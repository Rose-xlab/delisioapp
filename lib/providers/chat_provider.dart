// lib/providers/chat_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
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

  // This is the 'mounted' flag for the provider
  bool _mounted = true;

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

  @override
  void dispose() {
    _mounted = false; // Set to false when disposed
    _queueStatusDebounceTimer?.cancel();
    super.dispose();
  }

  void _notifySafely() {
    if (!_mounted) return; // Use the local _mounted flag
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle ||
        WidgetsBinding.instance.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mounted) notifyListeners(); // Use the local _mounted flag
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
      if (_authProvider?.isAuthenticated ?? false && _mounted) { // Use _mounted
        _checkQueueStatus();
      }
    });
  }

  Future<void> _checkQueueStatus() async {
    if (_isCheckingQueueStatus || !_mounted) return; // Use _mounted
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
    // ... (implementation as before, ensure _mounted checks if doing async UI updates)
    if (_isLoadingConversations) return;
    final userId = _authProvider?.user?.id;
    if (userId == null) { _conversationsError = "User not logged in."; _conversations = []; _isLoadingConversations = false; _notifySafely(); return; }
    _isLoadingConversations = true; _conversationsError = null;
    _notifySafely();
    try {
      final response = await _supabase.from('conversations').select().eq('user_id', userId).order('updated_at', ascending: false);
      if (!_mounted) return; // Check after await
      _conversations = response.map((data) => Conversation.fromJson(data)).toList();
    } catch (e, stackTrace) {
      if (!_mounted) return;
      _conversationsError = "Failed to load conversations."; _conversations = [];
      captureException(e, stackTrace: stackTrace, hintText: 'Error loading conversations');
    } finally {
      if (_mounted) {
        _isLoadingConversations = false;
        _debouncedCheckQueueStatus();
        _notifySafely();
      }
    }
  }

  Future<void> selectConversation(String conversationId) async {
    if (_activeConversationId == conversationId) {
      if (_isLoadingMessages) {
        if (kDebugMode) print("ChatProvider: Already loading messages for $conversationId. selectConversation call ignored.");
        return;
      }
      if (_activeMessages.isNotEmpty) {
        if (kDebugMode) print("ChatProvider: Conversation $conversationId already selected and messages loaded. selectConversation call ignored.");
        return;
      }
      if (kDebugMode) print("ChatProvider: Conversation $conversationId is active but messages empty. Proceeding to load.");
    }


    if (kDebugMode) print("ChatProvider: Selecting conversation $conversationId. Current active: $_activeConversationId");

    final String idToLoad = conversationId;

    _activeConversationId = idToLoad;
    _activeMessages = [];
    _messagesError = null;
    _sendMessageError = null;
    _isLoadingMessages = true;
    clearAiReplyLimitError();

    _notifySafely();

    List<ChatMessage> loadedMessages = [];
    String? loadError;

    try {
      if (!_mounted || _activeConversationId != idToLoad) {
        if (kDebugMode) print("ChatProvider: Active ID changed during selectConversation for $idToLoad. Aborting this load.");
        if (_isLoadingMessages && _activeConversationId != idToLoad) _isLoadingMessages = false;
        return;
      }
      final response = await _supabase.from('messages').select().eq('conversation_id', idToLoad).order('created_at', ascending: true);
      if (!_mounted || _activeConversationId != idToLoad) {
        if (kDebugMode) print("ChatProvider: Active ID changed after message load for $idToLoad. Discarding results.");
        if (_isLoadingMessages) _isLoadingMessages = false;
        return;
      }
      loadedMessages = response.map((data) => ChatMessage.fromJson(data)).toList();
    } catch (e, stackTrace) {
      if (!_mounted || _activeConversationId != idToLoad) {
        if (kDebugMode) print("ChatProvider: Active ID changed during message load error for $idToLoad. Discarding error.");
        if (_isLoadingMessages) _isLoadingMessages = false;
        return;
      }
      loadError = "Failed to load messages for conversation $idToLoad.";
      captureException(e, stackTrace: stackTrace, hintText: 'Error loading messages for conversation $idToLoad');
    } finally {
      if (_mounted && _activeConversationId == idToLoad) {
        _activeMessages = loadedMessages;
        _messagesError = loadError;
        _isLoadingMessages = false;
        _notifySafely();
      } else if (_mounted && _isLoadingMessages && _activeConversationId != idToLoad) {
        _isLoadingMessages = false;
      }
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

      if (!_mounted) return null; // Check after await

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
      if(_mounted) _notifySafely();
    }
    return newId;
  }

  // DEFINITION for _updateConversationTitle
  Future<void> _updateConversationTitle(String conversationId, String newTitle) async {
    if (!_mounted) return;
    try {
      final newUpdatedAt = DateTime.now();
      await _supabase
          .from('conversations')
          .update({'title': newTitle, 'updated_at': newUpdatedAt.toIso8601String()})
          .eq('id', conversationId);

      if (!_mounted) return; // Check after await

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = _conversations[index].copyWith(
          title: newTitle,
          updatedAt: newUpdatedAt,
        );
        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _notifySafely();
      }
      if (kDebugMode) print("ChatProvider: Conversation title updated to '$newTitle' for ID $conversationId");
    } catch (e, stackTrace) {
      if (kDebugMode) print("ChatProvider: Error updating conversation title: $e");
      captureException(e, stackTrace: stackTrace, hintText: 'Error updating conversation title for $conversationId');
      // Don't rethrow or block other operations if title update fails
    }
  }

  Future<void> sendMessage(String content, {bool addToUi = true}) async {
    if (_isSendingMessage) return;
    if (_activeConversationId == null) {
      _sendMessageError = "No active chat selected (sendMessage check).";
      _aiReplyLimitReachedError = false;
      _retryAfterSeconds = 0;
      if (kDebugMode) print("ChatProvider sendMessage: Aborting, _activeConversationId is null.");
      _notifySafely();
      return;
    }

    _retryAfterSeconds = 0;
    final userId = _authProvider?.user?.id;

    // Subscription check
    if (userId != null && _subscriptionProvider != null) {
      if (!_subscriptionProvider!.isProSubscriber) {
        final subInfo = _subscriptionProvider!.subscriptionInfo;
        int freeAiRepliesLimit = 3;
        int aiRepliesRemaining = 3;
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

    bool shouldAttemptTitleUpdate = false;
    if (content.isNotEmpty) {
      try {
        final currentConversation = _conversations.firstWhere((c) => c.id == _activeConversationId);
        if (currentConversation.title == null ||
            currentConversation.title!.isEmpty ||
            currentConversation.title!.startsWith("Chat - ")) {
          final bool isFirstUserMessageInLoaded = _activeMessages.where((m) => m.type == MessageType.user).isEmpty;
          if (addToUi ? isFirstUserMessageInLoaded : true) {
            shouldAttemptTitleUpdate = true;
          }
        }
      } catch (e) {
        final bool isFirstUserMessageInLoaded = _activeMessages.where((m) => m.type == MessageType.user).isEmpty;
        if (addToUi ? isFirstUserMessageInLoaded : true) {
          shouldAttemptTitleUpdate = true;
        }
        if (kDebugMode) print("ChatProvider: Titling check - conversation $_activeConversationId for title update not in _conversations list (might be new). Proceeding based on _activeMessages state.");
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

    // Ensure addBreadcrumb has message if it's required. Assuming it's fine for now.
    // addBreadcrumb(message: 'Sending chat message', category: 'chat', data: { 'conversationId': _activeConversationId, 'contentLength': content.length, 'addToUi': addToUi });

    try {
      if (userId != null) {
        await _supabase.from('messages').insert({
          'conversation_id': _activeConversationId!,
          'user_id': userId, 'role': 'user', 'content': content
        });

        if (shouldAttemptTitleUpdate) {
          String newTitle = content.trim();
          const maxLength = 35;
          if (newTitle.length > maxLength) {
            newTitle = "${newTitle.substring(0, maxLength - 3)}...";
          } else if (newTitle.isEmpty) {
            newTitle = "Chat";
          }
          await _updateConversationTitle(_activeConversationId!, newTitle);
        } else {
          final newUpdatedAtForSend = DateTime.now();
          await _supabase.from('conversations')
              .update({'updated_at': newUpdatedAtForSend.toIso8601String()})
              .eq('id', _activeConversationId!);

          if(_mounted) { // Check mounted before modifying state
            final convIndex = _conversations.indexWhere((c) => c.id == _activeConversationId);
            if (convIndex != -1) {
              _conversations[convIndex] = _conversations[convIndex].copyWith(updatedAt: newUpdatedAtForSend);
              _conversations.sort((a,b) => b.updatedAt.compareTo(a.updatedAt));
            }
          }
        }
      }

      List<ChatMessage> contextMessages = [];
      final List<ChatMessage> messagesForContextBuild = List.from(_activeMessages);
      if (localUserMessage != null && messagesForContextBuild.isNotEmpty && messagesForContextBuild.last.id == localUserMessage.id) {
        messagesForContextBuild.removeLast();
      }
      if (messagesForContextBuild.isNotEmpty) {
        final startIndex = math.max(0, messagesForContextBuild.length - _maxContextMessages);
        contextMessages = messagesForContextBuild.sublist(startIndex);
      }

      final token = _authProvider?.token;
      final Map<String, dynamic> response = await _chatService.sendMessage(
          _activeConversationId!, content, contextMessages, token: token);

      if (!_mounted) return; // Check after await

      final int statusCode = response['status_code'] as int? ?? 500;
      final String? errorType = response['error_type'] as String?;
      final String? serviceReply = response['reply'] as String?;
      final String potentialErrorMessage = serviceReply?.isNotEmpty == true ? serviceReply! : "An unexpected error occurred with the chat service.";

      if (statusCode == 429 || errorType == 'RATE_LIMITED' || errorType == 'AI_REPLY_LIMIT_REACHED') {
        _sendMessageError = potentialErrorMessage;
        _aiReplyLimitReachedError = (errorType == 'AI_REPLY_LIMIT_REACHED');
        _retryAfterSeconds = response['retry_after'] as int? ?? 30;
        if (addToUi && localUserMessage != null && _activeMessages.contains(localUserMessage)) {
          _activeMessages.remove(localUserMessage);
        }
      } else if (statusCode != 200) {
        _sendMessageError = potentialErrorMessage;
        if (addToUi && localUserMessage != null && _activeMessages.contains(localUserMessage)) {
          _activeMessages.remove(localUserMessage);
        }
      } else {
        final String? aiReplyContent = serviceReply;
        List<String>? suggestionsList = (response['suggestions'] as List?)?.whereType<String>().toList();
        if (suggestionsList != null && suggestionsList.isEmpty) suggestionsList = null;

        if (aiReplyContent == null || aiReplyContent.isEmpty) {
          _sendMessageError = "Received an empty reply from the assistant.";
        } else {
          if (userId != null && _subscriptionProvider != null && !_subscriptionProvider!.isProSubscriber) {
            if (_authProvider?.token != null) {
              await _subscriptionProvider!.loadSubscriptionStatus(_authProvider!.token!);
            }
          }
          final aiMessage = ChatMessage(
            id: _uuid.v4(),
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
          }
          _sendMessageError = null;
        }
      }
    } catch (e, stackTrace) {
      _sendMessageError = _extractUserFacingError(e, "Failed to send message. Please try again.");
      if (_sendMessageError != null) {
        _aiReplyLimitReachedError = _sendMessageError!.toLowerCase().contains("ai repl") || _sendMessageError!.toLowerCase().contains("limit");
      } else {
        _aiReplyLimitReachedError = false;
      }
      if (addToUi && localUserMessage != null && _activeMessages.contains(localUserMessage)) {
        _activeMessages.remove(localUserMessage);
      }
      captureException(e, stackTrace: stackTrace, hintText: 'Error sending chat message. Content: $content');
    } finally {
      if(_mounted){
        _isSendingMessage = false;
        _notifySafely();
      }
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
      if (!_mounted) return; // Check after await
      _conversations.removeWhere((c) => c.id == conversationId);
      if (_activeConversationId == conversationId) {
        resetActiveChat();
      } else {
        _notifySafely();
      }
    } catch(e, stackTrace) {
      if (!_mounted) return;
      _conversationsError = "Failed to delete conversation.";
      captureException(e, stackTrace: stackTrace, hintText: 'Error deleting conversation $conversationId');
      _notifySafely();
    }
  }

  Future<void> _startPollingForResponse(String messageId) async {
    if (!_isQueueActive || !_mounted) return;
    _isPolling = true;
    // ... (rest of method as before, ensuring _mounted checks in loops/timers)
  }
}