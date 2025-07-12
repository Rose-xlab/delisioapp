// lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/recipe.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';

import '../../widgets/chat/chat_bubble.dart';
import '../../widgets/chat/message_input.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';
import '../../widgets/common/upgrade_prompt_dialog.dart';


// --- ConversationsDrawer (remains unchanged from your provided code) ---
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
        else timeText = DateFormat('MMM d, yy').format(conversation.updatedAt.toLocal());

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
            final String title = conversation.title ?? 'Chat';
            await chatProvider.deleteConversation(conversation.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Conversation "$title" deleted'), duration: const Duration(seconds: 2))
              );
            }
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
  List<ChatMessage> _activeMessages = [];
  bool _isLoadingMessages = false;

  bool _isChatInitialized = false;

  ChatProvider? _chatProviderInstance;
  VoidCallback? _chatProviderListener;

  bool _isCurrentlyInitializingGlobal = false;
  bool _isHandlingNewChatFromFab = false;
  Timer? _retryMessageTimer;
  bool _dialogIsVisible = false;

  @override
  void initState() {
    super.initState();
    debugPrint("ChatScreen initState: convId=${widget.conversationId}, purpose=${widget.purpose}, key=${widget.key}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

        _chatProviderInstance = Provider.of<ChatProvider>(context, listen: false);
        _chatProviderInstance!.updateProviders(auth: authProvider, subs: subscriptionProvider);
        _initializeChatScreen();

        _chatProviderListener = () {
          if (!mounted || _chatProviderInstance == null) return;
          final currentChatProvider = _chatProviderInstance!;
          final providerActiveId = currentChatProvider.activeConversationId;

          if (providerActiveId != _activeLocalConversationId && providerActiveId != null) {
            if (kDebugMode) {
              print("ChatScreen Listener: Provider activeId ($providerActiveId) changed from local activeId ($_activeLocalConversationId). Re-initializing ChatScreen.");
            }
            _initializeChatScreen(forceIdFromProvider: providerActiveId);
          } else if (providerActiveId == _activeLocalConversationId && mounted){
            bool needsSetState = false;
            if (!listEquals(_activeMessages, currentChatProvider.activeMessages)) {
              _activeMessages = List.from(currentChatProvider.activeMessages);
              needsSetState = true;
            }
            if (_isLoadingMessages != currentChatProvider.isLoadingMessages) {
              _isLoadingMessages = currentChatProvider.isLoadingMessages;
              needsSetState = true;
            }
            if (needsSetState) setState(() {});
          }

          if (mounted && currentChatProvider.aiReplyLimitReachedError && !_dialogIsVisible) {
            if (kDebugMode) print("ChatScreen Listener: Detected aiReplyLimitReachedError. Attempting to show dialog.");
            _showUpgradeDialogIfNeeded(currentChatProvider.sendMessageError);
          }

          if (mounted && currentChatProvider.retryAfterSeconds > 0 && currentChatProvider.sendMessageError != null && !currentChatProvider.aiReplyLimitReachedError) {
            if (kDebugMode) print("ChatScreen Listener: Rate limit hit. Retry after ${currentChatProvider.retryAfterSeconds}s. Error: ${currentChatProvider.sendMessageError}");
            setState(() {});
          }
        };
        _chatProviderInstance!.addListener(_chatProviderListener!);
      }
    });
  }

  Future<void> _initializeChatScreen({String? forceIdFromProvider}) async {
    if (!mounted) return;

    if (_isCurrentlyInitializingGlobal && forceIdFromProvider == null && !(widget.purpose == 'newChatFromFab' && !_isHandlingNewChatFromFab && widget.conversationId == null) ) {
      debugPrint("ChatScreen _initialize: Skipping due to ongoing initialization and no forceId or new FAB intent.");
      return;
    }

    if(mounted) {
      setState(() {
        _isCurrentlyInitializingGlobal = true;
        if (!(widget.purpose == 'newChatFromFab' && widget.conversationId == null && !_isHandlingNewChatFromFab)) {
          _isChatInitialized = false;
        }
      });
    }

    final chatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context, listen: false);
    chatProvider.updateProviders(
        auth: Provider.of<AuthProvider>(context, listen: false),
        subs: Provider.of<SubscriptionProvider>(context, listen: false));

    String? targetConversationIdForThisScreen;

    if (widget.purpose == 'newChatFromFab' && widget.conversationId == null && !_isHandlingNewChatFromFab) {
      debugPrint("ChatScreen _initialize: First-time setup for 'newChatFromFab'.");
      _isHandlingNewChatFromFab = true;
      targetConversationIdForThisScreen = null;

      if (mounted) {
        setState(() {
          _activeLocalConversationId = null;
          _activeMessages = [];
          _isLoadingMessages = false;
          _isChatInitialized = true;
        });
      }
      await _initiateNewConversationInBackground().then((_) { // Ensure this completes before setting init flags false
        if (mounted) setState(() { _isCurrentlyInitializingGlobal = false; });
      }).catchError((e) {
        if (mounted) setState(() { _isCurrentlyInitializingGlobal = false; });
        debugPrint("Error in background new conversation creation: $e");
      });
      return;

    } else if (widget.purpose == 'newChatFromFab' && widget.conversationId == null && _isHandlingNewChatFromFab) {
      debugPrint("ChatScreen _initialize: Already in/processed 'newChatFromFab' state. LocalID: $_activeLocalConversationId. ProviderID: ${chatProvider.activeConversationId}");
      if (mounted) {
        setState(() {
          if (chatProvider.activeConversationId != null && _activeLocalConversationId != chatProvider.activeConversationId) {
            _activeLocalConversationId = chatProvider.activeConversationId;
            _activeMessages = List.from(chatProvider.activeMessages);
            _isLoadingMessages = chatProvider.isLoadingMessages;
          }
          _isChatInitialized = true;
          _isCurrentlyInitializingGlobal = false;
        });
      }
      return;
    } else {
      targetConversationIdForThisScreen = forceIdFromProvider ?? widget.conversationId ?? chatProvider.activeConversationId;
      // _isHandlingNewChatFromFab = false; // Reset only if transitioning away from FAB logic specifically
      if (widget.purpose != 'newChatFromFab') _isHandlingNewChatFromFab = false;

      debugPrint("ChatScreen _initialize: Standard/Forced. TargetID: $targetConversationIdForThisScreen "
          "(force: $forceIdFromProvider, widget: ${widget.conversationId}, provider: ${chatProvider.activeConversationId})");
    }

    if (targetConversationIdForThisScreen != null) {
      bool needsProviderSelect = chatProvider.activeConversationId != targetConversationIdForThisScreen ||
          (chatProvider.activeConversationId == targetConversationIdForThisScreen && chatProvider.activeMessages.isEmpty && !chatProvider.isLoadingMessages);

      if (_activeLocalConversationId != targetConversationIdForThisScreen || forceIdFromProvider != null || !_isChatInitialized || needsProviderSelect) {
        debugPrint("ChatScreen _initialize: Updating to/loading for $targetConversationIdForThisScreen.");
        if (mounted) {
          setState(() {
            _activeLocalConversationId = targetConversationIdForThisScreen;
            _activeMessages = [];
            _isLoadingMessages = true;
            _isChatInitialized = false;
          });
        }

        await chatProvider.selectConversation(targetConversationIdForThisScreen);

        if (mounted) {
          setState(() {
            _activeMessages = List.from(chatProvider.activeMessages);
            _isLoadingMessages = chatProvider.isLoadingMessages;
            _isChatInitialized = true;
          });
        }
      } else {
        debugPrint("ChatScreen _initialize: Already on target $targetConversationIdForThisScreen and initialized. Syncing state.");
        if (mounted) {
          bool changed = false;
          if (!listEquals(_activeMessages, chatProvider.activeMessages)) { _activeMessages = List.from(chatProvider.activeMessages); changed = true; }
          if (_isLoadingMessages != chatProvider.isLoadingMessages) { _isLoadingMessages = chatProvider.isLoadingMessages; changed = true; }
          if (changed) setState((){});
          if (!_isChatInitialized) setState(() => _isChatInitialized = true );
        }
      }
    } else {
      debugPrint("ChatScreen _initialize: No targetId. Displaying empty/welcome.");
      if (mounted) {
        setState(() {
          _activeLocalConversationId = null;
          _activeMessages = [];
          _isLoadingMessages = false;
          _isChatInitialized = true;
        });
      }
    }

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty &&
        _activeLocalConversationId != null &&
        forceIdFromProvider == null &&
        _isChatInitialized ) {

      final bool alreadySentAsLast = _activeMessages.isNotEmpty &&
          _activeMessages.last.type == MessageType.user &&
          _activeMessages.last.content == widget.initialQuery &&
          DateTime.now().difference(_activeMessages.last.timestamp).inSeconds < 15;

      if (!alreadySentAsLast) {
        debugPrint("ChatScreen _initialize: Processing initial query: '${widget.initialQuery}' for $_activeLocalConversationId");
        await _sendMessage(widget.initialQuery!);
      } else {
        debugPrint("ChatScreen _initialize: Initial query '${widget.initialQuery}' appears recently sent. Skipping.");
      }
    }

    if (mounted) {
      setState(() { _isCurrentlyInitializingGlobal = false; });
      if (_activeLocalConversationId != null && _activeMessages.isNotEmpty) {
        _scrollToBottom();
      }
    }
  }

  Future<void> _initiateNewConversationInBackground() async {
    debugPrint("ChatScreen (FAB): Starting background new conversation creation.");
    final chatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context, listen: false);
    final newConvId = await chatProvider.createNewConversation();

    if (mounted) {
      if (newConvId != null) {
        debugPrint("ChatScreen (FAB): Background creation complete. New ID: $newConvId. Provider selected it.");
        if (_activeLocalConversationId != newConvId) { // Sync if listener hasn't updated it yet
          setState(() {
            _activeLocalConversationId = newConvId;
            _activeMessages = List.from(chatProvider.activeMessages);
            _isLoadingMessages = false;
          });
        }
      } else {
        debugPrint("ChatScreen (FAB): Background creation failed.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error starting new chat. Please try again.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _retryMessageTimer?.cancel();
    if (_chatProviderListener != null && _chatProviderInstance != null) {
      _chatProviderInstance!.removeListener(_chatProviderListener!);
    }
    _chatProviderListener = null;
    _chatProviderInstance = null;

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
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
    if (!mounted || _dialogIsVisible) return;
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
          subscriptionProvider.revenueCatSubscriptionStatus(authProvider.token!);
          subscriptionProvider.loadSubscriptionStatus(authProvider.token!);
        }
      }
    });
  }

  Future<void> _sendMessage(String messageContent) async {
    final text = messageContent.trim();
    if (!mounted || text.isEmpty) return;

    final chatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? conversationIdForSend = _activeLocalConversationId;

    chatProvider.updateProviders(auth: authProvider, subs: Provider.of<SubscriptionProvider>(context, listen: false));

    if (conversationIdForSend == null) {
      // This condition is primarily for a FAB-initiated new chat where the ID isn't established yet.
      if (widget.purpose == 'newChatFromFab' && _isHandlingNewChatFromFab) {
        debugPrint("ChatScreen SendMessage: First message for a new FAB chat. Creating conversation context first.");

        final tempOptimisticMessage = ChatMessage(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
            content: text, type: MessageType.user,
            timestamp: DateTime.now());
        if (mounted) {
          setState(() { _activeMessages.add(tempOptimisticMessage); });
          _scrollToBottom();
        }

        final newConvId = await chatProvider.createNewConversation();
        if (mounted) {
          _activeMessages.removeWhere((m) => m.id == tempOptimisticMessage.id);
          if (newConvId != null) {
            setState(() { _activeLocalConversationId = newConvId; });
            conversationIdForSend = newConvId;
            // ChatProvider's activeConversationId is now newConvId
            debugPrint("ChatScreen SendMessage: New conversation $newConvId created and selected. Proceeding to send.");
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create chat session. Message not sent.'), backgroundColor: Colors.redAccent),
            );
            return;
          }
        } else {
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No active chat session to send message.'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    // Ensure ChatProvider's active ID is aligned before calling its sendMessage.
    // This is vital because createNewConversation (called above) sets the provider's active ID.
    if (chatProvider.activeConversationId != conversationIdForSend) {
      debugPrint("ChatScreen SendMessage: Aligning provider's active ID to $conversationIdForSend before sending.");
      await chatProvider.selectConversation(conversationIdForSend); // Ensure provider is on the right chat
    }

    // Critical check: After attempting to align, is the provider's activeId correct?
    if (chatProvider.activeConversationId == null || chatProvider.activeConversationId != conversationIdForSend) {
      debugPrint("ChatScreen SendMessage: CRITICAL - Provider's active ID is still not set or mismatched after select/create. Aborting send. Provider Active ID: ${chatProvider.activeConversationId}, Expected: $conversationIdForSend");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Chat session mismatch. Please try again.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (chatProvider.isSendingMessage || chatProvider.retryAfterSeconds > 0) {
      if (chatProvider.retryAfterSeconds > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Please wait ~${chatProvider.retryAfterSeconds}s before sending."),
            backgroundColor: Colors.orangeAccent, duration: const Duration(seconds: 2)));
      }
      return;
    }

    final originalMessageInController = _messageController.text;
    if (_messageController.text.trim() == text) {
      _messageController.clear();
    }

    final localUserMessage = ChatMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        content: text, type: MessageType.user, timestamp: DateTime.now());
    if (mounted) {
      setState(() { _activeMessages.add(localUserMessage); });
      _scrollToBottom();
    }

    // ChatProvider will handle backend & AI reply. addToUi: false because ChatScreen handles its own optimistic UI for user messages.
    await chatProvider.sendMessage(text, addToUi: false);

    if (mounted) {
      if (chatProvider.sendMessageError != null) {
        setState(() {
          _activeMessages.removeWhere((m) => m.id == localUserMessage.id);
          if(_messageController.text.isEmpty) _messageController.text = originalMessageInController;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(chatProvider.sendMessageError!), backgroundColor: Colors.redAccent));
      } else {
        // Success, provider would have updated its activeMessages with the AI reply. Sync.
        setState(() { _activeMessages = List.from(chatProvider.activeMessages); });
        _scrollToBottom();
      }

      if (chatProvider.retryAfterSeconds > 0 && !chatProvider.aiReplyLimitReachedError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(chatProvider.sendMessageError ?? "Rate limit. Wait ~${chatProvider.retryAfterSeconds}s."),
            backgroundColor: Colors.orangeAccent));
        _retryMessageTimer?.cancel();
        _retryMessageTimer = Timer(Duration(seconds: chatProvider.retryAfterSeconds), () {
          if (mounted) chatProvider.clearAiReplyLimitError();
        });
      }
    }
  }

  String _extractRecipeName(String text) {
    const maxLength = 50;
    if (text.length <= maxLength) return text;
    int endIndex = text.lastIndexOf('.', maxLength);
    if (endIndex == -1) endIndex = text.lastIndexOf(' ', maxLength);
    return text.substring(0, endIndex == -1 ? maxLength : endIndex + 1);
  }

  void _onSuggestionSelected(String suggestion, bool generateRecipe) {
    if (kDebugMode) print("Suggestion selected: '$suggestion', Generate Recipe: $generateRecipe");
    if (generateRecipe) {
      _generateRecipeFromChat(suggestion);
    } else {
      _sendMessage(suggestion);
    }
  }

  Future<void> _generateRecipeFromChat(String? suggestedQuery) async {
    if (_isGeneratingRecipeFromChat) return;
    if (!mounted) return;

    final query = suggestedQuery?.trim() ?? _messageController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter what recipe you want to generate.')),
        );
      }
      return;
    }

    if (mounted) setState(() { _isGeneratingRecipeFromChat = true; });

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final Recipe? recipe = await recipeProvider.generateRecipe(
        query,
        save: authProvider.isAuthenticated,
        token: authProvider.token,
        conversationId: _activeLocalConversationId,
      );

      if (recipe != null && mounted && !recipeProvider.wasCancelled) {
        Navigator.of(context).pushNamed('/recipe');
      } else if (recipeProvider.wasCancelled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe generation from chat cancelled.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (kDebugMode) print("Error generating recipe from chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating recipe: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isGeneratingRecipeFromChat = false; });
      }
    }
  }

  Future<void> _handleStartNewChatInTab() async {
    if (!mounted) return;
    final chatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context, listen: false);
    final newConversationId = await chatProvider.createNewConversation();
    if (newConversationId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a new chat. Please try again.'), backgroundColor: Colors.redAccent),
      );
    }
    // If successful, the ChatProvider listener should update _activeLocalConversationId
    // via _initializeChatScreen(forceIdFromProvider: newId) and ChatScreen will rebuild.
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context);

    final theme = Theme.of(context);
    double screenWidth = MediaQuery.sizeOf(context).width;

    if (!authProvider.isAuthenticated || authProvider.user == null) {
      return Scaffold(
          appBar: AppBar(
            title: const Text('Chat Assistant'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
            elevation: 0,
            shape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5), width: 0.5)),
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          ),
          body: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.chat_bubble_outline_rounded, size: 60, color: theme.dividerColor), const SizedBox(height: 20), const Text('Please log in to use the AI Chat Assistant.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17)), const SizedBox(height: 24), ElevatedButton(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)), onPressed: () => Navigator.of(context).pushReplacementNamed('/login'), child: const Text('Login / Sign Up', style: TextStyle(fontSize: 16)))]))));
    }

    bool showScreenLoader = !_isChatInitialized || _isCurrentlyInitializingGlobal;
    if (widget.purpose == 'newChatFromFab' && widget.conversationId == null && _isChatInitialized && !_isCurrentlyInitializingGlobal) {
      showScreenLoader = false;
    }

    if (showScreenLoader) {
      String appBarText = (widget.purpose == 'generateRecipe' && widget.conversationId == null) ? "Recipe Ideas Chat" : "Chat";
      if(_activeLocalConversationId != null) {
        try {
          final tempChatProvider = Provider.of<ChatProvider>(context, listen: false);
          final currentConv = tempChatProvider.conversations.firstWhere((c) => c.id == _activeLocalConversationId,
              orElse: () => Conversation(id: _activeLocalConversationId!, createdAt: DateTime.now(), updatedAt: DateTime.now(), title: "Chat"));
          appBarText = currentConv.title ?? "Chat";
        } catch(e) { /* keep default appBarText */ }
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(appBarText),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
          elevation: 0,
          shape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5), width: 0.5)),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: LoadingIndicator(message: _activeLocalConversationId == null && widget.purpose != 'newChatFromFab'
            ? 'Initializing chat session...'
            : 'Loading messages...'),
        drawer: ConversationsDrawer(currentConversationId: _activeLocalConversationId),
      );
    }

    final bool actuallyShowLoadingForMessages = _isLoadingMessages && _activeMessages.isEmpty;
    final bool showSendingIndicator = chatProvider.isSendingMessage && !chatProvider.aiReplyLimitReachedError && chatProvider.retryAfterSeconds == 0;

    String? inlineErrorToDisplay;
    if (chatProvider.sendMessageError != null && !chatProvider.aiReplyLimitReachedError && _activeLocalConversationId == chatProvider.activeConversationId) {
      inlineErrorToDisplay = chatProvider.sendMessageError;
      if (chatProvider.retryAfterSeconds > 0) {
        if (chatProvider.sendMessageError!.toLowerCase().contains("too many requests") ||
            chatProvider.sendMessageError!.toLowerCase().contains("rate limit")) {
          inlineErrorToDisplay = "Too many requests. Please wait ~${chatProvider.retryAfterSeconds}s.";
        }
      }
    } else if (chatProvider.messagesError != null && _activeLocalConversationId == chatProvider.activeConversationId) {
      inlineErrorToDisplay = chatProvider.messagesError;
    }

    Conversation? currentDisplayConversation;
    String appBarTitle = "Chat";
    if (_activeLocalConversationId != null) {
      try {
        // Ensure provider instance is available
        final currentChatProvider = _chatProviderInstance ?? Provider.of<ChatProvider>(context, listen: false);
        currentDisplayConversation = currentChatProvider.conversations.firstWhere((c) => c.id == _activeLocalConversationId);
        appBarTitle = currentDisplayConversation.title ?? "Chat";
      } catch (e) {
        appBarTitle = (widget.purpose == 'newChatFromFab' && widget.conversationId == null && _activeLocalConversationId == null) ? "New Chat" : "Chat";
      }
    } else if (widget.purpose == 'newChatFromFab' && widget.conversationId == null) {
      appBarTitle = "New Chat";
    }

    if (_activeMessages.isNotEmpty && _scrollController.hasClients) {
      if (_scrollController.position.atEdge) {
        if (_scrollController.position.pixels == _scrollController.position.minScrollExtent && _activeMessages.length > 1) {
          // Don't scroll if at top unless it's a new message making it scrollable
        } else {
          _scrollToBottom();
        }
      } else if (_activeMessages.last.type == MessageType.user || (_activeMessages.length >1 && _activeMessages.last.type == MessageType.ai) ) {
        // Scroll if last message is user, or if AI message just arrived
        _scrollToBottom();
      }
    } else if (_activeMessages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w500
        ),
        title: Text(appBarTitle),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actionsIconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(icon: const Icon(Icons.add_comment_outlined), tooltip: 'New Chat', onPressed: _handleStartNewChatInTab),
          if (_activeLocalConversationId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) async {
                if (value == 'rename') {
                  // Implement rename logic
                } else if (value == 'delete') {
                  final bool? confirmDelete = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext ctx) => AlertDialog(
                        title: const Text("Delete Conversation?"),
                        content: const Text("This will permanently delete this chat history."),
                        actions: [
                          TextButton(onPressed: ()=>Navigator.of(ctx).pop(false), child: const Text("CANCEL")),
                          TextButton(onPressed: ()=>Navigator.of(ctx).pop(true), child: Text("DELETE", style: TextStyle(color: Colors.red.shade700)))
                        ],
                      )
                  ) ?? false;

                  if (confirmDelete == true && mounted && _activeLocalConversationId != null) {
                    final String deletedTitle = currentDisplayConversation?.title ?? 'Chat';
                    // Store context before async gap
                    final navContext = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    await chatProvider.deleteConversation(_activeLocalConversationId!);

                    if (mounted) { // Recheck mounted after await
                      scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Conversation "$deletedTitle" deleted.'), duration: const Duration(seconds: 2))
                      );
                      // Resetting provider's active chat is done in deleteConversation.
                      // ChatScreen needs to react to this, usually by _initializeChatScreen being called by listener.
                      // Or, if MainNavigationScreen handles the "after delete" logic better, that's an option.
                      // For now, re-initialize to pick up new state (e.g. no active chat, or next chat).
                      _initializeChatScreen();
                    }
                  }
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
          padding: () {
            const double mobileOuterPadding = 0.0;
            const double tabletOuterPadding = 8.0;
            const double maxChatColumnWidth = 768.0;

            if (screenWidth <= 500) {
              return EdgeInsets.symmetric(horizontal: mobileOuterPadding, vertical: 8.0);
            } else if (screenWidth <= 800) {
              return EdgeInsets.symmetric(horizontal: tabletOuterPadding, vertical: 8.0);
            } else {
              final double horizontalPaddingForCentering = (screenWidth - maxChatColumnWidth) / 2;
              return EdgeInsets.symmetric(
                  horizontal: horizontalPaddingForCentering > tabletOuterPadding ? horizontalPaddingForCentering : tabletOuterPadding,
                  vertical: 8.0
              );
            }
          }(),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(kIsWeb ? 0.03 : 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: (actuallyShowLoadingForMessages && _activeMessages.isEmpty)
                      ? LoadingIndicator(message: 'Loading messages...')
                      : (inlineErrorToDisplay != null && _activeMessages.isEmpty && !chatProvider.aiReplyLimitReachedError)
                      ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: ErrorDisplay(message: "$inlineErrorToDisplay")))
                      : (_activeMessages.isEmpty && !showSendingIndicator)
                      ? _buildWelcomePrompt(isNewChat: _activeLocalConversationId == null)
                      : _buildMessagesList(_activeMessages),
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
                      ],),
                    ),
                  ],),
                ),
              if (inlineErrorToDisplay != null &&
                  !showSendingIndicator &&
                  !chatProvider.aiReplyLimitReachedError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
                  child: Text(inlineErrorToDisplay, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: MessageInput(
                  controller: _messageController,
                  onSend: _sendMessage,
                  isLoading: chatProvider.isSendingMessage || _isGeneratingRecipeFromChat || (chatProvider.retryAfterSeconds > 0 && !chatProvider.aiReplyLimitReachedError),
                  hintText: 'Ask your kitchen assistant...',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePrompt({bool isNewChat = false}) {
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
            child: Icon(Icons.assistant, size: 48, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(isNewChat ? 'AI' : 'AI', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('How can I help \nwith your cooking today?', style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color:Colors.grey[500]), textAlign: TextAlign.center),
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
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200] ?? Colors.grey)),
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14.5))),
            Icon(Icons.send_rounded, size: 16, color: Colors.grey[600]),
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
    else dateText = DateFormat('MMMM d, yy').format(timestamp);

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