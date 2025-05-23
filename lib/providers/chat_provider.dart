// lib/providers/chat_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/chat_service.dart';
import './auth_provider.dart';
import './subscription_provider.dart';
import 'dart:math' as math;
import '../config/sentry_config.dart';

class ChatProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  AuthProvider? _authProvider;
  SubscriptionProvider? _subscriptionProvider;
  final _uuid = const Uuid();

  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationsError;

  String? _activeConversationId;
  List<ChatMessage> _activeMessages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;

  bool _isSendingMessage = false;
  String? _sendMessageError;
  bool _aiReplyLimitReachedError = false;

  bool _isQueueActive = false;
  bool _isPolling = false;
  final int _maxContextMessages = 10;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;
  String? get activeConversationId => _activeConversationId;
  List<ChatMessage> get activeMessages => List.unmodifiable(_activeMessages);
  bool get isLoadingMessages => _isLoadingMessages;
  String? get messagesError => _messagesError;
  bool get isSendingMessage => _isSendingMessage;
  String? get sendMessageError => _sendMessageError;
  bool get aiReplyLimitReachedError => _aiReplyLimitReachedError;
  bool get isQueueActive => _isQueueActive;

  void updateProviders({AuthProvider? auth, SubscriptionProvider? subs}) {
    bool authChanged = _authProvider?.isAuthenticated != auth?.isAuthenticated;
    bool subsProviderChanged = _subscriptionProvider != subs;

    if (auth != null) _authProvider = auth;
    if (subs != null) _subscriptionProvider = subs;

    if (authChanged || subsProviderChanged) {
      if (kDebugMode) {
        print("ChatProvider: updateProviders called. AuthChanged: $authChanged, SubsChanged: $subsProviderChanged");
        print("  Auth State: ${auth?.isAuthenticated}, SubsProvider Instance: ${subs != null}");
        if (subs != null && subs.subscriptionInfo != null) {
          print("  SubsProvider isPro: ${subs.isProSubscriber}, SubInfo AI Limits: L=${subs.subscriptionInfo!.aiChatRepliesLimit}, R=${subs.subscriptionInfo!.aiChatRepliesRemaining}");
        } else if (subs != null) {
          print("  SubsProvider isPro: ${subs.isProSubscriber}, SubInfo: null");
        }
      }
      addBreadcrumb(
        message: 'Auth/Subs providers updated in ChatProvider',
        category: 'provider_update',
        data: {
          'authProvided': auth != null, 'subsProvided': subs != null,
          'authChanged': authChanged, 'subsProviderChanged': subsProviderChanged,
          'isProNow': _subscriptionProvider?.isProSubscriber,
          'subInfoAvailableNow': _subscriptionProvider?.subscriptionInfo != null
        },
      );
    }

    if (authChanged) {
      if (!(_authProvider?.isAuthenticated ?? false)) {
        if (kDebugMode) print("ChatProvider: User logged out, resetting chat state.");
        _conversations = []; _conversationsError = null; resetActiveChat();
      } else {
        if (kDebugMode) print("ChatProvider: User logged in, reloading conversations.");
        loadConversations();
      }
    } else if (_authProvider?.isAuthenticated ?? false) {
      _checkQueueStatus();
      if (subsProviderChanged && _authProvider?.token != null && _subscriptionProvider != null) {
        if (kDebugMode) print("ChatProvider: SubscriptionProvider instance updated, refreshing subscription status.");
        _subscriptionProvider!.loadSubscriptionStatus(_authProvider!.token!);
        _subscriptionProvider!.revenueCatSubscriptionStatus(_authProvider!.token!);
      }
    }
  }

  Future<void> _checkQueueStatus() async {
    try {
      final token = _authProvider?.token;
      if (kDebugMode && token == null && (_authProvider?.isAuthenticated ?? false) ) {
        print("ChatProvider: Attempting to check queue status for authenticated user, but token is null.");
      }
      _isQueueActive = await _chatService.isChatQueueActive(token: token);
      if (kDebugMode) print("ChatProvider: Queue system is ${_isQueueActive ? 'active' : 'not active'}");
    } catch (e, stackTrace) {
      if (kDebugMode) print("ChatProvider: Error checking queue status: $e");
      _isQueueActive = false;
      captureException(e, stackTrace: stackTrace, hint: 'Error checking chat queue status');
    }
  }

  Future<void> loadConversations() async {
    if (_isLoadingConversations) return;
    final userId = _authProvider?.user?.id;
    if (userId == null) {
      _conversationsError = "Cannot load conversations: User not logged in.";
      _conversations = [];
      _isLoadingConversations = false;
      notifyListeners();
      return;
    }
    _isLoadingConversations = true; _conversationsError = null;
    notifyListeners(); // Notify loading start

    if(kDebugMode) print("ChatProvider: Loading conversations for user $userId");
    addBreadcrumb(message: 'Loading conversations', category: 'chat', data: {'userId': userId});
    try {
      final response = await _supabase.from('conversations').select().eq('user_id', userId).order('updated_at', ascending: false);
      _conversations = response.map((data) => Conversation.fromJson(data)).toList();
      if(kDebugMode) print("ChatProvider: Loaded ${_conversations.length} conversations.");
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error loading conversations: $e\n$stackTrace");
      _conversationsError = "Failed to load conversations."; _conversations = [];
      captureException(e, stackTrace: stackTrace, hint: 'Error loading conversations');
    } finally {
      _isLoadingConversations = false;
      await _checkQueueStatus();
      notifyListeners();
    }
  }

  Future<void> selectConversation(String conversationId) async {
    if (_activeConversationId == conversationId && _activeMessages.isNotEmpty && !_isLoadingMessages) return;
    if(kDebugMode) print("ChatProvider: Selecting conversation $conversationId");
    addBreadcrumb(message: 'Selecting conversation', category: 'chat', data: {'conversationId': conversationId});

    clearAiReplyLimitError();

    _activeConversationId = conversationId;
    _activeMessages = [];
    _messagesError = null;
    _sendMessageError = null;
    _isLoadingMessages = true;
    notifyListeners();
    await _loadMessagesForActiveConversation();
  }

  Future<void> _loadMessagesForActiveConversation() async {
    if (_activeConversationId == null) {
      _isLoadingMessages = false;
      notifyListeners();
      return;
    }
    if(kDebugMode) print("ChatProvider: Loading messages for conversation $_activeConversationId");
    addBreadcrumb(message: 'Loading messages for conversation', category: 'chat', data: {'conversationId': _activeConversationId});
    try {
      final response = await _supabase.from('messages').select().eq('conversation_id', _activeConversationId!).order('created_at', ascending: true);
      _activeMessages = response.map((data) => ChatMessage.fromJson(data)).toList();
      if (kDebugMode) print("ChatProvider: Loaded ${_activeMessages.length} messages for $_activeConversationId. Last message type: ${_activeMessages.lastOrNull?.type}");
      _messagesError = null;
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error loading messages for $_activeConversationId: $e\n$stackTrace");
      _messagesError = "Failed to load messages for conversation $_activeConversationId.";
      _activeMessages = [];
      captureException(e, stackTrace: stackTrace, hint: 'Error loading messages for conversation $_activeConversationId');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<String?> createNewConversation() async {
    final userId = _authProvider?.user?.id;
    if (userId == null) {
      _conversationsError = "User not logged in.";
      notifyListeners();
      return null;
    }
    if(kDebugMode) print("ChatProvider: Creating new conversation for user $userId");
    addBreadcrumb(message: 'Creating new conversation',category: 'chat',data: {'userId': userId});

    clearAiReplyLimitError();

    _isLoadingConversations = true; notifyListeners();
    String? newId;
    try {
      final response = await _supabase.from('conversations').insert({'user_id': userId}).select('id').single();
      newId = response['id'] as String?;
      if (newId != null) {
        if(kDebugMode) print("ChatProvider: New conversation created with ID: $newId");
        await loadConversations();
        await selectConversation(newId);
        return newId;
      } else { throw Exception("Failed to retrieve ID for new conversation from Supabase."); }
    } catch (e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error creating new conversation: $e\n$stackTrace");
      _conversationsError = "Failed to create new conversation.";
      captureException(e, stackTrace: stackTrace, hint: 'Error creating new conversation');
    } finally {
      if (newId == null && _isLoadingConversations) {
        _isLoadingConversations = false;
        notifyListeners();
      }
    }
    return newId;
  }

  Future<void> sendMessage(String content, {bool addToUi = true}) async {
    if (_isSendingMessage) return;
    if (_activeConversationId == null) {
      _sendMessageError = "No active chat selected.";
      _aiReplyLimitReachedError = false;
      notifyListeners();
      return;
    }

    final userId = _authProvider?.user?.id;

    // --- PRE-SEND AI REPLY LIMIT CHECK ---
    if (userId != null && _subscriptionProvider != null) {
      if (!_subscriptionProvider!.isProSubscriber) {
        final subInfo = _subscriptionProvider!.subscriptionInfo;

        int freeAiRepliesLimit = 3;
        int aiRepliesRemaining = 3;

        if (subInfo != null) {
          // Ensure your SubscriptionInfo model has these fields and they are non-null
          // or handle nullability here.
          freeAiRepliesLimit = (subInfo.aiChatRepliesLimit != -1) ? subInfo.aiChatRepliesLimit : 3;
          aiRepliesRemaining = (subInfo.aiChatRepliesRemaining != -1) ? subInfo.aiChatRepliesRemaining : freeAiRepliesLimit;
        } else {
          if (kDebugMode) print("ChatProvider (Pre-send Check): SubscriptionInfo is null. Using default AI reply limits (Limit: $freeAiRepliesLimit, Remaining: $aiRepliesRemaining).");
        }

        if (kDebugMode) {
          print("ChatProvider --- PRE-SEND CHECK ---");
          print("  User ID: $userId, Is Pro (RevenueCat): ${_subscriptionProvider!.isProSubscriber}");
          print("  SubInfo from backend: ${subInfo != null}");
          if (subInfo != null) {
            print("    Backend Tier: ${subInfo.tier}");
            print("    Backend AI Limit: ${subInfo.aiChatRepliesLimit}");
            print("    Backend AI Used: ${subInfo.aiChatRepliesUsed}");
            print("    Backend AI Remaining: ${subInfo.aiChatRepliesRemaining}");
          }
          print("  Effective AI Limit for Check: $freeAiRepliesLimit");
          print("  Effective AI Remaining for Check: $aiRepliesRemaining");
        }

        if (aiRepliesRemaining <= 0 && freeAiRepliesLimit != -1) {
          if (kDebugMode) {
            print("ChatProvider: PRE-SEND LIMIT HIT! Remaining: $aiRepliesRemaining, Limit: $freeAiRepliesLimit. Stopping send.");
          }
          _sendMessageError = "You've used your $freeAiRepliesLimit free AI replies for this period. Please upgrade.";
          if (subInfo != null && subInfo.aiChatRepliesLimit != -1) {
            _sendMessageError = "You've used your ${subInfo.aiChatRepliesLimit} free AI replies for this period. Please upgrade.";
          }
          _aiReplyLimitReachedError = true;
          notifyListeners();
          return; // <<<< CRITICAL RETURN TO STOP EXECUTION
        }
        if (kDebugMode) {
          print("ChatProvider: Pre-send check passed. Proceeding to send message.");
        }
      }
    }
    // --- END PRE-SEND AI REPLY LIMIT CHECK ---

    _isSendingMessage = true;
    _sendMessageError = null;
    _aiReplyLimitReachedError = false;
    notifyListeners();

    addBreadcrumb(
      message: 'Sending chat message',
      category: 'chat',
      data: { 'conversationId': _activeConversationId, 'contentLength': content.length, 'addToUi': addToUi },
    );

    ChatMessage? localUserMessage;
    if (addToUi) {
      localUserMessage = ChatMessage(
        id: 'local_${_uuid.v4()}', content: content, type: MessageType.user, timestamp: DateTime.now(),
      );
      _activeMessages.add(localUserMessage);
    }

    try {
      if (userId != null && addToUi && localUserMessage != null) {
        await _supabase.from('messages').insert({
          // id is auto-generated by DB
          'conversation_id': _activeConversationId!,
          'user_id': userId, 'role': 'user', 'content': content
        });
      }

      List<ChatMessage> contextMessages = [];
      final List<ChatMessage> messagesForContext = List.from(_activeMessages);
      if (addToUi && localUserMessage != null && messagesForContext.isNotEmpty) {
        if (messagesForContext.last.id == localUserMessage.id) {
          messagesForContext.removeLast();
        }
      }
      if (messagesForContext.isNotEmpty) {
        final startIndex = math.max(0, messagesForContext.length - _maxContextMessages);
        contextMessages = messagesForContext.sublist(startIndex);
      }

      final token = _authProvider?.token;
      if (kDebugMode) print("ChatProvider: Calling backend chat service with context history (${contextMessages.length} messages)...");
      final Map<String, dynamic> response = await _chatService.sendMessage(
          _activeConversationId!, content, contextMessages, token: token);

      if (kDebugMode) print(">>> ChatProvider: Received from ChatService: ${response.toString()}");

      if (response['error'] == "AI_REPLY_LIMIT_REACHED" || response['status_code'] == 402 ) {
        _sendMessageError = response['reply'] as String? ?? "You've reached your AI reply limit. Please upgrade.";
        _aiReplyLimitReachedError = true;
        if (localUserMessage != null && addToUi && _activeMessages.contains(localUserMessage)) {
          _activeMessages.remove(localUserMessage);
        }
        _isSendingMessage = false; notifyListeners(); return;
      }

      final String? aiReplyContent = response['reply'] as String?;
      List<String>? suggestionsList;
      final suggestionsData = response['suggestions'];
      if (suggestionsData is List) {
        suggestionsList = suggestionsData.whereType<String>().toList();
        if (suggestionsList.isEmpty) suggestionsList = null;
      }

      if (aiReplyContent == null || aiReplyContent.isEmpty) {
        throw Exception("Received empty or null reply from assistant.");
      }

      if (userId != null && _subscriptionProvider != null && !_subscriptionProvider!.isProSubscriber) {
        if (kDebugMode) print("ChatProvider: AI reply generated for free user. Backend tracked usage. Refreshing SubscriptionInfo.");
        if (_authProvider?.token != null) {
          await _subscriptionProvider!.loadSubscriptionStatus(_authProvider!.token!);
        }
      }

      final String aiMessageDbId = _uuid.v4();
      final aiMessage = ChatMessage(
        id: aiMessageDbId, content: aiReplyContent, type: MessageType.ai,
        timestamp: DateTime.now(), suggestions: suggestionsList,
      );
      _activeMessages.add(aiMessage);

      if (userId != null) {
        final metadataToSave = {'suggestions': suggestionsList ?? []};
        await _supabase.from('messages').insert({
          // id is auto-generated by DB
          'conversation_id': _activeConversationId!, 'user_id': null,
          'role': 'assistant', 'content': aiReplyContent, 'metadata': metadataToSave,
        });
        await _supabase.from('conversations').update({'updated_at': DateTime.now().toIso8601String()}).eq('id', _activeConversationId!);
      }
      _sendMessageError = null;

    } catch (e, stackTrace) {
      if (kDebugMode) print("ChatProvider: Error during sendMessage process: $e");
      String errorMessage = e.toString();

      if (errorMessage.contains("AI_REPLY_LIMIT_REACHED")) {
        _aiReplyLimitReachedError = true;
        final match = RegExp(r"reply:\s*([^,}]*)").firstMatch(errorMessage);
        _sendMessageError = match?.group(1)?.trim() ?? "You've reached your AI reply limit. Please upgrade.";
      } else {
        _sendMessageError = _extractUserFacingError(e, "Failed to send message. Please try again.");
        _aiReplyLimitReachedError = false;
      }

      if (localUserMessage != null && addToUi && _activeMessages.contains(localUserMessage)) {
        _activeMessages.remove(localUserMessage);
      }
      captureException(e, stackTrace: stackTrace, hint: 'Error sending chat message. Content: $content');
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  String _extractUserFacingError(Object error, String defaultMessage) {
    if (error is FormatException) return "There was an issue with the data format from the server.";
    String errorStr = error.toString();
    if (errorStr.startsWith("Exception: ")) errorStr = errorStr.substring("Exception: ".length);

    final limitMsgMatch = RegExp(r"AI_REPLY_LIMIT_REACHED(?:.*reply: ([^,}]*))?").firstMatch(errorStr);
    if (limitMsgMatch != null) {
      return limitMsgMatch.group(1)?.trim() ?? "You've reached your AI reply limit. Please upgrade.";
    }

    if (errorStr.length > 150 || errorStr.contains("SocketException") || errorStr.contains("HttpException")) return defaultMessage;
    return errorStr.isEmpty ? defaultMessage : errorStr;
  }

  void clearAiReplyLimitError() {
    if (_aiReplyLimitReachedError ||
        (_sendMessageError != null &&
            (_sendMessageError!.toLowerCase().contains("ai repl") || _sendMessageError!.toLowerCase().contains("limit"))
        )
    ) {
      if (kDebugMode) print("ChatProvider: Clearing AI Reply Limit Error state.");
      _aiReplyLimitReachedError = false;
      _sendMessageError = null;
      notifyListeners();
    }
  }

  void resetActiveChat() {
    clearAiReplyLimitError();
    _activeConversationId = null; _activeMessages = []; _messagesError = null;
    _sendMessageError = null; _isSendingMessage = false;
    if(kDebugMode) print("ChatProvider: Active chat state reset.");
    notifyListeners();
  }

  Future<void> deleteConversation(String conversationId) async {
    final userId = _authProvider?.user?.id;
    if (userId == null) { _conversationsError = "Cannot delete: User not logged in."; notifyListeners(); return; }
    if(kDebugMode) print("ChatProvider: Deleting conversation $conversationId");
    addBreadcrumb(message: 'Deleting conversation', category: 'chat', data: {'conversationId': conversationId, 'userId': userId});
    try {
      await _supabase.from('conversations').delete().match({'id': conversationId, 'user_id': userId});
      _conversations.removeWhere((c) => c.id == conversationId);
      if (_activeConversationId == conversationId) resetActiveChat();
      notifyListeners();
    } catch(e, stackTrace) {
      if(kDebugMode) print("ChatProvider: Error deleting conversation: $e\n$stackTrace");
      _conversationsError = "Failed to delete conversation.";
      captureException(e, stackTrace: stackTrace, hint: 'Error deleting conversation $conversationId');
      notifyListeners();
    }
  }

  Future<void> _startPollingForResponse(String messageId) async {
    if (!_isQueueActive) return;
    _isPolling = true;
    int attempts = 0;
    const maxAttempts = 30;
    addBreadcrumb(message: 'Starting to poll for AI response', category: 'chat', data: {'messageId': messageId, 'maxAttempts': maxAttempts});
    while (_isPolling && attempts < maxAttempts) {
      attempts++;
      await Future.delayed(const Duration(milliseconds: 500));
      final userMessageIndex = _activeMessages.indexWhere((m) => m.id == messageId);
      bool hasResponse = false;
      if (userMessageIndex != -1 && userMessageIndex + 1 < _activeMessages.length) {
        hasResponse = _activeMessages[userMessageIndex + 1].type == MessageType.ai;
      }
      if (hasResponse) {
        if (kDebugMode) print("ChatProvider: Response likely received, stopping polls for $messageId");
        _isPolling = false;
        break;
      }
      if (!_isSendingMessage) {
        if (kDebugMode) print("ChatProvider: Message sending phase completed/failed, stopping polls for $messageId");
        _isPolling = false;
        break;
      }
      if (kDebugMode && attempts % 10 == 0) {
        print("ChatProvider: Still waiting for queued response for $messageId, poll attempt $attempts");
      }
    }
    if (_isPolling && attempts >= maxAttempts) {
      if (kDebugMode) print("ChatProvider: Polling timed out waiting for response for $messageId.");
      addBreadcrumb(message: 'Polling for AI response timed out', category: 'chat', level: SentryLevel.warning, data: {'messageId': messageId, 'attempts': attempts});
    }
    _isPolling = false;
  }
}
