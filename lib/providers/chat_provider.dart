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

class ChatProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  AuthProvider? _authProvider;

  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationsError;

  String? _activeConversationId;
  List<ChatMessage> _activeMessages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;

  bool _isSendingMessage = false;
  String? _sendMessageError;

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

  // --- Update Method ---
  void updateAuth(AuthProvider? auth) {
    if (kDebugMode) print("ChatProvider: Received updateAuth. New auth state isAuthenticated: ${auth?.isAuthenticated}");
    bool authChanged = _authProvider?.isAuthenticated != auth?.isAuthenticated;
    _authProvider = auth;
    if (authChanged) {
      if (!(_authProvider?.isAuthenticated ?? false)) {
        if (kDebugMode) print("ChatProvider: Auth state changed to logged out, resetting chat state.");
        _conversations = []; _conversationsError = null; resetActiveChat();
      } else {
        if (kDebugMode) print("ChatProvider: Auth state changed to logged in, reloading conversations.");
        loadConversations();
      }
    }
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
    try {
      final response = await _supabase.from('conversations').select().eq('user_id', userId).order('updated_at', ascending: false);
      _conversations = response.map((data) => Conversation.fromJson(data as Map<String, dynamic>)).toList();
      if(kDebugMode) print("ChatProvider: Loaded ${_conversations.length} conversations.");
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error loading conversations: $e\n$stackTrace");
      _conversationsError = "Failed to load conversations."; _conversations = [];
    } finally { _isLoadingConversations = false; notifyListeners(); }
  }

  Future<void> selectConversation(String conversationId) async {
    if (_activeConversationId == conversationId && _activeMessages.isNotEmpty) return;
    if(kDebugMode) print("ChatProvider: Selecting conversation $conversationId");
    _activeConversationId = conversationId; _activeMessages = []; _messagesError = null;
    _sendMessageError = null; _isLoadingMessages = true; notifyListeners();
    await _loadMessagesForActiveConversation();
  }

  Future<void> _loadMessagesForActiveConversation() async {
    if (_activeConversationId == null) return;
    if(kDebugMode) print("ChatProvider: Loading messages for conversation $_activeConversationId");
    // isLoadingMessages already true

    try {
      final response = await _supabase.from('messages').select().eq('conversation_id', _activeConversationId!).order('created_at', ascending: true);

      _activeMessages = response.map((data) {
        final mapData = data as Map<String, dynamic>;
        MessageType type = (mapData['role'] == 'assistant') ? MessageType.ai : MessageType.user;

        // --- ADD LOGS HERE (Loading) ---
        final metadata = mapData['metadata'];
        print("<<< ChatProvider: Loading message ID ${mapData['id']}, Raw metadata from DB: ${metadata?.toString()} (Type: ${metadata?.runtimeType})");
        List<String>? suggestionsList;
        if (metadata != null && metadata is Map && metadata['suggestions'] != null && metadata['suggestions'] is List) {
          try {
            suggestionsList = (metadata['suggestions'] as List)
                .whereType<String>()
                .toList();
            if (suggestionsList.isEmpty) suggestionsList = null;
            print("<<< ChatProvider: Parsed suggestions list from DB: ${suggestionsList?.toString()}");
          } catch (e) {
            if (kDebugMode) print("<<< ChatProvider: Error casting suggestions metadata from DB for msg ${mapData['id']}: $e");
            suggestionsList = null;
          }
        } else {
          print("<<< ChatProvider: No valid suggestions list found in metadata for msg ${mapData['id']}.");
          suggestionsList = null;
        }
        // --- END OF ADDED LOGS ---

        return ChatMessage(
          id: mapData['id'] as String,
          content: mapData['content'] as String,
          type: type,
          timestamp: DateTime.parse(mapData['created_at'] as String),
          suggestions: suggestionsList, // Use parsed list
        );
      }).toList();
      if(kDebugMode) print("ChatProvider: Loaded ${_activeMessages.length} messages.");
      _messagesError = null;
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error loading messages: $e\n$stackTrace");
      _messagesError = "Failed to load messages."; _activeMessages = [];
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
    _isLoadingConversations = true; notifyListeners();
    try {
      final response = await _supabase.from('conversations').insert({'user_id': userId}).select('id').single();
      final newId = response['id'] as String?;
      if (newId != null) {
        if(kDebugMode) print("ChatProvider: New conversation created with ID: $newId");
        await loadConversations(); await selectConversation(newId); return newId;
      }
      else { throw Exception("Failed to retrieve ID for new conversation."); }
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error creating new conversation: $e\n$stackTrace");
      _conversationsError = "Failed to create conversation."; _isLoadingConversations = false; notifyListeners(); return null;
    }
  }

  Future<void> sendMessage(String content) async {
    if (_isSendingMessage) return;
    if (_activeConversationId == null) { _sendMessageError = "No active chat."; notifyListeners(); return; }
    final userId = _authProvider?.user?.id;
    if (userId == null) { _sendMessageError = "User not logged in."; notifyListeners(); return; }

    _isSendingMessage = true; _sendMessageError = null; notifyListeners();

    final localUserMessage = ChatMessage(id: 'local_${DateTime.now().millisecondsSinceEpoch}', content: content, type: MessageType.user, timestamp: DateTime.now());
    _activeMessages.add(localUserMessage); notifyListeners();

    ChatMessage? localAiMessage;

    try {
      // Save User Message
      if(kDebugMode) print("ChatProvider: Saving user message to DB...");
      await _supabase.from('messages').insert({'conversation_id': _activeConversationId!, 'user_id': userId, 'role': 'user', 'content': content});

      // Get recent message history for context
      List<ChatMessage> contextMessages = [];
      if (_activeMessages.length > 1) {
        // Get the last N messages (excluding the one we just added)
        final startIndex = math.max(0, _activeMessages.length - 1 - _maxContextMessages);
        contextMessages = _activeMessages.sublist(startIndex, _activeMessages.length - 1);
        if(kDebugMode) print("ChatProvider: Including ${contextMessages.length} previous messages as context");
      }

      // Call Backend/AI Service with conversation history
      if(kDebugMode) print("ChatProvider: Calling backend chat service with context history...");
      final Map<String, dynamic> response = await _chatService.sendMessage(
          _activeConversationId!,
          content,
          contextMessages
      );

      // --- ADD LOGS HERE (Sending) ---
      print(">>> ChatProvider: Received from ChatService: ${response.toString()}");
      final String? aiReplyContent = response['reply'] as String?;
      List<String>? suggestionsList;
      final suggestionsData = response['suggestions']; // Get the suggestions data
      print(">>> ChatProvider: Raw suggestions data from backend: ${suggestionsData?.toString()} (Type: ${suggestionsData?.runtimeType})");
      if (suggestionsData != null && suggestionsData is List) {
        try {
          suggestionsList = suggestionsData.whereType<String>().toList();
          if (suggestionsList.isEmpty) suggestionsList = null; // Treat empty list as null for consistency
        } catch (e) {
          print(">>> ChatProvider: Error casting suggestions from backend: $e");
          suggestionsList = null;
        }
      }
      print(">>> ChatProvider: Parsed suggestions list for local message: ${suggestionsList?.toString()}");
      // --- END OF ADDED LOGS ---

      if (aiReplyContent == null || aiReplyContent.isEmpty) throw Exception("Received empty reply from assistant.");

      // Create local AI message
      localAiMessage = ChatMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch + 1}', content: aiReplyContent, type: MessageType.ai, timestamp: DateTime.now(),
        suggestions: suggestionsList, // Use parsed list
      );
      _activeMessages.add(localAiMessage);
      notifyListeners(); // Notify for optimistic UI update

      // Prepare data for saving
      final metadataToSave = {'suggestions': suggestionsList ?? []}; // Save empty list if null
      final assistantMessageDataToSave = {
        'conversation_id': _activeConversationId!, 'user_id': null, 'role': 'assistant', 'content': aiReplyContent,
        'metadata': metadataToSave, // Save parsed list (or empty)
      };

      // --- ADD LOG HERE (Sending) ---
      print(">>> ChatProvider: Metadata being saved to DB: ${jsonEncode(metadataToSave)}"); // Log JSON being saved
      // --- END OF ADDED LOG ---

      // Save Assistant Message
      if(kDebugMode) print("ChatProvider: Saving assistant message to DB...");
      await _supabase.from('messages').insert(assistantMessageDataToSave);

      // Update Conversation Timestamp
      if(kDebugMode) print("ChatProvider: Updating conversation timestamp...");
      await _supabase.from('conversations').update({'updated_at': DateTime.now().toIso8601String()}).eq('id', _activeConversationId!);

      if(kDebugMode) print("ChatProvider: Send message process complete.");

    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error during sendMessage full process: $e\n$stackTrace");
      _sendMessageError = "Failed to send message.";
      _activeMessages.remove(localUserMessage); // Attempt to remove optimistic user msg
      if (localAiMessage != null) _activeMessages.remove(localAiMessage); // Attempt to remove optimistic AI msg
      notifyListeners(); // Notify UI about the error state and removal
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
  }

  Future<void> deleteConversation(String conversationId) async {
    final userId = _authProvider?.user?.id;
    if (userId == null) { _conversationsError = "Cannot delete: User not logged in."; notifyListeners(); return; }
    if(kDebugMode) print("ChatProvider: Deleting conversation $conversationId");
    try {
      await _supabase.from('conversations').delete().eq('id', conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      if (_activeConversationId == conversationId) resetActiveChat();
      notifyListeners();
      if(kDebugMode) print("ChatProvider: Conversation $conversationId deleted locally and from DB.");
    } catch(e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error deleting conversation: $e\n$stackTrace");
      _conversationsError = "Failed to delete conversation.";
      notifyListeners();
    }
  }
}

// Add this import at the top
