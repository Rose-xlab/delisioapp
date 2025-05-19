// lib/screens/chat/chat_screen.dart
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'dart:math' as math;           // For math.min/max
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../providers/recipe_provider.dart'; // For _generateRecipeFromChat
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart'; // For injecting into ChatProvider

import '../../models/chat_message.dart';
import '../../models/conversation.dart';

import '../../widgets/chat/chat_bubble.dart';
import '../../widgets/chat/message_input.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';
import '../../widgets/common/upgrade_prompt_dialog.dart'; // Import the dialog
// import '../../constants/myofferings.dart'; // Dialog uses MyOfferings directly

// --- ConversationsDrawer (Your Full Original Code as provided before) ---
class ConversationsDrawer extends StatelessWidget {
  final String? currentConversationId;

  const ConversationsDrawer({
    Key? key,
    required this.currentConversationId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);
    final conversations = chatProvider.conversations;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.primaryColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.message_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Your Conversations',
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                    Navigator.pop(context);
                    final newConversationId = await chatProvider.createNewConversation();
                    if (newConversationId != null) {
                      if (kDebugMode) {
                        print("ConversationsDrawer: New chat selected/created. ID: $newConversationId.");
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not create new chat. Please try again.'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_comment_outlined, size: 20),
                  label: const Text('Start New Chat'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.9),
                      foregroundColor: theme.primaryColor,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: chatProvider.isLoadingConversations && conversations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                ? _buildEmptyConversationsState(theme, context)
                : _buildConversationsList(context, conversations, chatProvider, currentConversationId),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversationsState(ThemeData theme, BuildContext context) {
    // Your original _buildEmptyConversationsState implementation
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text('No conversations yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Start a new chat to ask about recipes or cooking tips!',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(
      BuildContext context,
      List<Conversation> conversations,
      ChatProvider chatProvider,
      String? currentConversationId,
      ) {
    // Your original _buildConversationsList implementation
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerColor.withOpacity(0.5)),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final isSelected = conversation.id == currentConversationId;
        final now = DateTime.now();
        final difference = now.difference(conversation.updatedAt.toLocal());
        String timeText;

        if (difference.inSeconds < 60) timeText = 'Just now';
        else if (difference.inMinutes < 60) timeText = '${difference.inMinutes}m ago';
        else if (difference.inHours < 24 && now.day == conversation.updatedAt.toLocal().day) timeText = DateFormat.jm().format(conversation.updatedAt.toLocal());
        else if (difference.inDays < 1 && now.day - 1 == conversation.updatedAt.toLocal().day) timeText = 'Yesterday';
        else if (difference.inDays < 7) timeText = DateFormat('EEE').format(conversation.updatedAt.toLocal());
        else if (now.year == conversation.updatedAt.toLocal().year) timeText = DateFormat('MMM d').format(conversation.updatedAt.toLocal());
        else timeText = DateFormat('MMM d, yyyy').format(conversation.updatedAt.toLocal());

        return Dismissible(
          key: Key(conversation.id),
          background: Container(
            color: Colors.redAccent.withOpacity(0.8),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 26),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(context: context, builder: (BuildContext ctx) => AlertDialog(title: const Text("Delete Conversation?"), content: const Text("This will permanently delete the chat history."), actions: [TextButton(onPressed: ()=>Navigator.of(ctx).pop(false), child: const Text("CANCEL")), TextButton(onPressed: ()=>Navigator.of(ctx).pop(true), child: Text("DELETE", style: TextStyle(color: Colors.red.shade700)))],)) ?? false;
          },
          onDismissed: (direction) async {
            await chatProvider.deleteConversation(conversation.id);
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : Theme.of(context).colorScheme.surfaceVariant,
              child: Icon(
                isSelected ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded,
                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            title: Text(
              conversation.title ?? 'Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
            ),
            subtitle: Text(
              timeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            selected: isSelected,
            selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.08),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            onTap: () {
              Navigator.pop(context);
              if (!isSelected) {
                chatProvider.selectConversation(conversation.id);
              }
            },
          ),
        );
      },
    );
  }
}
// --- End of ConversationsDrawer ---

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? initialQuery;
  final String? purpose;

  const ChatScreen({
    Key? key,
    this.conversationId,
    this.initialQuery,
    this.purpose,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGeneratingRecipeFromChat = false;

  String? _activeLocalConversationId;
  bool _isChatInitialized = false;

  // ***** MODIFICATION FOR DISPOSE FIX *****
  ChatProvider? _chatProviderInstance; // Store instance for dispose
  VoidCallback? _chatProviderListener;
  // ***** END MODIFICATION *****

  bool _dialogIsVisible = false;
  bool _isCurrentlyInitializing = false;

  @override
  void initState() {
    super.initState();
    // Defer provider access and initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

        // ***** MODIFICATION FOR DISPOSE FIX *****
        _chatProviderInstance = Provider.of<ChatProvider>(context, listen: false);
        // ***** END MODIFICATION *****

        _chatProviderInstance!.updateProviders(auth: authProvider, subs: subscriptionProvider);
        _initializeChatScreen();

        _chatProviderListener = () {
          if (!mounted || _chatProviderInstance == null) return; // Check instance too
          // Use the stored instance or get a fresh one if absolutely necessary, but stored is safer for listener context
          final currentChatProvider = _chatProviderInstance!;
          final providerActiveId = currentChatProvider.activeConversationId;

          if (providerActiveId != _activeLocalConversationId && providerActiveId != null) {
            if (kDebugMode) {
              print("ChatScreen Listener: Provider activeId ($providerActiveId) differs from local activeId ($_activeLocalConversationId). Re-initializing.");
            }
            setState(() {
              _activeLocalConversationId = providerActiveId;
              _isChatInitialized = false;
            });
            _initializeChatScreen(forceIdFromProvider: providerActiveId);
          }

          if (mounted && currentChatProvider.aiReplyLimitReachedError && !_dialogIsVisible) {
            if (kDebugMode) print("ChatScreen Listener: Detected aiReplyLimitReachedError. Attempting to show dialog.");
            _showUpgradeDialogIfNeeded(currentChatProvider.sendMessageError);
          }
        };
        _chatProviderInstance!.addListener(_chatProviderListener!);
      }
    });
  }

  Future<void> _initializeChatScreen({String? forceIdFromProvider}) async {
    // ... (Implementation from previous full file version, with loop fixes) ...
    if (!mounted || (_isCurrentlyInitializing && forceIdFromProvider == null) ) return;
    if (mounted) setState(() { _isCurrentlyInitializing = true; });

    if (kDebugMode) print("ChatScreen (_initializeChatScreen): Start. Forced ID: $forceIdFromProvider, Widget ID: ${widget.conversationId}, Current Local ID: $_activeLocalConversationId");

    final chatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context, listen: false); // Use stored instance
    chatProvider.updateProviders(
        auth: Provider.of<AuthProvider>(context, listen: false),
        subs: Provider.of<SubscriptionProvider>(context, listen: false)
    );

    String? targetConversationId = forceIdFromProvider ?? widget.conversationId ?? chatProvider.activeConversationId;

    if (kDebugMode) print("ChatScreen: Target Conversation ID for init: $targetConversationId");

    if (targetConversationId != null) {
      if (_activeLocalConversationId != targetConversationId || forceIdFromProvider != null) {
        if (mounted) {
          setState(() {
            _activeLocalConversationId = targetConversationId;
            _isChatInitialized = false;
          });
        } else {
          _activeLocalConversationId = targetConversationId;
        }
      }
      if (chatProvider.activeConversationId != targetConversationId ||
          (chatProvider.activeConversationId == targetConversationId && chatProvider.activeMessages.isEmpty && !chatProvider.isLoadingMessages) ||
          forceIdFromProvider != null ) {
        if (kDebugMode) print("ChatScreen: Calling selectConversation for $targetConversationId");
        await chatProvider.selectConversation(targetConversationId);
      } else {
        if (kDebugMode) print("ChatScreen: Conversation $targetConversationId already active in provider or being loaded.");
      }
    } else {
      if (kDebugMode) print("ChatScreen: No explicit conversation ID. Purpose: ${widget.purpose}.");
      if (widget.purpose == 'generateRecipe' && widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        if (kDebugMode) print("ChatScreen: Creating new conversation for 'generateRecipe' purpose.");
        targetConversationId = await chatProvider.createNewConversation();
        if (targetConversationId == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not start a new chat session.')));
          setState(() { _activeLocalConversationId = null; _isChatInitialized = true; _isCurrentlyInitializing = false; });
          return;
        }
        // If created, listener will pick up the change in activeConversationId and re-init with it.
        // Or, we can set _activeLocalConversationId here, but it might race with listener.
        // For now, rely on listener or next build cycle.
      } else {
        if (kDebugMode) print("ChatScreen: No conversation ID to initialize with and no specific purpose to create new.");
        if (mounted) {
          setState(() {
            _activeLocalConversationId = null;
            _isChatInitialized = true;
          });
        }
      }
    }

    if (!mounted) {
      if(mounted) setState(() => _isCurrentlyInitializing = false); else _isCurrentlyInitializing = false;
      return;
    }

    bool initialQueryWasAttempted = false;
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty &&
        _activeLocalConversationId != null &&
        forceIdFromProvider == null) {
      final bool alreadySentAsLast = chatProvider.activeMessages.isNotEmpty &&
          chatProvider.activeMessages.last.type == MessageType.user &&
          chatProvider.activeMessages.last.content == widget.initialQuery &&
          DateTime.now().difference(chatProvider.activeMessages.last.timestamp).inSeconds < 15;
      if (!alreadySentAsLast) {
        if (kDebugMode) print("ChatScreen: Processing initial query: '${widget.initialQuery}' for $_activeLocalConversationId");
        await _sendMessage(widget.initialQuery!);
        initialQueryWasAttempted = true;
      } else {
        if (kDebugMode) print("ChatScreen: Initial query '${widget.initialQuery}' appears to be very recently sent. Skipping.");
      }
    }

    if (mounted) {
      setState(() {
        _isChatInitialized = true;
        _isCurrentlyInitializing = false;
      });
      if (_activeLocalConversationId != null && (initialQueryWasAttempted || chatProvider.activeMessages.isNotEmpty)) {
        _scrollToBottom();
      }
    } else {
      _isCurrentlyInitializing = false;
    }
  }

  @override
  void dispose() {
    // ***** MODIFICATION FOR DISPOSE FIX *****
    if (_chatProviderListener != null && _chatProviderInstance != null) {
      try {
        _chatProviderInstance!.removeListener(_chatProviderListener!);
        if (kDebugMode) print("ChatScreen dispose: Successfully removed _chatProviderListener.");
      } catch (e) {
        if (kDebugMode) print("ChatScreen dispose: Error removing listener: $e");
        // Log to Sentry if needed, but avoid using context here.
      }
    }
    _chatProviderListener = null; // Clear the callback
    _chatProviderInstance = null; // Clear the instance
    // ***** END MODIFICATION *****

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // ... (Your original _scrollToBottom implementation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients && _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  void _showUpgradeDialogIfNeeded(String? messageFromProvider) {
    // ... (Your original _showUpgradeDialogIfNeeded implementation)
    if (!mounted || _dialogIsVisible) return;
    if (kDebugMode) print("ChatScreen: _showUpgradeDialogIfNeeded called. Message: $messageFromProvider");
    setState(() { _dialogIsVisible = true; });
    showDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'UpgradeDialog'),
      builder: (BuildContext dialogContext) => UpgradePromptDialog(
        titleText: 'AI Chat Limit Reached',
        messageText: messageFromProvider ?? "You've used all your free AI replies for this period. Please upgrade.",
        proFeatures: const [
          'Unlimited AI chat replies', 'Priority chat assistance',
          'Unlimited recipe generations', 'All features unlocked',
        ],
      ),
      barrierDismissible: false,
    ).then((_) {
      if (mounted) {
        setState(() { _dialogIsVisible = false; });
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        if (authProvider.isAuthenticated && authProvider.token != null) {
          if (kDebugMode) print("ChatScreen: Upgrade dialog dismissed. Refreshing subscription status.");
          subscriptionProvider.revenueCatSubscriptionStatus();
          subscriptionProvider.loadSubscriptionStatus(authProvider.token!);
        }
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    // ... (Your original _sendMessage implementation, ensure it uses passed 'message' or controller.text)
    final text = message.trim();
    if (!mounted) return;
    final chatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context, listen: false); // Use stored instance
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (text.isEmpty || chatProvider.isSendingMessage || _activeLocalConversationId == null) {
      return;
    }
    chatProvider.updateProviders(auth: authProvider, subs: Provider.of<SubscriptionProvider>(context, listen: false));

    final String messageToSend = _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : text;
    if(_messageController.text.isNotEmpty && _messageController.text.trim() == messageToSend) {
      _messageController.clear();
    }

    chatProvider.clearAiReplyLimitError();
    await chatProvider.sendMessage(messageToSend);
    _scrollToBottom();

    if (mounted && chatProvider.aiReplyLimitReachedError && !_dialogIsVisible) {
      if (kDebugMode) print("ChatScreen (_sendMessage): AI Reply limit was hit. Showing UpgradePromptDialog.");
      _showUpgradeDialogIfNeeded(chatProvider.sendMessageError);
    }
  }

  // --- Your original helper methods for UI (ensure these are fully implemented) ---
  String _extractRecipeName(String text) { /* ... Your implementation ... */ return text.substring(0, math.min(text.length, 50)); }
  void _onSuggestionSelected(String suggestion, bool generateRecipe) { /* ... Your implementation, ensure it calls _sendMessage for non-recipe ... */
    if (generateRecipe) _generateRecipeFromChat(suggestion); else _sendMessage(suggestion);
  }
  Future<void> _generateRecipeFromChat(String? suggestedQuery) async { /* ... Your implementation ... */ }
  Future<void> _handleStartNewChatInTab() async { /* ... Your implementation ... */ }

  @override
  Widget build(BuildContext context) {
    // ... (Your existing build method, ensure it uses _activeLocalConversationId for its primary logic) ...
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context); // Use stored instance or lookup
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

    // It's good practice to ensure ChatProvider has the latest references,
    // especially if this build method is triggered by other provider changes.
    chatProvider.updateProviders(auth: authProvider, subs: subscriptionProvider);

    final theme = Theme.of(context);
    double screenWidth = MediaQuery.sizeOf(context).width;

    if (!authProvider.isAuthenticated || authProvider.user == null) {
      return Scaffold(appBar: AppBar(title: const Text('Chat Assistant')), body: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.chat_bubble_outline_rounded, size: 60, color: theme.dividerColor), const SizedBox(height: 20), const Text('Please log in to use the AI Chat Assistant.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17)), const SizedBox(height: 24), ElevatedButton(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)), onPressed: () => Navigator.of(context).pushReplacementNamed('/login'), child: const Text('Login / Sign Up', style: TextStyle(fontSize: 16)))]))));
    }

    if (!_isChatInitialized || (_activeLocalConversationId == null && !chatProvider.isLoadingConversations && chatProvider.activeConversationId == null) ) {
      String appBarText = widget.purpose == 'generateRecipe' && widget.conversationId == null ? "Recipe Ideas Chat" : "Chat";
      return Scaffold(
        appBar: AppBar(title: Text(appBarText)),
        body: const LoadingIndicator(message: 'Initializing chat session...'),
        drawer: ConversationsDrawer(currentConversationId: _activeLocalConversationId),
      );
    }

    final bool isScreenEffectivelyDisplayingActiveChat = chatProvider.activeConversationId == _activeLocalConversationId && _activeLocalConversationId != null;

    final List<ChatMessage> messagesToDisplay = isScreenEffectivelyDisplayingActiveChat ? chatProvider.activeMessages : [];
    final bool showLoadingForMessages = isScreenEffectivelyDisplayingActiveChat ? chatProvider.isLoadingMessages : (_activeLocalConversationId != null && messagesToDisplay.isEmpty);
    final bool showSendingIndicator = isScreenEffectivelyDisplayingActiveChat && chatProvider.isSendingMessage && !chatProvider.aiReplyLimitReachedError;

    String? inlineErrorToDisplay;
    if (isScreenEffectivelyDisplayingActiveChat) {
      if (chatProvider.sendMessageError != null && !chatProvider.aiReplyLimitReachedError) {
        inlineErrorToDisplay = chatProvider.sendMessageError;
      } else if (chatProvider.messagesError != null) {
        inlineErrorToDisplay = chatProvider.messagesError;
      }
    }

    if (isScreenEffectivelyDisplayingActiveChat && messagesToDisplay.isNotEmpty) _scrollToBottom();

    Conversation? currentDisplayConversation;
    if (_activeLocalConversationId != null) {
      try {
        currentDisplayConversation = chatProvider.conversations.firstWhere((c) => c.id == _activeLocalConversationId);
      } catch (e) {
        currentDisplayConversation = Conversation(
            id: _activeLocalConversationId!, createdAt: DateTime.now(), updatedAt: DateTime.now(),
            title: (widget.purpose == 'generateRecipe' && widget.conversationId == null) ? "Recipe Ideas" : "Chat"
        );
      }
    }
    final String appBarTitle = (widget.purpose == 'generateRecipe' && widget.conversationId == null && (_activeLocalConversationId == currentDisplayConversation?.id || currentDisplayConversation == null))
        ? "Recipe Ideas Chat"
        : (currentDisplayConversation?.title?.isNotEmpty == true ? currentDisplayConversation!.title! : "Chat");

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(icon: const Icon(Icons.add_comment_outlined), tooltip: 'New Chat', onPressed: _handleStartNewChatInTab),
          if (_activeLocalConversationId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) async {
                if (value == 'rename') { if (kDebugMode) print('Rename action for $_activeLocalConversationId');}
                else if (value == 'delete') {
                  if (kDebugMode) print('Delete action for $_activeLocalConversationId');
                  // Your confirm delete dialog and chatProvider.deleteConversation call
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Rename Chat')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete Chat', style: TextStyle(color: Colors.red))])),
              ],
            ),
        ],
      ),
      drawer: ConversationsDrawer(currentConversationId: _activeLocalConversationId),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              screenWidth > 700 ? (screenWidth * 0.15) : (screenWidth > 500 ? (screenWidth * 0.05) : 8),8,
              screenWidth > 700 ? (screenWidth * 0.15) : (screenWidth > 500 ? (screenWidth * 0.05) : 8),8
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(kIsWeb ? 0.03 : 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: (showLoadingForMessages && messagesToDisplay.isEmpty)
                      ? const LoadingIndicator(message: 'Loading messages...')
                      : (inlineErrorToDisplay != null && messagesToDisplay.isEmpty)
                      ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: ErrorDisplay(message: "Error: $inlineErrorToDisplay")))
                      : (messagesToDisplay.isEmpty && !showSendingIndicator)
                      ? _buildWelcomePrompt()
                      : _buildMessagesList(messagesToDisplay),
                ),
              ),
              if (showSendingIndicator)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Text('Assistant is thinking...', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                      ),
                    ),
                  ],
                  ),
                ),

              if (inlineErrorToDisplay != null && isScreenEffectivelyDisplayingActiveChat && !showSendingIndicator)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
                  child: Text(inlineErrorToDisplay, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                ),
              MessageInput(
                controller: _messageController,
                onSend: _sendMessage,
                isLoading: chatProvider.isSendingMessage || _isGeneratingRecipeFromChat,
                hintText: 'Ask your kitchen assistant...',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Your original UI helper methods (ensure these are fully implemented in your file) ---
  Widget _buildWelcomePrompt() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.soup_kitchen_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text('Kitchen Assistant AI', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('How can I help with your cooking today?', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          ..._buildExamplePrompts(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _buildExamplePrompts() {
    final prompts = [
      {'text': 'What can I make with chicken and broccoli?', 'icon': Icons.kitchen_outlined},
      {'text': 'I need a quick dinner idea for tonight', 'icon': Icons.timer_outlined},
      {'text': 'How do I make pasta from scratch?', 'icon': Icons.restaurant_menu_outlined},
      {'text': 'Give me a healthy breakfast recipe', 'icon': Icons.breakfast_dining_outlined},
    ];
    return prompts.map((prompt) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: _buildPromptCard(prompt['text'] as String, prompt['icon'] as IconData),
      );
    }).toList();
  }

  Widget _buildPromptCard(String text, IconData icon) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14.5))),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).hintColor.withOpacity(0.7)),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        bool showHeader = false;
        if (index == 0) {
          showHeader = true;
        } else {
          final previousMessage = messages[index - 1];
          final previousDate = previousMessage.timestamp.toLocal();
          final currentDate = message.timestamp.toLocal();
          if (previousDate.year != currentDate.year || previousDate.month != currentDate.month || previousDate.day != currentDate.day || currentDate.difference(previousDate).inMinutes > 60 ) {
            showHeader = true;
          }
        }
        return Column(
          children: [
            if (showHeader) _buildDateHeader(message.timestamp),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ChatBubble(message: message, onSuggestionSelected: _onSuggestionSelected),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    String dateText;
    if (messageDate == today) dateText = 'Today';
    else if (messageDate == yesterday) dateText = 'Yesterday';
    else if (now.year == timestamp.year) dateText = DateFormat('MMMM d').format(timestamp);
    else dateText = DateFormat('MMMM d, yyyy').format(timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(children: [
        Expanded(child: Divider(color: Theme.of(context).dividerColor.withOpacity(0.5), thickness: 0.5)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Text(dateText, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor, fontWeight: FontWeight.w500))),
        Expanded(child: Divider(color: Theme.of(context).dividerColor.withOpacity(0.5), thickness: 0.5)),
      ],
      ),
    );
  }
}
