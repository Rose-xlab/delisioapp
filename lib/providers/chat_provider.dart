// lib/providers/chat_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart'; // Import for generating unique IDs

import '../models/chat_message.dart'; // Updated model
import '../models/conversation.dart';
import '../models/recipe.dart'; // Import Recipe model
import '../services/chat_service.dart';
import './auth_provider.dart';
import 'dart:math' as math;
import '../config/sentry_config.dart';

class ChatProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  AuthProvider? _authProvider; // Already exists
  final _uuid = const Uuid(); // For generating local IDs

  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationsError;

  String? _activeConversationId;
  List<ChatMessage> _activeMessages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;

  bool _isSendingMessage = false;
  String? _sendMessageError;

  // Added properties for queue support
  bool _isQueueActive = false;
  bool _isPolling = false;

  // Maximum number of messages to include as context history
  final int _maxContextMessages = 10;

  // --- Getters ---
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;
  String? get activeConversationId => _activeConversationId;
  List<ChatMessage> get activeMessages => List.unmodifiable(_activeMessages);
  bool get isLoadingMessages => _isLoadingMessages;
  String? get messagesError => _messagesError;
  bool get isSendingMessage => _isSendingMessage;
  String? get sendMessageError => _sendMessageError;
  bool get isQueueActive => _isQueueActive;

  // --- Update Method ---
  void updateAuth(AuthProvider? auth) {
    if (kDebugMode) print("ChatProvider: Received updateAuth. New auth state isAuthenticated: ${auth?.isAuthenticated}");
    bool authChanged = _authProvider?.isAuthenticated != auth?.isAuthenticated;
    _authProvider = auth; // Update the internal auth provider reference

    // Add breadcrumb for auth state change
    addBreadcrumb(
      message: 'Auth state updated in ChatProvider',
      category: 'auth',
      data: {'isAuthenticated': auth?.isAuthenticated},
    );

    if (authChanged) {
      if (!(_authProvider?.isAuthenticated ?? false)) {
        if (kDebugMode) print("ChatProvider: Auth state changed to logged out, resetting chat state.");
        _conversations = []; _conversationsError = null; resetActiveChat();
      } else {
        if (kDebugMode) print("ChatProvider: Auth state changed to logged in, reloading conversations.");
        loadConversations(); // This already calls _checkQueueStatus indirectly
      }
    } else if (_authProvider?.isAuthenticated ?? false) {
      // If auth didn't change but user is authenticated, still check queue status
      // This handles cases where the provider might be updated without login/logout event
      _checkQueueStatus();
    }
  }

  // --- Check if queue system is being used ---
  Future<void> _checkQueueStatus() async {
    try {
      // --- MODIFIED: Get token and pass it ---
      final token = _authProvider?.token; // Get token from AuthProvider
      if (kDebugMode && token == null) {
        print("ChatProvider: Attempting to check queue status, but token is null (User might be logged out).");
      }

      // Add breadcrumb
      addBreadcrumb(
        message: 'Checking chat queue status',
        category: 'api',
      );

      // Pass the token (even if null, service handles it)
      _isQueueActive = await _chatService.isChatQueueActive(token: token);
      // --- END MODIFICATION ---

      if (kDebugMode) print("ChatProvider: Queue system is ${_isQueueActive ? 'active' : 'not active'}");
    } catch (e) {
      if (kDebugMode) print("ChatProvider: Error checking queue status: $e");
      _isQueueActive = false; // Default to no queue if check fails

      // Log to Sentry
      captureException(e,
          stackTrace: StackTrace.current,
          hint: 'Error checking chat queue status'
      );
    }
    // Notify listeners if the queue status might affect the UI
    // notifyListeners(); // Uncomment if UI depends directly on isQueueActive
  }

  // --- Methods ---

  Future<void> loadConversations() async {
    if (_isLoadingConversations) return;
    final userId = _authProvider?.user?.id;
    if (userId == null) {
      _conversationsError = "Cannot load conversations: User not logged in.";
      _conversations = [];
      if(kDebugMode) print("ChatProvider: Cannot load conversations, user null according to AuthProvider.");
      if (_isLoadingConversations || _conversations.isNotEmpty || _conversationsError == null) {
        _isLoadingConversations = false; notifyListeners();
      }
      return;
    }
    _isLoadingConversations = true; _conversationsError = null; notifyListeners();
    if(kDebugMode) print("ChatProvider: Loading conversations for user $userId (from AuthProvider)");

    // Add breadcrumb
    addBreadcrumb(
      message: 'Loading conversations',
      category: 'chat',
      data: {'userId': userId},
    );

    try {
      final response = await _supabase.from('conversations').select().eq('user_id', userId).order('updated_at', ascending: false);
      _conversations = response.map((data) => Conversation.fromJson(data)).toList();
      if(kDebugMode) print("ChatProvider: Loaded ${_conversations.length} conversations.");
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error loading conversations: $e\n$stackTrace");
      _conversationsError = "Failed to load conversations."; _conversations = [];

      // Log to Sentry
      captureException(e,
          stackTrace: stackTrace,
          hint: 'Error loading conversations'
      );
    } finally {
      _isLoadingConversations = false;
      // Check queue status after loading conversations
      await _checkQueueStatus(); // It's okay to call this here, it uses the updated _authProvider
      notifyListeners();
    }
  }

  Future<void> selectConversation(String conversationId) async {
    if (_activeConversationId == conversationId && _activeMessages.isNotEmpty) return;
    if(kDebugMode) print("ChatProvider: Selecting conversation $conversationId");

    // Add breadcrumb
    addBreadcrumb(
      message: 'Selecting conversation',
      category: 'chat',
      data: {'conversationId': conversationId},
    );

    _activeConversationId = conversationId; _activeMessages = []; _messagesError = null;
    _sendMessageError = null; _isLoadingMessages = true; notifyListeners();
    await _loadMessagesForActiveConversation();
  }

  // --- MODIFIED: _loadMessagesForActiveConversation uses new factory ---
  Future<void> _loadMessagesForActiveConversation() async {
    if (_activeConversationId == null) return;
    if (kDebugMode) print("ChatProvider: Loading messages for conversation $_activeConversationId");
    // isLoadingMessages should already be true from selectConversation

    addBreadcrumb(message: 'Loading messages for conversation', category: 'chat', data: {'conversationId': _activeConversationId});

    try {
      final response = await _supabase
          .from('messages')
          .select() // Select all columns
          .eq('conversation_id', _activeConversationId!)
          .order('created_at', ascending: true);

      _activeMessages = response.map((data) {
        // Use the updated ChatMessage.fromJson factory which handles metadata/types
        return ChatMessage.fromJson(data as Map<String, dynamic>);
      }).toList();

      if (kDebugMode) print("ChatProvider: Loaded ${_activeMessages.length} messages. Last message type: ${_activeMessages.lastOrNull?.type}");
      _messagesError = null;
    } catch (e, stackTrace) {
      if (kDebugMode) print("ChatProvider: Error loading messages: $e\n$stackTrace");
      _messagesError = "Failed to load messages.";
      _activeMessages = [];
      captureException(e, stackTrace: stackTrace, hint: 'Error loading messages for conversation');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }
  // --- END MODIFIED ---

  Future<String?> createNewConversation() async {
    final userId = _authProvider?.user?.id;
    if (userId == null) {
      _conversationsError = "Cannot create conversation: User not logged in.";
      notifyListeners();
      if(kDebugMode) print("ChatProvider: Attempted createNewConversation, but user is null according to AuthProvider.");
      return null;
    }
    if(kDebugMode) print("ChatProvider: Creating new conversation for user $userId (from AuthProvider)");

    // Add breadcrumb
    addBreadcrumb(
      message: 'Creating new conversation',
      category: 'chat',
      data: {'userId': userId},
    );

    _isLoadingConversations = true; notifyListeners();
    try {
      final response = await _supabase.from('conversations').insert({'user_id': userId}).select('id').single();
      final newId = response['id'] as String?;
      if (newId != null) {
        if(kDebugMode) print("ChatProvider: New conversation created with ID: $newId");
        await loadConversations(); // Reloads conversations list
        await selectConversation(newId); // Selects the new one
        return newId;
      }
      else { throw Exception("Failed to retrieve ID for new conversation."); }
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error creating new conversation: $e\n$stackTrace");
      _conversationsError = "Failed to create conversation.";

      // Log to Sentry
      captureException(e,
          stackTrace: stackTrace,
          hint: 'Error creating new conversation'
      );
    } finally {
      _isLoadingConversations = false;
      notifyListeners(); // Ensure UI updates after operation, regardless of success/failure
    }
    return null; // Return null if try block didn't succeed
  }

  // --- NEW: Add Recipe Placeholder Message ---
  Future<String> addRecipePlaceholderMessage(String conversationId, String query) async {
    // Use a UUID for the local ID to ensure uniqueness
    final localId = 'local_placeholder_${_uuid.v4()}';
    final placeholderMessage = ChatMessage(
      id: localId,
      content: 'Generating recipe for "$query"...', // Placeholder content
      type: MessageType.recipePlaceholder, // Specific type
      timestamp: DateTime.now(),
      generationQuery: query, // Store the query used
    );

    if (_activeConversationId == conversationId) {
      _activeMessages.add(placeholderMessage);
      notifyListeners();
      if (kDebugMode) print("ChatProvider: Added recipe placeholder message locally (ID: $localId)");
    } else {
      if (kDebugMode) print("ChatProvider: Warning - Tried to add placeholder to non-active conversation $conversationId");
      // Ideally, handle adding to non-active chats, but complex. For now, only adds if active.
    }
    // Do NOT save the placeholder to the database yet.
    return localId; // Return the temporary ID
  }
  // --- END NEW ---

  // --- NEW: Update Placeholder to Recipe Result Message ---
  Future<void> updatePlaceholderToRecipeMessage(String conversationId, String placeholderId, Recipe generatedRecipe) async {
    if (_activeConversationId != conversationId) {
      if (kDebugMode) print("ChatProvider: Warning - Tried to update placeholder in non-active conversation $conversationId");
      // If not active, we might fetch messages, update, save, but that's complex.
      // Alternative: Just add the result message directly if placeholder update fails.
      await addRecipeResultMessage(conversationId, generatedRecipe);
      return;
    }

    final messageIndex = _activeMessages.indexWhere((msg) => msg.id == placeholderId && msg.type == MessageType.recipePlaceholder);

    if (messageIndex != -1) {
      // Create the final message
      final finalMessage = ChatMessage(
        // Use a real UUID if the placeholder ID was local, otherwise keep DB ID if it exists (though placeholders aren't saved yet)
        id: placeholderId.startsWith('local_') ? _uuid.v4() : placeholderId,
        content: 'Generated recipe: ${generatedRecipe.title}', // Indicate recipe generation
        type: MessageType.recipeResult, // Specific type for recipe result
        timestamp: DateTime.now(), // Use current time for the result message
        recipeId: generatedRecipe.id, // Store the recipe ID
        recipeTitle: generatedRecipe.title, // Store the recipe title
      );

      // Replace in local list FIRST for immediate UI update
      _activeMessages[messageIndex] = finalMessage;
      if (kDebugMode) print("ChatProvider: Replaced placeholder with recipe result locally (New ID: ${finalMessage.id}, RecipeID: ${finalMessage.recipeId})");
      notifyListeners(); // Notify after local update

      // NOW, save the *final* message to the Database
      final userId = _authProvider?.user?.id; // Get user ID for saving context if needed
      try {
        // Use the new toJsonForDb method which correctly sets role and metadata
        final dbPayload = finalMessage.toJsonForDb();
        dbPayload['conversation_id'] = conversationId;
        // user_id should not be set for assistant messages
        // dbPayload['user_id'] = userId;

        if (kDebugMode) print("ChatProvider: Saving recipe result message to DB: ${jsonEncode(dbPayload)}");

        // Insert the new message (we didn't save the placeholder)
        await _supabase.from('messages').insert(dbPayload);

        if (kDebugMode) print("ChatProvider: Recipe result message saved successfully.");

        // Update Conversation Timestamp (Only if user is logged in)
        if (userId != null) {
          if(kDebugMode) print("ChatProvider: Updating conversation timestamp for recipe result...");
          await _supabase.from('conversations')
              .update({'updated_at': DateTime.now().toIso8601String()})
              .eq('id', conversationId);
        }

      } catch (e, stackTrace) {
        if (kDebugMode) print("ChatProvider: Error saving recipe result message: $e\n$stackTrace");
        _sendMessageError = "Failed to save generated recipe message."; // Use appropriate error state
        captureException(e, stackTrace: stackTrace, hint: 'Error saving recipe result message');
        // Optionally revert the local change if DB save fails? More complex.
        // _activeMessages[messageIndex] = originalPlaceholder; // Need to store original first
        notifyListeners(); // Notify about error state
      }
      // No final notifyListeners needed here as it's done after local update and in catch block

    } else {
      if (kDebugMode) print("ChatProvider: Could not find placeholder message with ID $placeholderId to update. Adding result directly.");
      // If placeholder wasn't found (e.g., app restart during generation), add the result message anyway.
      await addRecipeResultMessage(conversationId, generatedRecipe);
    }
  }
  // --- END NEW ---

  // --- NEW: Add Recipe Result Message (if placeholder failed or wasn't used) ---
  Future<void> addRecipeResultMessage(String conversationId, Recipe recipe) async {
    // Create the message object
    final message = ChatMessage(
      id: _uuid.v4(), // Generate a new UUID
      content: 'Generated recipe: ${recipe.title}',
      type: MessageType.recipeResult,
      timestamp: DateTime.now(),
      recipeId: recipe.id,
      recipeTitle: recipe.title,
    );

    // Add optimistically if the conversation is active
    if (_activeConversationId == conversationId) {
      _activeMessages.add(message);
      if(kDebugMode) print("ChatProvider: Added recipe result message directly (ID: ${message.id}, RecipeID: ${message.recipeId})");
      notifyListeners(); // Notify for optimistic UI update
    }

    // Save to DB regardless of active state (important for consistency)
    final userId = _authProvider?.user?.id;
    try {
      final dbPayload = message.toJsonForDb();
      dbPayload['conversation_id'] = conversationId;
      // user_id not set for assistant messages

      if(kDebugMode) print("ChatProvider: Saving direct recipe result message to DB: ${jsonEncode(dbPayload)}");
      await _supabase.from('messages').insert(dbPayload);
      if(kDebugMode) print("ChatProvider: Recipe result message saved successfully (direct add).");

      // Update conversation timestamp if user is logged in
      if (userId != null) {
        await _supabase.from('conversations').update({'updated_at': DateTime.now().toIso8601String()}).eq('id', conversationId);
      }
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error saving direct recipe result message: $e\n$stackTrace");
      _sendMessageError = "Failed to save generated recipe message.";
      captureException(e, stackTrace: stackTrace, hint: 'Error saving direct recipe result message');
      // Remove optimistic add on failure ONLY if it was the active conversation
      if (_activeConversationId == conversationId) {
        _activeMessages.removeWhere((m) => m.id == message.id);
        notifyListeners(); // Notify UI about removal
      }
    }
    // No finally/notify here unless we always want notification after DB attempt
  }
  // --- END NEW ---

  // --- NEW: Remove Placeholder Message ---
  Future<void> removePlaceholderMessage(String conversationId, String placeholderId) async {
    if (_activeConversationId == conversationId) {
      final originalLength = _activeMessages.length;
      _activeMessages.removeWhere((msg) => msg.id == placeholderId && msg.type == MessageType.recipePlaceholder);
      if (_activeMessages.length < originalLength) {
        if (kDebugMode) print("ChatProvider: Removed recipe placeholder message locally (ID: $placeholderId)");
        notifyListeners(); // Update UI after removing
      } else {
        if (kDebugMode) print("ChatProvider: Could not find local placeholder message with ID $placeholderId to remove.");
      }
    } else {
      if (kDebugMode) print("ChatProvider: Warning - Tried to remove placeholder from non-active conversation $conversationId");
      // Placeholder only exists locally for active chat, so no action needed for non-active.
    }
    // No DB action needed as the placeholder was never saved.
  }
  // --- END NEW ---

  Future<void> sendMessage(String content) async {
    if (_isSendingMessage) return;
    if (_activeConversationId == null) { _sendMessageError = "No active chat."; notifyListeners(); return; }
    final userId = _authProvider?.user?.id;
    // Message can be sent even if userId is null if backend allows optionalAuth
    // if (userId == null) { _sendMessageError = "User not logged in."; notifyListeners(); return; }

    _isSendingMessage = true; _sendMessageError = null; notifyListeners();

    // Add breadcrumb
    addBreadcrumb(
      message: 'Sending chat message',
      category: 'chat',
      data: {
        'conversationId': _activeConversationId,
        'contentLength': content.length
      },
    );

    // Use a real UUID for the local message ID
    final localUserMessageId = _uuid.v4();
    final localUserMessage = ChatMessage(id: localUserMessageId, content: content, type: MessageType.user, timestamp: DateTime.now());
    _activeMessages.add(localUserMessage); notifyListeners();

    ChatMessage? localAiMessage;
    String? savedUserMessageDbId; // Store the DB ID if saved

    try {
      // 1. Save User Message (Only if user is logged in)
      if (userId != null) {
        if(kDebugMode) print("ChatProvider: Saving user message to DB...");
        // Use toJsonForDb which correctly sets role and metadata (empty for user msg)
        final userMsgData = localUserMessage.toJsonForDb();
        userMsgData['conversation_id'] = _activeConversationId!;
        userMsgData['user_id'] = userId; // Associate with user

        // Insert and select the 'id' generated by the database
        final response = await _supabase.from('messages').insert(userMsgData).select('id').single();
        savedUserMessageDbId = response['id'] as String?; // Get the actual DB ID
        if (kDebugMode) print("ChatProvider: User message saved with DB ID: $savedUserMessageDbId");

        // OPTIONAL: Update the local message with the DB ID for consistency, though not strictly required
        // final userMsgIndex = _activeMessages.indexWhere((m) => m.id == localUserMessageId);
        // if (userMsgIndex != -1 && savedUserMessageDbId != null) {
        //    _activeMessages[userMsgIndex] = ChatMessage(
        //        id: savedUserMessageDbId, // Use DB ID
        //        content: localUserMessage.content, type: localUserMessage.type, timestamp: localUserMessage.timestamp);
        //    // No need to notifyListeners here, happens later anyway
        // }

      } else {
        if(kDebugMode) print("ChatProvider: User not logged in, skipping saving user message to DB.");
      }

      // 2. Get Context History
      List<ChatMessage> contextMessages = [];
      if (_activeMessages.length > 1) {
        // Get the last N messages (excluding the one we just added)
        final startIndex = math.max(0, _activeMessages.length - 1 - _maxContextMessages);
        contextMessages = _activeMessages.sublist(startIndex, _activeMessages.length - 1);
        if(kDebugMode) print("ChatProvider: Including ${contextMessages.length} previous messages as context");
      }

      // 3. Call Backend Chat Service
      // --- MODIFIED: Get token and pass it ---
      final token = _authProvider?.token; // Get token
      if(kDebugMode) print("ChatProvider: Calling backend chat service with context history...");
      final Map<String, dynamic> response = await _chatService.sendMessage(
          _activeConversationId!,
          content,
          contextMessages,
          token: token // <-- Pass token here
      );
      // --- END MODIFICATION ---


      // 4. Process Backend Response
      // --- Original Sending logs (Retained) ---
      if (kDebugMode) print(">>> ChatProvider: Received from ChatService: ${response.toString()}");
      final String? aiReplyContent = response['reply'] as String?;
      List<String>? suggestionsList;
      final suggestionsData = response['suggestions']; // Get the suggestions data
      if (kDebugMode) print(">>> ChatProvider: Raw suggestions data from backend: ${suggestionsData?.toString()} (Type: ${suggestionsData?.runtimeType})");
      if (suggestionsData != null && suggestionsData is List) {
        try {
          // Filter for non-null strings
          suggestionsList = suggestionsData
              .map((item) => item?.toString())
              .where((item) => item != null)
              .cast<String>()
              .toList();
          if (suggestionsList.isEmpty) suggestionsList = null; // Treat empty list as null for consistency
        } catch (e) {
          if (kDebugMode) print(">>> ChatProvider: Error casting suggestions from backend: $e");
          suggestionsList = null;

          // Log to Sentry
          captureException(e,
              stackTrace: StackTrace.current,
              hint: 'Error parsing suggestions from chat API response'
          );
        }
      }
      if (kDebugMode) print(">>> ChatProvider: Parsed suggestions list for local message: ${suggestionsList?.toString()}");
      // --- END OF Original Sending logs ---

      if (aiReplyContent == null || aiReplyContent.isEmpty) throw Exception("Received empty reply from assistant.");

      // 5. Add Optimistic AI Message (with unique local ID)
      final localAiMessageId = _uuid.v4(); // Use UUID for AI message too
      localAiMessage = ChatMessage(
        id: localAiMessageId,
        content: aiReplyContent,
        type: MessageType.ai,
        timestamp: DateTime.now(),
        suggestions: suggestionsList, // Use parsed list
      );
      _activeMessages.add(localAiMessage);
      notifyListeners(); // Notify for optimistic UI update

      // 6. Save Assistant Message to DB
      // Use toJsonForDb, which handles metadata like suggestions
      final assistantMessageDataToSave = localAiMessage.toJsonForDb();
      assistantMessageDataToSave['conversation_id'] = _activeConversationId!;
      // AI messages don't have a user_id
      // metadata is handled inside toJsonForDb

      // --- Original Sending log (Retained) ---
      if (kDebugMode) print(">>> ChatProvider: Assistant Message Metadata being saved to DB: ${jsonEncode(assistantMessageDataToSave['metadata'])}"); // Log JSON being saved
      // --- END OF Original Sending log ---

      // Save Assistant Message (Save regardless of user login status, as AI replied)
      if(kDebugMode) print("ChatProvider: Saving assistant message to DB...");
      // Insert the assistant message
      await _supabase.from('messages').insert(assistantMessageDataToSave);
      if(kDebugMode) print("ChatProvider: Assistant message saved successfully.");


      // 7. Update Conversation Timestamp (Only if user is logged in and conversation belongs to them)
      if (userId != null) {
        if(kDebugMode) print("ChatProvider: Updating conversation timestamp...");
        await _supabase.from('conversations').update({'updated_at': DateTime.now().toIso8601String()}).eq('id', _activeConversationId!);
      } else {
        if(kDebugMode) print("ChatProvider: User not logged in, skipping conversation timestamp update.");
      }

      if(kDebugMode) print("ChatProvider: Send message process complete.");

    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error during sendMessage full process: $e\n$stackTrace");
      // Use the error message from the exception if available
      _sendMessageError = e.toString().replaceFirst("Exception: ", "");
      // Remove optimistic messages using their unique local IDs
      _activeMessages.removeWhere((m) => m.id == localUserMessageId);
      if (localAiMessage != null) _activeMessages.removeWhere((m) => m.id == localAiMessage!.id);
      notifyListeners(); // Notify UI about the error state and removal

      // Log to Sentry
      captureException(e,
          stackTrace: stackTrace,
          hint: 'Error sending chat message'
      );
    } finally {
      _isSendingMessage = false;
      notifyListeners(); // Notify about sending state change
    }
  }


  void resetActiveChat() {
    _activeConversationId = null; _activeMessages = []; _messagesError = null;
    _sendMessageError = null; _isSendingMessage = false;
    if(kDebugMode) print("ChatProvider: Active chat state reset.");
    notifyListeners();

    // Add breadcrumb
    addBreadcrumb(
      message: 'Reset active chat',
      category: 'chat',
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    final userId = _authProvider?.user?.id;
    if (userId == null) { _conversationsError = "Cannot delete: User not logged in."; notifyListeners(); return; }
    if(kDebugMode) print("ChatProvider: Deleting conversation $conversationId");

    // Add breadcrumb
    addBreadcrumb(
      message: 'Deleting conversation',
      category: 'chat',
      data: {'conversationId': conversationId, 'userId': userId},
    );

    try {
      // Ensure deletion only happens if the conversation belongs to the user
      // NOTE: Supabase cascade delete should handle deleting related messages automatically
      // if the foreign key constraint is set up correctly (`messages.conversation_id` -> `conversations.id` with ON DELETE CASCADE)
      await _supabase.from('conversations').delete().match({'id': conversationId, 'user_id': userId});
      int initialLength = _conversations.length;
      _conversations.removeWhere((c) => c.id == conversationId);
      if (initialLength == _conversations.length) {
        if(kDebugMode) print("ChatProvider: Delete action completed, but conversation $conversationId not found locally or delete RLS failed.");
        // Optionally, reload conversations to ensure consistency if RLS might have blocked delete
        // await loadConversations();
      } else {
        if(kDebugMode) print("ChatProvider: Conversation $conversationId deleted locally.");
      }

      if (_activeConversationId == conversationId) resetActiveChat();
      notifyListeners();
    } catch(e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error deleting conversation: $e\n$stackTrace");
      _conversationsError = "Failed to delete conversation.";
      notifyListeners();

      // Log to Sentry
      captureException(e,
          stackTrace: stackTrace,
          hint: 'Error deleting conversation'
      );
    }
  }

  // Poll for AI response if using queue system (Original, retained)
  // Note: This polling logic might need adjustment based on how backend notifies completion
  Future<void> _startPollingForResponse(String messageId) async {
    if (!_isQueueActive) return;

    _isPolling = true;
    int attempts = 0;
    const maxAttempts = 30;  // 15 seconds (500ms * 30) - Adjust as needed

    // Add breadcrumb
    addBreadcrumb(
      message: 'Starting to poll for AI response',
      category: 'chat',
      data: {'messageId': messageId, 'maxAttempts': maxAttempts},
    );

    while (_isPolling && attempts < maxAttempts) {
      attempts++;
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if we already have a response for the corresponding user message
      // This assumes AI response is linked or added shortly after user message processing
      // This logic might need refinement based on actual response flow
      final userMessageIndex = _activeMessages.indexWhere((m) => m.id == messageId); // Find the original user message
      bool hasResponse = false;
      if (userMessageIndex != -1 && userMessageIndex + 1 < _activeMessages.length) {
        // Check if the next message exists and is from AI (or Recipe type)
        hasResponse = _activeMessages[userMessageIndex + 1].type == MessageType.ai || _activeMessages[userMessageIndex + 1].type == MessageType.recipeResult;
      }

      if (hasResponse) {
        if (kDebugMode) print("ChatProvider: Response likely received, stopping polls");
        _isPolling = false;
        break;
      }

      // Check if we're still sending (i.e., waiting for the backend call to return)
      if (!_isSendingMessage) {
        if (kDebugMode) print("ChatProvider: Message sending phase completed/failed, stopping polls");
        _isPolling = false;
        break;
      }

      if (kDebugMode && attempts % 10 == 0) { // Log less frequently
        print("ChatProvider: Still waiting for queued response, poll attempt $attempts");
      }
    }

    if (_isPolling && attempts >= maxAttempts) {
      if (kDebugMode) print("ChatProvider: Polling timed out waiting for response.");
      // Optionally set an error state or notify user

      // Add breadcrumb for polling timeout
      addBreadcrumb(
        message: 'Polling for AI response timed out',
        category: 'chat',
        level: SentryLevel.warning,
        data: {'messageId': messageId, 'attempts': attempts},
      );
    }

    _isPolling = false;
  }
}