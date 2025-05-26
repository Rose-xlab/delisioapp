// lib/providers/chat_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Required for WidgetsBinding
import 'package:flutter/scheduler.dart'; // Required for SchedulerPhase
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
  int _retryAfterSeconds = 0;

  bool _isQueueActive = false;
  bool _isPolling = false;
  final int _maxContextMessages = 10;

  Timer? _queueStatusDebounceTimer;
  static const Duration _queueStatusDebounceDuration = Duration(milliseconds: 1500);
  bool _isCheckingQueueStatus = false;

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
  int get retryAfterSeconds => _retryAfterSeconds;
  bool get isQueueActive => _isQueueActive;

  bool _mounted = true;
  @override
  void dispose() {
    _mounted = false;
    _queueStatusDebounceTimer?.cancel();
    super.dispose();
  }

  void _notifySafely() {
    if (!_mounted) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle ||
        WidgetsBinding.instance.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mounted) notifyListeners();
      });
    }
  }

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
        _queueStatusDebounceTimer?.cancel();
      } else {
        if (kDebugMode) print("ChatProvider: User logged in, reloading conversations.");
        loadConversations();
      }
    } else if (_authProvider?.isAuthenticated ?? false) {
      _debouncedCheckQueueStatus();
      if (subsProviderChanged && _authProvider?.token != null && _subscriptionProvider != null) {
        if (kDebugMode) print("ChatProvider: SubscriptionProvider instance updated, refreshing subscription status.");
        _subscriptionProvider!.loadSubscriptionStatus(_authProvider!.token!);
        _subscriptionProvider!.revenueCatSubscriptionStatus(_authProvider!.token!);
      }
    }
  }

  void _debouncedCheckQueueStatus() {
    if (!(_authProvider?.isAuthenticated ?? false)) return;
    _queueStatusDebounceTimer?.cancel();
    _queueStatusDebounceTimer = Timer(_queueStatusDebounceDuration, () {
      if (_authProvider?.isAuthenticated ?? false && _mounted) {
        _checkQueueStatus();
      }
    });
  }

  Future<void> _checkQueueStatus() async {
    if (_isCheckingQueueStatus || !_mounted) return;
    if (!(_authProvider?.isAuthenticated ?? false)) return;

    _isCheckingQueueStatus = true;
    final originalQueueStatus = _isQueueActive;
    bool shouldNotify = false;

    try {
      final token = _authProvider?.token;
      _isQueueActive = await _chatService.isChatQueueActive(token: token);
      if (kDebugMode) print("ChatProvider: Queue system is ${_isQueueActive ? 'active' : 'not active'}");
      if (originalQueueStatus != _isQueueActive) shouldNotify = true;
    } catch (e, stackTrace) {
      if (_isQueueActive) { _isQueueActive = false; shouldNotify = true; }
      captureException(e, stackTrace: stackTrace, hintText: 'Error checking chat queue status');
    } finally {
      _isCheckingQueueStatus = false;
      if (shouldNotify) _notifySafely();
    }
  }

  Future<void> loadConversations() async {
    if (_isLoadingConversations) return;
    final userId = _authProvider?.user?.id;
    if (userId == null) { _conversationsError = "User not logged in."; _conversations = []; _isLoadingConversations = false; _notifySafely(); return; }
    _isLoadingConversations = true; _conversationsError = null;
    _notifySafely();
    try {
      final response = await _supabase.from('conversations').select().eq('user_id', userId).order('updated_at', ascending: false);
      _conversations = response.map((data) => Conversation.fromJson(data)).toList();
    } catch (e, stackTrace) {
      _conversationsError = "Failed to load conversations."; _conversations = [];
      captureException(e, stackTrace: stackTrace, hintText: 'Error loading conversations');
    } finally {
      _isLoadingConversations = false;
      _debouncedCheckQueueStatus(); // Check queue status after loading conversations
      _notifySafely();
    }
  }

  Future<void> selectConversation(String conversationId) async {
    if (_activeConversationId == conversationId && !_isLoadingMessages) {
      if (kDebugMode) print("ChatProvider: Conversation $conversationId already selected and not loading messages.");
      if(_activeMessages.isEmpty && !_isLoadingMessages) {
        if (kDebugMode) print("ChatProvider: Active conversation $conversationId has no messages, ensuring load.");
      } else {
        return;
      }
    }

    if (kDebugMode) print("ChatProvider: Selecting conversation $conversationId");
    clearAiReplyLimitError();
    _activeConversationId = conversationId;
    _activeMessages = [];
    _messagesError = null;
    _sendMessageError = null;
    _isLoadingMessages = true;
    _notifySafely();

    await _loadMessagesForActiveConversation();
  }

  Future<void> _loadMessagesForActiveConversation() async {
    if (_activeConversationId == null) {
      _isLoadingMessages = false;
      _notifySafely();
      return;
    }
    try {
      final response = await _supabase.from('messages').select().eq('conversation_id', _activeConversationId!).order('created_at', ascending: true);
      _activeMessages = response.map((data) => ChatMessage.fromJson(data)).toList();
      _messagesError = null;
    } catch (e, stackTrace) {
      _messagesError = "Failed to load messages for conversation $_activeConversationId.";
      _activeMessages = [];
      captureException(e, stackTrace: stackTrace, hintText: 'Error loading messages for conversation $_activeConversationId');
    } finally {
      _isLoadingMessages = false;
      _notifySafely();
    }
  }

  Future<String?> createNewConversation() async {
    final userId = _authProvider?.user?.id;
    if (userId == null) {
      _conversationsError = "User not logged in.";
      _notifySafely();
      return null;
    }

    clearAiReplyLimitError();

    String? newId;
    try {
      final response = await _supabase
          .from('conversations')
          .insert({'user_id': userId})
          .select()
          .single();

      final newConversationData = response;
      newId = newConversationData['id'] as String?;

      if (newId != null) {
        final newConversation = Conversation.fromJson(newConversationData);

        _conversations.insert(0, newConversation);

        await selectConversation(newId);

        debugPrint("ChatProvider: New conversation $newId created and selected (optimistic).");
        return newId;
      } else {
        throw Exception("Failed to retrieve ID or data for new conversation from Supabase.");
      }
    } catch (e, stackTrace) {
      _conversationsError = "Failed to create new conversation.";
      captureException(e, stackTrace: stackTrace, hintText: 'Error creating new conversation');
      _notifySafely();
    }
    return newId;
  }

  Future<void> sendMessage(String content, {bool addToUi = true}) async {
    if (_isSendingMessage) return;
    if (_activeConversationId == null) {
      _sendMessageError = "No active chat selected.";
      _aiReplyLimitReachedError = false;
      _retryAfterSeconds = 0;
      _notifySafely();
      return;
    }
    _retryAfterSeconds = 0;
    final userId = _authProvider?.user?.id;

    if (userId != null && _subscriptionProvider != null) {
      if (!_subscriptionProvider!.isProSubscriber) {
        final subInfo = _subscriptionProvider!.subscriptionInfo;
        int freeAiRepliesLimit = 3; int aiRepliesRemaining = 3;
        if (subInfo != null) {
          freeAiRepliesLimit = (subInfo.aiChatRepliesLimit != -1) ? subInfo.aiChatRepliesLimit : 3;
          aiRepliesRemaining = (subInfo.aiChatRepliesRemaining != -1) ? subInfo.aiChatRepliesRemaining : freeAiRepliesLimit;
        }
        if (aiRepliesRemaining <= 0 && freeAiRepliesLimit != -1) {
          _sendMessageError = "You've used your ${subInfo?.aiChatRepliesLimit ?? freeAiRepliesLimit} free AI replies for this period. Please upgrade.";
          _aiReplyLimitReachedError = true;
          _notifySafely();
          return;
        }
      }
    }

    _isSendingMessage = true;
    _sendMessageError = null;
    _aiReplyLimitReachedError = false;

    ChatMessage? localUserMessage;
    if (addToUi) {
      localUserMessage = ChatMessage(
        id: 'local_${_uuid.v4()}', content: content, type: MessageType.user, timestamp: DateTime.now(),
      );
      _activeMessages.add(localUserMessage);
      _notifySafely();
    } else {
      _notifySafely();
    }

    addBreadcrumb(message: 'Sending chat message', category: 'chat', data: { 'conversationId': _activeConversationId, 'contentLength': content.length, 'addToUi': addToUi });

    try {
      if (userId != null && addToUi && localUserMessage != null) {
        await _supabase.from('messages').insert({
          'conversation_id': _activeConversationId!,
          'user_id': userId, 'role': 'user', 'content': content
        });
        await _supabase.from('conversations').update({'updated_at': DateTime.now().toIso8601String()}).eq('id', _activeConversationId!);
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
      final Map<String, dynamic> response = await _chatService.sendMessage(
          _activeConversationId!, content, contextMessages, token: token);

      if (kDebugMode) print(">>> ChatProvider: Received from ChatService: ${response.toString()}");

      final int statusCode = response['status_code'] as int? ?? 500;
      final String? errorType = response['error_type'] as String?;
      final String? serviceReply = response['reply'] as String?;
      final String potentialErrorMessage = serviceReply?.isNotEmpty == true ? serviceReply! : "An unexpected error occurred with the chat service.";

      if (statusCode == 429 || errorType == 'RATE_LIMITED' || errorType == 'AI_REPLY_LIMIT_REACHED') {
        _sendMessageError = potentialErrorMessage;
        _aiReplyLimitReachedError = (errorType == 'AI_REPLY_LIMIT_REACHED');
        _retryAfterSeconds = response['retry_after'] as int? ?? 30;
        if (localUserMessage != null && addToUi && _activeMessages.contains(localUserMessage)) {
          _activeMessages.remove(localUserMessage);
        }
      } else if (statusCode != 200) {
        if (kDebugMode) {
          print("ChatProvider: Handling non-200/non-429 error from ChatService. Status: $statusCode, ErrorType: $errorType");
          print("ChatProvider: Response map from ChatService: $response");
        }
        _sendMessageError = potentialErrorMessage;
        if (kDebugMode && (_sendMessageError == "An unexpected error occurred with the chat service." && (serviceReply == null || serviceReply.isEmpty) )) {
          print("ChatProvider: _sendMessageError fell back to generic message because serviceReply (from response['reply']) was null or empty.");
        }
        if (kDebugMode) print("ChatProvider: Set _sendMessageError to: $_sendMessageError");
        if (localUserMessage != null && addToUi && _activeMessages.contains(localUserMessage)) {
          _activeMessages.remove(localUserMessage);
        }
      } else {
        final String? aiReplyContent = serviceReply;
        List<String>? suggestionsList = (response['suggestions'] as List?)?.whereType<String>().toList();
        if (suggestionsList != null && suggestionsList.isEmpty) suggestionsList = null;

        if (aiReplyContent == null || aiReplyContent.isEmpty) {
          _sendMessageError = "Received an empty reply from the assistant.";
          if (kDebugMode) print("ChatProvider: Error - $_sendMessageError");
          captureException(Exception(_sendMessageError), hintText: "Empty AI reply content for query: $content");
          if (localUserMessage != null && addToUi && _activeMessages.contains(localUserMessage)) {
            _activeMessages.remove(localUserMessage);
          }
        } else {
          if (userId != null && _subscriptionProvider != null && !_subscriptionProvider!.isProSubscriber) {
            if (_authProvider?.token != null) {
              // MODIFIED: Removed forceRefresh parameter
              await _subscriptionProvider!.loadSubscriptionStatus(_authProvider!.token!);
            }
          }
          final String aiMessageDbId = _uuid.v4();
          final aiMessage = ChatMessage(
            id: aiMessageDbId,
            content: aiReplyContent, type: MessageType.ai,
            timestamp: DateTime.now(), suggestions: suggestionsList,
          );
          _activeMessages.add(aiMessage);
          if (userId != null) {
            final metadataToSave = {'suggestions': suggestionsList ?? []};
            await _supabase.from('messages').insert({
              'conversation_id': _activeConversationId!,
              'user_id': null,
              'role': 'assistant',
              'content': aiReplyContent,
              'metadata': metadataToSave,
            });
            await _supabase.from('conversations').update({'updated_at': DateTime.now().toIso8601String()}).eq('id', _activeConversationId!);
          }
          _sendMessageError = null;
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print("ChatProvider: Error during sendMessage process (outer catch): $e");
      _sendMessageError = _extractUserFacingError(e, "Failed to send message. Please try again.");
      if (_sendMessageError != null) {
        _aiReplyLimitReachedError = _sendMessageError!.toLowerCase().contains("ai repl") || _sendMessageError!.toLowerCase().contains("limit");
      } else {
        _aiReplyLimitReachedError = false;
      }
      if (localUserMessage != null && addToUi && _activeMessages.contains(localUserMessage)) {
        _activeMessages.remove(localUserMessage);
      }
      captureException(e, stackTrace: stackTrace, hintText: 'Error sending chat message. Content: $content');
    } finally {
      _isSendingMessage = false;
      _notifySafely();
    }
  }

  String _extractUserFacingError(Object error, String defaultMessage) {
    if (error is FormatException) return "There was an issue with the data format from the server.";
    String errorStr = error.toString();
    if (errorStr.startsWith("Exception: ")) errorStr = errorStr.substring("Exception: ".length);

    final errorStrLower = errorStr.toLowerCase();
    final structuredErrorMatch = RegExp(r"reply:\s*([^,}]*)").firstMatch(errorStr);
    if (structuredErrorMatch != null && errorStrLower.contains("limit")) {
      return structuredErrorMatch.group(1)?.trim() ?? "You've reached your AI reply limit. Please upgrade.";
    }
    if (structuredErrorMatch != null && errorStrLower.contains("too many requests")) {
      return structuredErrorMatch.group(1)?.trim() ?? "Too many requests. Please try again later.";
    }

    if (errorStr.length > 150 || errorStrLower.contains("socketexception") || errorStrLower.contains("httpexception") || errorStrLower.contains("communication_error")) {
      return "Failed to connect to chat service. Please check your internet connection.";
    }
    return errorStr.isEmpty ? defaultMessage : (errorStr.length > 100 ? defaultMessage : errorStr) ;
  }

  void clearAiReplyLimitError() {
    bool shouldNotify = false;
    if (_aiReplyLimitReachedError) {
      _aiReplyLimitReachedError = false;
      shouldNotify = true;
    }
    if (_sendMessageError != null) {
      final String? currentErrorLower = _sendMessageError?.toLowerCase();
      if (currentErrorLower != null &&
          (currentErrorLower.contains("ai repl") ||
              currentErrorLower.contains("limit") ||
              currentErrorLower.contains("too many requests") )) {
        _sendMessageError = null;
        shouldNotify = true;
      } else if (_sendMessageError != null) {
        _sendMessageError = null;
        shouldNotify = true;
      }
    }
    if (_retryAfterSeconds > 0) {
      _retryAfterSeconds = 0;
      shouldNotify = true;
    }

    if (shouldNotify) {
      if (kDebugMode) print("ChatProvider: Clearing AI Reply Limit/Rate Limit/Send Error state.");
      _notifySafely();
    }
  }

  void resetActiveChat() {
    clearAiReplyLimitError();
    _activeConversationId = null;
    _activeMessages = [];
    _messagesError = null;
    _isSendingMessage = false;
    if(kDebugMode) print("ChatProvider: Active chat state reset.");
    _notifySafely();
  }

  Future<void> deleteConversation(String conversationId) async {
    final userId = _authProvider?.user?.id;
    if (userId == null) { _conversationsError = "Cannot delete: User not logged in."; _notifySafely(); return; }
    try {
      await _supabase.from('conversations').delete().match({'id': conversationId, 'user_id': userId});
      _conversations.removeWhere((c) => c.id == conversationId);
      if (_activeConversationId == conversationId) {
        resetActiveChat();
      } else {
        _notifySafely();
      }
    } catch(e, stackTrace) {
      _conversationsError = "Failed to delete conversation.";
      captureException(e, stackTrace: stackTrace, hintText: 'Error deleting conversation $conversationId');
      _notifySafely();
    }
  }

  Future<void> _startPollingForResponse(String messageId) async {
    if (!_isQueueActive || !_mounted) return;
    _isPolling = true;
    int attempts = 0;
    const maxAttempts = 30;
    addBreadcrumb(message: 'Starting to poll for AI response', category: 'chat', data: {'messageId': messageId, 'maxAttempts': maxAttempts});
    while (_isPolling && attempts < maxAttempts && _mounted) {
      attempts++;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_mounted || !_isPolling) break;

      final userMessageIndex = _activeMessages.indexWhere((m) => m.id == messageId);
      bool hasResponse = false;
      if (userMessageIndex != -1 && userMessageIndex + 1 < _activeMessages.length) {
        hasResponse = _activeMessages[userMessageIndex + 1].type == MessageType.ai;
      }

      if (hasResponse) { if (kDebugMode) print("ChatProvider: Response likely received, stopping polls for $messageId"); _isPolling = false; break; }
      if (!_isSendingMessage) { if (kDebugMode) print("ChatProvider: Message sending phase no longer active, stopping polls for $messageId"); _isPolling = false; break; }
      if (kDebugMode && attempts % 10 == 0) { print("ChatProvider: Still waiting for queued response for $messageId, poll attempt $attempts"); }
    }
    if (_isPolling && attempts >= maxAttempts && _mounted) { addBreadcrumb(message: 'Polling for AI response timed out', category: 'chat', level: SentryLevel.warning, data: {'messageId': messageId, 'attempts': attempts});}
    _isPolling = false;
  }
}