// lib/providers/chat_provider.dart
import 'dart:async';
import 'dart:convert'; // Import for jsonEncode
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart'; // Updated model
import '../models/conversation.dart';
import '../services/chat_service.dart';
import './auth_provider.dart';
import 'dart:math' as math;
import '../config/sentry_config.dart'; // Import the Sentry config

class ChatProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  AuthProvider? _authProvider; // Already exists

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
        loadConversations();
      }
    } else if (_authProvider?.isAuthenticated ?? false) {
      _checkQueueStatus();
    }
  }

  Future<void> _checkQueueStatus() async {
    try {
      final token = _authProvider?.token;
      if (kDebugMode && token == null) {
        print("ChatProvider: Attempting to check queue status, but token is null (User might be logged out).");
      }
      addBreadcrumb(
        message: 'Checking chat queue status',
        category: 'api',
      );
      _isQueueActive = await _chatService.isChatQueueActive(token: token);
      if (kDebugMode) print("ChatProvider: Queue system is ${_isQueueActive ? 'active' : 'not active'}");
    } catch (e) {
      if (kDebugMode) print("ChatProvider: Error checking queue status: $e");
      _isQueueActive = false;
      captureException(e,
          stackTrace: StackTrace.current,
          hint: 'Error checking chat queue status'
      );
    }
  }

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
      captureException(e,
          stackTrace: stackTrace,
          hint: 'Error loading conversations'
      );
    } finally {
      _isLoadingConversations = false;
      await _checkQueueStatus();
      notifyListeners();
    }
  }

  Future<void> selectConversation(String conversationId) async {
    if (_activeConversationId == conversationId && _activeMessages.isNotEmpty) return;
    if(kDebugMode) print("ChatProvider: Selecting conversation $conversationId");

    addBreadcrumb(
      message: 'Selecting conversation',
      category: 'chat',
      data: {'conversationId': conversationId},
    );

    _activeConversationId = conversationId; _activeMessages = []; _messagesError = null;
    _sendMessageError = null; _isLoadingMessages = true; notifyListeners();
    await _loadMessagesForActiveConversation();
  }

  Future<void> _loadMessagesForActiveConversation() async {
    if (_activeConversationId == null) return;
    if(kDebugMode) print("ChatProvider: Loading messages for conversation $_activeConversationId");

    addBreadcrumb(
      message: 'Loading messages for conversation',
      category: 'chat',
      data: {'conversationId': _activeConversationId},
    );

    try {
      final response = await _supabase.from('messages').select().eq('conversation_id', _activeConversationId!).order('created_at', ascending: true);
      _activeMessages = response.map((data) {
        final mapData = data;
        MessageType type = (mapData['role'] == 'assistant') ? MessageType.ai : MessageType.user;
        final metadata = mapData['metadata'];
        if (kDebugMode) print("<<< ChatProvider: Loading message ID ${mapData['id']}, Raw metadata from DB: ${metadata?.toString()} (Type: ${metadata?.runtimeType})");
        List<String>? suggestionsList;
        if (metadata != null && metadata is Map && metadata['suggestions'] != null && metadata['suggestions'] is List) {
          try {
            suggestionsList = (metadata['suggestions'] as List).whereType<String>().toList();
            if (suggestionsList.isEmpty) suggestionsList = null;
            if (kDebugMode) print("<<< ChatProvider: Parsed suggestions list from DB: ${suggestionsList?.toString()}");
          } catch (e) {
            if (kDebugMode) print("<<< ChatProvider: Error casting suggestions metadata from DB for msg ${mapData['id']}: $e");
            suggestionsList = null;
            captureException(e, stackTrace: StackTrace.current, hint: 'Error parsing message suggestions from database');
          }
        } else {
          if (kDebugMode) print("<<< ChatProvider: No valid suggestions list found in metadata for msg ${mapData['id']}.");
          suggestionsList = null;
        }
        return ChatMessage(
          id: mapData['id'] as String,
          content: mapData['content'] as String,
          type: type,
          timestamp: DateTime.parse(mapData['created_at'] as String),
          suggestions: suggestionsList,
        );
      }).toList();
      if(kDebugMode) print("ChatProvider: Loaded ${_activeMessages.length} messages.");
      _messagesError = null;
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error loading messages: $e\n$stackTrace");
      _messagesError = "Failed to load messages."; _activeMessages = [];
      captureException(e, stackTrace: stackTrace, hint: 'Error loading messages for conversation');
    } finally {
      _isLoadingMessages = false; notifyListeners();
    }
  }

  Future<String?> createNewConversation() async {
    final userId = _authProvider?.user?.id;
    if (userId == null) {
      _conversationsError = "Cannot create conversation: User not logged in.";
      notifyListeners();
      if(kDebugMode) print("ChatProvider: Attempted createNewConversation, but user is null according to AuthProvider.");
      return null;
    }
    if(kDebugMode) print("ChatProvider: Creating new conversation for user $userId (from AuthProvider)");

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
        await loadConversations();
        await selectConversation(newId);
        return newId;
      } else { throw Exception("Failed to retrieve ID for new conversation."); }
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error creating new conversation: $e\n$stackTrace");
      _conversationsError = "Failed to create conversation.";
      captureException(e, stackTrace: stackTrace, hint: 'Error creating new conversation');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
    return null;
  }

  // MODIFIED sendMessage method
  Future<void> sendMessage(String content, {bool addToUi = true}) async { // Added addToUi parameter
    if (_isSendingMessage) return;
    if (_activeConversationId == null) {
      _sendMessageError = "No active chat.";
      notifyListeners();
      return;
    }
    final userId = _authProvider?.user?.id;

    _isSendingMessage = true;
    _sendMessageError = null;
    notifyListeners(); // Notify listeners that sending has started (for UI indicators)

    addBreadcrumb(
      message: 'Sending chat message',
      category: 'chat',
      data: {
        'conversationId': _activeConversationId,
        'contentLength': content.length,
        'addToUi': addToUi // Log the new parameter
      },
    );

    ChatMessage? localUserMessage; // Declare here to access in catch/finally if needed

    if (addToUi) {
      localUserMessage = ChatMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        content: content,
        type: MessageType.user,
        timestamp: DateTime.now(),
      );
      _activeMessages.add(localUserMessage);
      notifyListeners(); // Show user's message in UI immediately if addToUi is true
    }

    ChatMessage? localAiMessage;

    try {
      // Save User Message to DB (Only if user is logged in AND message is meant for UI)
      // If addToUi is false, it's a background query, so we typically wouldn't save it as a user message.
      // Adjust this logic if your backend expects even "silent" queries to be logged this way.
      if (userId != null && addToUi) { // Conditionally save based on addToUi
        if(kDebugMode) print("ChatProvider: Saving user message to DB (since addToUi is true)...");
        await _supabase.from('messages').insert({
          'conversation_id': _activeConversationId!,
          'user_id': userId,
          'role': 'user',
          'content': content
        });
      } else {
        if(kDebugMode) print("ChatProvider: Skipping saving user message to DB (User not logged in OR addToUi is false).");
      }

      List<ChatMessage> contextMessages = [];
      // Prepare context. If addToUi is false, the current `content` is not in `_activeMessages` yet.
      // Consider if "silent" messages should still use existing visible history or have tailored context.
      // For now, let's use the visible history.
      final messagesForContext = List<ChatMessage>.from(_activeMessages);
      if (addToUi && localUserMessage != null && messagesForContext.isNotEmpty) {
        // If we added the user message to UI, it's the last one. Exclude it from context for the current call.
        messagesForContext.removeLast();
      }

      if (messagesForContext.isNotEmpty) {
        final startIndex = math.max(0, messagesForContext.length - _maxContextMessages);
        contextMessages = messagesForContext.sublist(startIndex);
        if(kDebugMode) print("ChatProvider: Including ${contextMessages.length} previous messages as context");
      }


      final token = _authProvider?.token;
      if(kDebugMode) print("ChatProvider: Calling backend chat service with context history...");
      final Map<String, dynamic> response = await _chatService.sendMessage(
          _activeConversationId!,
          content, // This is the actual query text, visible or silent
          contextMessages,
          token: token
      );

      if (kDebugMode) print(">>> ChatProvider: Received from ChatService: ${response.toString()}");
      final String? aiReplyContent = response['reply'] as String?;
      List<String>? suggestionsList;
      final suggestionsData = response['suggestions'];
      if (kDebugMode) print(">>> ChatProvider: Raw suggestions data from backend: ${suggestionsData?.toString()} (Type: ${suggestionsData?.runtimeType})");
      if (suggestionsData != null && suggestionsData is List) {
        try {
          suggestionsList = suggestionsData.whereType<String>().toList();
          if (suggestionsList.isEmpty) suggestionsList = null;
        } catch (e) {
          if (kDebugMode) print(">>> ChatProvider: Error casting suggestions from backend: $e");
          suggestionsList = null;
          captureException(e, stackTrace: StackTrace.current, hint: 'Error parsing suggestions from chat API response');
        }
      }
      if (kDebugMode) print(">>> ChatProvider: Parsed suggestions list for local message: ${suggestionsList?.toString()}");

      if (aiReplyContent == null || aiReplyContent.isEmpty) throw Exception("Received empty reply from assistant.");

      localAiMessage = ChatMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch + 1}', // Ensure unique ID
        content: aiReplyContent,
        type: MessageType.ai,
        timestamp: DateTime.now(),
        suggestions: suggestionsList,
      );
      _activeMessages.add(localAiMessage);
      // No need to notifyListeners here if we save and then notify in finally,
      // but for immediate UI update of AI message:
      // notifyListeners(); // Uncomment if you want AI message to show before DB save completes

      final metadataToSave = {'suggestions': suggestionsList ?? []};
      final assistantMessageDataToSave = {
        'conversation_id': _activeConversationId!,
        'user_id': null,
        'role': 'assistant',
        'content': aiReplyContent,
        'metadata': metadataToSave,
      };

      if (kDebugMode) print(">>> ChatProvider: Metadata being saved to DB: ${jsonEncode(metadataToSave)}");
      if(kDebugMode) print("ChatProvider: Saving assistant message to DB...");
      await _supabase.from('messages').insert(assistantMessageDataToSave);

      if (userId != null) { // Only update conversation timestamp if a user is involved
        if(kDebugMode) print("ChatProvider: Updating conversation timestamp...");
        await _supabase.from('conversations').update({'updated_at': DateTime.now().toIso8601String()}).eq('id', _activeConversationId!);
      } else {
        if(kDebugMode) print("ChatProvider: User not logged in, skipping conversation timestamp update.");
      }

      if(kDebugMode) print("ChatProvider: Send message process complete.");
      _sendMessageError = null; // Clear error on success

    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error during sendMessage full process: $e\n$stackTrace");
      _sendMessageError = e.toString().replaceFirst("Exception: ", "");
      if (addToUi && localUserMessage != null) {
        // If the message was added to UI and failed, consider removing it or marking it as failed
        _activeMessages.remove(localUserMessage);
      }
      if (localAiMessage != null) _activeMessages.remove(localAiMessage);
      // notifyListeners(); // Already called in finally

      captureException(e, stackTrace: stackTrace, hint: 'Error sending chat message');
    } finally {
      _isSendingMessage = false;
      notifyListeners(); // Crucial: Notify UI about the final state (sending finished, error updated, messages updated)
    }
  }
  // END OF MODIFIED sendMessage

  void resetActiveChat() {
    _activeConversationId = null; _activeMessages = []; _messagesError = null;
    _sendMessageError = null; _isSendingMessage = false;
    if(kDebugMode) print("ChatProvider: Active chat state reset.");
    notifyListeners();
    addBreadcrumb(message: 'Reset active chat', category: 'chat');
  }

  Future<void> deleteConversation(String conversationId) async {
    final userId = _authProvider?.user?.id;
    if (userId == null) { _conversationsError = "Cannot delete: User not logged in."; notifyListeners(); return; }
    if(kDebugMode) print("ChatProvider: Deleting conversation $conversationId");

    addBreadcrumb(
      message: 'Deleting conversation',
      category: 'chat',
      data: {'conversationId': conversationId, 'userId': userId},
    );

    try {
      await _supabase.from('conversations').delete().match({'id': conversationId, 'user_id': userId});
      int initialLength = _conversations.length;
      _conversations.removeWhere((c) => c.id == conversationId);
      if (initialLength == _conversations.length) {
        if(kDebugMode) print("ChatProvider: Delete action completed, but conversation $conversationId not found locally or delete RLS failed.");
      } else {
        if(kDebugMode) print("ChatProvider: Conversation $conversationId deleted locally.");
      }
      if (_activeConversationId == conversationId) resetActiveChat();
      notifyListeners();
    } catch(e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error deleting conversation: $e\n$stackTrace");
      _conversationsError = "Failed to delete conversation.";
      notifyListeners();
      captureException(e, stackTrace: stackTrace, hint: 'Error deleting conversation');
    }
  }

  Future<void> _startPollingForResponse(String messageId) async {
    if (!_isQueueActive) return;
    _isPolling = true;
    int attempts = 0;
    const maxAttempts = 30;
    addBreadcrumb(
      message: 'Starting to poll for AI response',
      category: 'chat',
      data: {'messageId': messageId, 'maxAttempts': maxAttempts},
    );
    while (_isPolling && attempts < maxAttempts) {
      attempts++;
      await Future.delayed(const Duration(milliseconds: 500));
      final userMessageIndex = _activeMessages.indexWhere((m) => m.id == messageId);
      bool hasResponse = false;
      if (userMessageIndex != -1 && userMessageIndex + 1 < _activeMessages.length) {
        hasResponse = _activeMessages[userMessageIndex + 1].type == MessageType.ai;
      }
      if (hasResponse) {
        if (kDebugMode) print("ChatProvider: Response likely received, stopping polls");
        _isPolling = false;
        break;
      }
      if (!_isSendingMessage) {
        if (kDebugMode) print("ChatProvider: Message sending phase completed/failed, stopping polls");
        _isPolling = false;
        break;
      }
      if (kDebugMode && attempts % 10 == 0) {
        print("ChatProvider: Still waiting for queued response, poll attempt $attempts");
      }
    }
    if (_isPolling && attempts >= maxAttempts) {
      if (kDebugMode) print("ChatProvider: Polling timed out waiting for response.");
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