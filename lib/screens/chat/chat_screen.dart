// lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../widgets/chat/chat_bubble.dart';
import '../../widgets/chat/message_input.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';

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
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                    Navigator.pop(context); // Close drawer first

                    final newConversationId = await chatProvider.createNewConversation();
                    if (newConversationId != null) {
                      await chatProvider.selectConversation(newConversationId);
                      // NOTE: MainNavigationScreen needs to react to this provider change
                      // to update its ChatScreen tab with the newConversationId.
                      // No explicit Navigator.push... here to stay within MainNavigationScreen.
                      debugPrint("ConversationsDrawer: New chat selected. ID: $newConversationId. MainNavigationScreen should update its tab.");
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not create new chat'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Start New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.onPrimary,
                    foregroundColor: theme.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: chatProvider.isLoadingConversations
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
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new chat to begin your culinary journey!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
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
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final isSelected = conversation.id == currentConversationId;
        final now = DateTime.now();
        final difference = now.difference(conversation.updatedAt);
        String timeText;

        if (difference.inMinutes < 1) timeText = 'Just now';
        else if (difference.inHours < 1) timeText = '${difference.inMinutes}m ago';
        else if (difference.inHours < 24) timeText = '${difference.inHours}h ago';
        else if (difference.inDays < 2) timeText = 'Yesterday';
        else if (difference.inDays < 7) timeText = '${difference.inDays}d ago';
        else if (now.year == conversation.updatedAt.year) timeText = DateFormat('MMM d').format(conversation.updatedAt);
        else timeText = DateFormat('MMM d, yyyy').format(conversation.updatedAt);


        return Dismissible(
          key: Key(conversation.id),
          background: Container(
            color: Colors.redAccent,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text("Delete Conversation?"),
                  content: const Text("This action will permanently delete this conversation history."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text("CANCEL"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text("DELETE", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                );
              },
            ) ?? false;
          },
          onDismissed: (direction) async {
            String deletedConversationId = conversation.id;
            await chatProvider.deleteConversation(deletedConversationId);
            if (context.mounted && isSelected) { // If the currently active chat was deleted
              // Select another conversation or create a new one
              final conversationsAfterDeletion = chatProvider.conversations;
              String? nextConversationId;
              if (conversationsAfterDeletion.isNotEmpty) {
                nextConversationId = conversationsAfterDeletion.first.id;
              } else {
                nextConversationId = await chatProvider.createNewConversation();
              }
              if (nextConversationId != null) {
                await chatProvider.selectConversation(nextConversationId);
                // MainNavigationScreen should react to this change.
              }
            }
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
              child: Icon(
                isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
            ),
            title: Text(
              conversation.title ?? 'Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: Text(
              timeText,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            selected: isSelected,
            selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              if (!isSelected) {
                chatProvider.selectConversation(conversation.id);
                // NOTE: MainNavigationScreen needs to react to this provider change
                // to update its ChatScreen tab with the selected conversationId.
                debugPrint("ConversationsDrawer: Switched to conversation. ID: ${conversation.id}. MainNavigationScreen should update its tab.");
              }
            },
          ),
        );
      },
    );
  }
}


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

  // Listener for ChatProvider changes
  VoidCallback? _chatProviderListener;

  @override
  void initState() {
    super.initState();
    _initializeChatScreen();

    // Listen to ChatProvider for activeConversationId changes
    // This helps if another part of the app (like ConversationsDrawer) changes the active chat
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _chatProviderListener = () {
      if (!mounted) return;
      final providerActiveId = chatProvider.activeConversationId;
      if (providerActiveId != null && providerActiveId != _activeLocalConversationId) {
        debugPrint("ChatScreen (${widget.hashCode}): Detected activeConversationId change in provider: $providerActiveId. Re-initializing screen for new ID.");
        // If the active ID in provider changes, and it's different from what this screen currently shows,
        // it means MainNavigationScreen likely wants this tab to display the new active chat.
        // We can re-initialize this screen instance to load the new conversation.
        // This assumes MainNavigationScreen isn't replacing the ChatScreen instance wholesale but
        // rather expects the existing ChatScreen instance in the tab to adapt.
        // This is only effective if this ChatScreen instance is still the one in the IndexedStack.
        // A more robust solution is MainNavigationScreen replacing the ChatScreen instance in _screens[1].
        // For now, let's re-run initialization logic for this instance.
        setState(() {
          _isChatInitialized = false; // Force re-initialization visuals
          // _activeLocalConversationId = providerActiveId; // This will be set by _initializeChatScreen
        });
        _initializeChatScreen(forceIdFromProvider: providerActiveId);
      }
    };
    chatProvider.addListener(_chatProviderListener!);
  }

  // Modified to accept an optional ID to force, for listener.
  Future<void> _initializeChatScreen({String? forceIdFromProvider}) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    String? resolvedConversationId = forceIdFromProvider ?? widget.conversationId;

    if (resolvedConversationId != null) {
      debugPrint("ChatScreen (${widget.hashCode}): Initializing/Re-initializing with explicit/forced conversation ID: $resolvedConversationId");
      await chatProvider.selectConversation(resolvedConversationId);
    } else {
      debugPrint("ChatScreen (${widget.hashCode}): No explicit conversation ID. Purpose: ${widget.purpose}. Creating new.");
      resolvedConversationId = await chatProvider.createNewConversation();
      if (resolvedConversationId != null) {
        debugPrint("ChatScreen (${widget.hashCode}): New conversation created: $resolvedConversationId. Selecting it.");
        await chatProvider.selectConversation(resolvedConversationId);
      } else {
        debugPrint("ChatScreen (${widget.hashCode}): CRITICAL - Failed to create new conversation.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Could not start a new chat session.'))
          );
          setState(() { _activeLocalConversationId = null; _isChatInitialized = true; });
        }
        return;
      }
    }

    if (mounted) {
      bool hadInitialQueryToSend = false;
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty &&
          resolvedConversationId != null && forceIdFromProvider == null) { // Only send initialQuery on first load with it
        debugPrint("ChatScreen (${widget.hashCode}): Sending initial query: '${widget.initialQuery}' to conversation $resolvedConversationId");
        // Basic duplicate check for initial query
        final existingMessages = chatProvider.activeMessages;
        bool alreadySent = false;
        if (resolvedConversationId == chatProvider.activeConversationId && existingMessages.isNotEmpty) {
          final lastMessage = existingMessages.last;
          if (lastMessage.type == MessageType.user && lastMessage.content == widget.initialQuery &&
              DateTime.now().difference(lastMessage.timestamp).inSeconds < 10) {
            debugPrint("ChatScreen (${widget.hashCode}): Initial query seems to be a duplicate. Skipping send.");
            alreadySent = true;
          }
        }
        if (!alreadySent) {
          await chatProvider.sendMessage(widget.initialQuery!);
          hadInitialQueryToSend = true;
        }
      }

      setState(() {
        _activeLocalConversationId = resolvedConversationId;
        _isChatInitialized = true;
      });

      if (resolvedConversationId != null && (hadInitialQueryToSend || chatProvider.activeMessages.isNotEmpty)) {
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (_chatProviderListener != null) {
      chatProvider.removeListener(_chatProviderListener!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    final text = message.trim();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (text.isEmpty || chatProvider.isSendingMessage || _activeLocalConversationId == null) return;
    _messageController.clear();

    if (chatProvider.activeConversationId != _activeLocalConversationId) {
      await chatProvider.selectConversation(_activeLocalConversationId!);
    }

    await chatProvider.sendMessage(text);
    _scrollToBottom();
  }

  String _extractRecipeName(String text) {
    // ... (your existing _extractRecipeName method remains unchanged)
    if (text.length <= 190) return text;
    List<RegExp> recipePatterns = [
      RegExp(r"^([A-Z][A-Za-z\s''-]+(?:Bread|Cake|Soup|Pasta|Stew|Salad|Curry|Pie|Roll|Dish|Bowl|Meal))\b"),
      RegExp(r"^((?:Traditional|Classic|Authentic|Homemade|Easy|Quick|Simple|Healthy)\s+[A-Za-z\s''-]+)\b"),
      RegExp(r"^([A-Za-z]+(?:-style)\s+[A-Za-z\s''-]+)\b"),
    ];
    for (var pattern in recipePatterns) {
      var matches = pattern.firstMatch(text);
      if (matches != null && matches.group(1) != null) {
        String name = matches.group(1)!.trim();
        if (name.length >= 3 && name.length <= 100) return name;
      }
    }
    int colonIndex = text.indexOf(':');
    if (colonIndex > 3 && colonIndex < 100) return text.substring(0, colonIndex).trim();
    int periodIndex = text.indexOf('.');
    if (periodIndex > 3 && periodIndex < 100) return text.substring(0, periodIndex).trim();
    List<String> words = text.split(' ');
    if (words.length > 3) {
      int wordCount = words.length <= 12 ? words.length : 12;
      return words.take(wordCount).join(' ').trim();
    }
    return text.substring(0, text.length > 100 ? 100 : text.length).trim();
  }

  void _onSuggestionSelected(String suggestion, bool generateRecipe) {
    // ... (your existing _onSuggestionSelected method, ensure it uses _activeLocalConversationId)
    debugPrint("Suggestion selected: $suggestion, generate: $generateRecipe, current convo: $_activeLocalConversationId");
    if (_activeLocalConversationId == null) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.activeConversationId != _activeLocalConversationId) {
      chatProvider.selectConversation(_activeLocalConversationId!);
    }

    if (suggestion.toLowerCase() == "something else?") {
      _sendMessage("Something else?");
      return;
    }

    if (generateRecipe) {
      String recipeQuery = suggestion;
      if (recipeQuery.length > 190) {
        debugPrint("Original query (${recipeQuery.length} chars): '$recipeQuery'");
        String extractedName = _extractRecipeName(suggestion);
        if (extractedName.length >= 3 && extractedName.length <= 50) {
          recipeQuery = extractedName;
          print("Using extracted recipe name: '$recipeQuery'");
        } else {
          int cutPoint = 190;
          for (int i = 190; i >= 150; i--) {
            if (i < recipeQuery.length && (recipeQuery[i] == '.' || recipeQuery[i] == ',' || recipeQuery[i] == ';')) {
              cutPoint = i + 1;
              break;
            }
          }
          recipeQuery = recipeQuery.substring(0, cutPoint).trim();
          print("Truncated to ${recipeQuery.length} chars: '$recipeQuery'");
        }
      }
      _generateRecipeFromChat(recipeQuery);
    } else {
      final backgroundQuery = "Tell me more about $suggestion - what it is, how it tastes, and what ingredients I need for it.";
      debugPrint("Sending background query (will not be shown in UI): $backgroundQuery");
      chatProvider.sendMessage(backgroundQuery, addToUi: false);
      _scrollToBottom();
    }
  }

  Future<void> _generateRecipeFromChat(String? suggestedQuery) async {
    // ... (your existing _generateRecipeFromChat method remains unchanged)
    if (_isGeneratingRecipeFromChat) return;
    final String recipeQuery = suggestedQuery ?? "";
    if (recipeQuery.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not determine which recipe to generate.'), backgroundColor: Colors.orange )
        );
      }
      return;
    }
    if (mounted) setState(() => _isGeneratingRecipeFromChat = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      recipeProvider.clearCurrentRecipe();
      Navigator.of(context).pushNamed('/recipe');
      await recipeProvider.generateRecipe(
        recipeQuery, save: authProvider.isAuthenticated, token: authProvider.token,
      );
    } catch (e) { /* ... */ }
    finally { if (mounted) setState(() => _isGeneratingRecipeFromChat = false); }
  }

  // MODIFIED: _handleStartNewChat for use within the tab.
  Future<void> _handleStartNewChatInTab() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final newConversationId = await chatProvider.createNewConversation();

    if (newConversationId != null && mounted) {
      await chatProvider.selectConversation(newConversationId);
      // MainNavigationScreen should ideally react to this change in ChatProvider's
      // activeConversationId and update its _screens[1] to a new ChatScreen instance
      // or this ChatScreen instance should re-initialize based on provider change (added listener for this).
      debugPrint("ChatScreen: New chat initiated from AppBar. ID: $newConversationId. Provider's active ID updated.");
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start new chat.'))
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context); // Listen for UI updates
    final theme = Theme.of(context);
    double screenWidth = MediaQuery.sizeOf(context).width;

    if (!authProvider.isAuthenticated || authProvider.user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Please log in to Chat with AI'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                  child: const Text('Login / Sign Up'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isChatInitialized || _activeLocalConversationId == null) {
      String appBarText = "Chat";
      if (widget.purpose == 'generateRecipe' && widget.conversationId == null) {
        appBarText = "Recipe Ideas Chat";
      }
      return Scaffold(
        appBar: AppBar(title: Text(appBarText)),
        body: _activeLocalConversationId == null && _isChatInitialized
            ? const ErrorDisplay(message: "Could not initialize chat session.")
            : const LoadingIndicator(message: 'Initializing chat...'),
        drawer: ConversationsDrawer(currentConversationId: _activeLocalConversationId),
      );
    }

    final bool isEffectivelyActive = chatProvider.activeConversationId == _activeLocalConversationId;
    final messages = isEffectivelyActive ? chatProvider.activeMessages : <ChatMessage>[];
    // isLoadingMessages should reflect the status for _activeLocalConversationId
    // If chatProvider.activeConversationId has changed, and this screen instance is still visible
    // but not yet updated (e.g. listener is about to fire), isLoadingMessages might be for the wrong convo.
    // This is why having MainNavigationScreen replace the ChatScreen instance is often more robust.
    final isLoadingMessages = (chatProvider.activeConversationId == _activeLocalConversationId) ? chatProvider.isLoadingMessages : true;
    final isSendingMessage = chatProvider.isSendingMessage;
    final error = isEffectivelyActive ? chatProvider.messagesError ?? chatProvider.sendMessageError : null;

    if (isEffectivelyActive && messages.isNotEmpty) {
      _scrollToBottom();
    }

    Conversation? currentDisplayConversation;
    if (_activeLocalConversationId != null) {
      currentDisplayConversation = chatProvider.conversations.firstWhere(
              (conv) => conv.id == _activeLocalConversationId,
          orElse: () {
            return Conversation(
                id: _activeLocalConversationId!,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                title: (widget.purpose == 'generateRecipe' && widget.conversationId == null)
                    ? "Recipe Ideas"
                    : "New Chat"
            );
          }
      );
    }

    final String appBarTitle =
    (widget.purpose == 'generateRecipe' && widget.conversationId == null && _activeLocalConversationId == currentDisplayConversation?.id)
        ? "Recipe Ideas Chat" // Specifically for the first load from "Chat for Recipe Ideas"
        : (currentDisplayConversation?.title ?? "Chat");


    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Chat',
            // MODIFIED: Call _handleStartNewChatInTab
            onPressed: _handleStartNewChatInTab,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async { // Made async
              if (value == 'rename') {
                debugPrint('Rename action selected for ${_activeLocalConversationId}');
                // TODO: Implement rename logic (e.g., show a dialog)
              } else if (value == 'delete') {
                debugPrint('Delete action selected for ${_activeLocalConversationId}');
                if (_activeLocalConversationId != null) {
                  bool? confirmDelete = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text("Delete Conversation?"),
                        content: const Text("Are you sure you want to delete this chat history? This action cannot be undone."),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () { Navigator.of(dialogContext).pop(false); },
                          ),
                          TextButton(
                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                            onPressed: () { Navigator.of(dialogContext).pop(true); },
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmDelete == true && mounted) {
                    await chatProvider.deleteConversation(_activeLocalConversationId!);
                    // After deletion, ChatProvider's activeId might change or become null.
                    // The listener _chatProviderListener should pick this up,
                    // or MainNavigationScreen should react to show a new/different chat.
                    // For safety, if this instance is no longer relevant, pop it if it's a standalone route.
                    // However, if embedded, MainNavigationScreen handles the view.
                    // For now, we rely on MainNavigationScreen to update the tab.
                    // If it was the last conversation, MainNavigationScreen might take user to new chat view.
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Rename chat')]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete chat', style: TextStyle(color: Colors.red))]),
              ),
            ],
          ),
        ],
      ),
      drawer: ConversationsDrawer(currentConversationId: _activeLocalConversationId),
      body: Padding(
        // ... (rest of your body Column remains largely the same)
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: screenWidth > 600 ? 100 : 8),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isLoadingMessages && messages.isEmpty && isEffectivelyActive
                    ? const LoadingIndicator(message: 'Loading messages...')
                    : error != null && messages.isEmpty && isEffectivelyActive
                    ? ErrorDisplay(message: "Error loading chat: $error")
                    : messages.isEmpty && !isSendingMessage && isEffectivelyActive
                    ? _buildWelcomePrompt()
                    : _buildMessagesList(messages, isSendingMessage),
              ),
            ),
            if (isSendingMessage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(20)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.colorScheme.onSurfaceVariant)
                          ),
                          const SizedBox(width: 8),
                          Text('Assistant is thinking...', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (chatProvider.sendMessageError != null && isEffectivelyActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text(
                    chatProvider.sendMessageError!,
                    style: TextStyle(color: theme.colorScheme.error)
                ),
              ),
            MessageInput(
              controller: _messageController,
              onSend: _sendMessage,
              isLoading: isSendingMessage || _isGeneratingRecipeFromChat,
              hintText: 'Ask about recipes, cooking tips, or meal ideas...',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePrompt() {
    // ... (Welcome prompt remains unchanged)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.restaurant,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Kitchen Assistant',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'How can I help with your cooking today?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._buildExamplePrompts(),
        ],
      ),
    );
  }

  List<Widget> _buildExamplePrompts() {
    // ... (Example prompts remain unchanged)
    final prompts = [
      {'text': 'What can I make with chicken and broccoli?', 'icon': Icons.shopping_basket_outlined},
      {'text': 'I need a quick dinner idea for tonight', 'icon': Icons.timer_outlined},
      {'text': 'How do I make pasta from scratch?', 'icon': Icons.menu_book_outlined},
      {'text': 'Give me a healthy breakfast recipe', 'icon': Icons.breakfast_dining_outlined},
    ];

    return prompts.map((prompt) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _buildPromptCard(prompt['text'] as String, prompt['icon'] as IconData),
      );
    }).toList();
  }

  Widget _buildPromptCard(String text, IconData icon) {
    // ... (Prompt card remains unchanged)
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessage> messages, bool isSendingMessage) {
    // ... (Messages list remains unchanged)
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
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
          if (previousDate.year != currentDate.year ||
              previousDate.month != currentDate.month ||
              previousDate.day != currentDate.day) {
            showHeader = true;
          }
        }

        return Column(
          children: [
            if (showHeader) _buildDateHeader(message.timestamp),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ChatBubble(
                message: message,
                onSuggestionSelected: _onSuggestionSelected,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime timestamp) {
    // ... (Date header remains unchanged)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else if (now.year == timestamp.year) {
      dateText = DateFormat('MMM d').format(timestamp);
    }
    else {
      dateText = DateFormat('MMM d, yyyy').format(timestamp);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }
}