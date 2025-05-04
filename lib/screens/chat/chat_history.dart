// lib/screens/chat/chat_screen.dart - Updated with production-ready recipe extraction

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

class ChatHistoryScreen extends StatefulWidget {
  final String conversationId;

  const ChatHistoryScreen({
    required this.conversationId,
    Key? key,
  }) : super(key: key);

  @override
  _ChatHistoryScreenState createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGenerating = false;
  String? _generatedRecipeId;

  @override
  void initState() {
    super.initState();
    debugPrint("ChatScreen: Initializing for conversation ID: ${widget.conversationId}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) {
        Provider.of<ChatProvider>(context, listen: false).selectConversation(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
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
    if (text.isEmpty || chatProvider.isSendingMessage) return;
    _messageController.clear();

    await chatProvider.sendMessage(text);
    _scrollToBottom();
  }

  // Improved recipe name extraction with multiple strategies
  String _extractRecipeName(String text) {
    // If the text is already reasonably short, just use it
    if (text.length <= 190) return text;

    // Try to find recipe name patterns first
    List<RegExp> recipePatterns = [
      // Match common recipe name formats with food types
      RegExp(r"^([A-Z][A-Za-z\s''-]+(?:Bread|Cake|Soup|Pasta|Stew|Salad|Curry|Pie|Roll|Dish|Bowl|Meal))\b"),
      // Match a recipe name that starts with 'Traditional', 'Classic', etc.
      RegExp(r"^((?:Traditional|Classic|Authentic|Homemade|Easy|Quick|Simple|Healthy)\s+[A-Za-z\s''-]+)\b"),
      // Match "X-style Y" patterns (e.g., "Italian-style Lasagna")
      RegExp(r"^([A-Za-z]+(?:-style)\s+[A-Za-z\s''-]+)\b"),
    ];

    // Try each pattern
    for (var pattern in recipePatterns) {
      var matches = pattern.firstMatch(text);
      if (matches != null && matches.group(1) != null) {
        String name = matches.group(1)!.trim();
        if (name.length >= 3 && name.length <= 100) {
          return name;
        }
      }
    }

    // Try to extract name based on punctuation
    // Look for name ending with a colon
    int colonIndex = text.indexOf(':');
    if (colonIndex > 3 && colonIndex < 100) {
      return text.substring(0, colonIndex).trim();
    }

    // Look for name ending with a period or new paragraph
    int periodIndex = text.indexOf('.');
    if (periodIndex > 3 && periodIndex < 100) {
      return text.substring(0, periodIndex).trim();
    }

    // If all else fails, take the first sentence or a reasonable number of words
    List<String> words = text.split(' ');
    if (words.length > 3) {
      int wordCount = words.length <= 12 ? words.length : 12; // Max 12 words
      return words.take(wordCount).join(' ').trim();
    }

    // Last resort: just take the first part of the text
    return text.substring(0, text.length > 100 ? 100 : text.length).trim();
  }

  void _onSuggestionSelected(String suggestion, bool generateRecipe) {
    debugPrint("Suggestion selected in ChatScreen: $suggestion, generate: $generateRecipe");

    // Special handling for "Something else?" option
    if (suggestion.toLowerCase() == "something else?") {
      _sendMessage("Something else?");
      return;
    }

    if (generateRecipe) {
      // Process the suggestion for recipe generation
      String recipeQuery = suggestion;

      // Only process if we exceed or approach the limit (leaving some margin)
      if (recipeQuery.length > 190) {
        debugPrint("Original query (${recipeQuery.length} chars): '$recipeQuery'");

        // Try intelligent extraction first
        String extractedName = _extractRecipeName(suggestion);

        // If the extracted name is reasonable in length and not too short
        if (extractedName.length >= 3 && extractedName.length <= 50) {
          recipeQuery = extractedName;
          print("Using extracted recipe name: '$recipeQuery'");
        } else {
          // If extraction failed, use basic truncation but try to cut at a sensible point
          int cutPoint = 190;
          // Try to cut at a sentence or phrase boundary if possible
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
      _sendMessage("Tell me more about $suggestion - what it is, how it tastes, and what ingredients I need for it.");
    }
  }

  void _viewExistingRecipe() {
    if (_generatedRecipeId == null) return;
    Navigator.of(context).pushNamed('/recipe');
  }

  Future<void> _generateRecipeFromChat(String? suggestedQuery) async {
    if (_isGenerating) return;

    final String recipeQuery = suggestedQuery ?? "";
    if (recipeQuery.isEmpty) {
      print("Error: Cannot generate recipe. No valid query context found from suggestion.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not determine which recipe to generate.'),
                backgroundColor: Colors.orange
            )
        );
      }
      return;
    }

    // Set generating state to prevent multiple clicks
    if (mounted) setState(() => _isGenerating = true);

    debugPrint("Attempting to generate recipe for: $recipeQuery from chat context.");

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

      // Clear any previous recipe to ensure we start fresh
      recipeProvider.clearCurrentRecipe();

      // Instead of showing a loading indicator, immediately navigate to recipe screen
      // The recipe screen will handle showing the loading/generation progress
      Navigator.of(context).pushNamed('/recipe');

      // Start the recipe generation after navigation
      await recipeProvider.generateRecipe(
        recipeQuery,
        save: authProvider.isAuthenticated,
        token: authProvider.token,
      );

      debugPrint("Recipe generation initiated via RecipeProvider...");

      // We don't need to navigate again, as we already did it before generation started
      if (mounted && recipeProvider.error != null) {
        debugPrint("RecipeProvider has error: ${recipeProvider.error}");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error generating recipe: ${recipeProvider.error}'),
                backgroundColor: Colors.red
            )
        );
      }
    } catch (e) {
      debugPrint("Error caught in _generateRecipeFromChat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error generating recipe: ${e.toString()}'),
                backgroundColor: Colors.red
            )
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showConversationsDrawer() {
    // Refresh the conversations list first
    Provider.of<ChatProvider>(context, listen: false).loadConversations();

    Scaffold.of(context).openDrawer();
  }

  void _startNewChat() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final newConversationId = await chatProvider.createNewConversation();

    if (newConversationId != null && mounted) {
      Navigator.of(context).pushReplacementNamed('/chat', arguments: newConversationId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not start new chat.'),
              backgroundColor: Colors.red
          )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);

    final bool isActiveConversation = chatProvider.activeConversationId == widget.conversationId;
    final messages = isActiveConversation ? chatProvider.activeMessages : <ChatMessage>[];
    final isLoadingMessages = isActiveConversation ? chatProvider.isLoadingMessages : false;
    final isSendingMessage = chatProvider.isSendingMessage;
    final error = isActiveConversation ? chatProvider.messagesError ?? chatProvider.sendMessageError : null;
    double screenWidth = MediaQuery.sizeOf(context).width;

    if (isActiveConversation && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) _scrollToBottom();
      });
    }

    // Find the current conversation for the title
    final currentConversation = chatProvider.conversations
        .firstWhere((conv) => conv.id == widget.conversationId,
        orElse: () => Conversation(
            id: widget.conversationId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            title: 'New Chat'
        ));

    final String appBarTitle = currentConversation.title ?? 'Chat';

    return Scaffold(
      appBar: AppBar(
        leading:IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_sharp),
            tooltip: 'Back',
            onPressed: (){
              Navigator.pop(context);
            },
          ),
        title: Text(
          appBarTitle,
          style: const TextStyle(fontSize: 18), // Slightly smaller for longer titles
        ),
        actions: [
          // New chat button
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                // TODO: Implement rename conversation
              } else if (value == 'delete') {
                // TODO: Implement delete conversation
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Rename chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),

          
        ],
      ),
      
      // drawer: ConversationsDrawer(
      //   currentConversationId: widget.conversationId,
      // ),
      body: Padding(

        padding: EdgeInsets.symmetric(vertical: 8,horizontal:screenWidth > 600 ? 100 : 8),
        child: Column(
              
          children: [
            // Messages area
            Expanded(
              child: Container(
                color: theme.colorScheme.surface.withOpacity(0.3),
                child: isLoadingMessages && messages.isEmpty
                    ? const LoadingIndicator(message: 'Loading messages...')
                    : error != null && messages.isEmpty
                    ? ErrorDisplay(message: "Error loading chat: $error")
                    : messages.isEmpty && !isSendingMessage
                    ? _buildWelcomePrompt()
                    : _buildMessagesList(messages, isSendingMessage),
              ),
            ),
        
            // Indicators
            if (isSendingMessage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20)
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5)
                          ),
                          SizedBox(width: 8),
                          Text('Assistant is thinking...', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        
            // Error message
            if (chatProvider.sendMessageError != null && isActiveConversation)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text(
                    chatProvider.sendMessageError!,
                    style: TextStyle(color: theme.colorScheme.error)
                ),
              ),
        
            // Message input
            MessageInput(
              controller: _messageController,
              onSend: _sendMessage,
              isLoading: isSendingMessage || _isGenerating,
              hintText: 'Ask about recipes, cooking tips, or meal ideas...',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePrompt() {
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
            'Delisio Cooking Assistant',
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

          // Example prompts in attractive cards
          ..._buildExamplePrompts(),
        ],
      ),
    );
  }

  List<Widget> _buildExamplePrompts() {
    final prompts = [
      {'text': 'What can I make with chicken and broccoli?', 'icon': Icons.shopping_basket},
      {'text': 'I need a quick dinner idea', 'icon': Icons.timer},
      {'text': 'How do I make pasta from scratch?', 'icon': Icons.restaurant_menu},
      {'text': 'Give me a healthy breakfast recipe', 'icon': Icons.breakfast_dining},
    ];

    return prompts.map((prompt) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _buildPromptCard(prompt['text'] as String, prompt['icon'] as IconData),
      );
    }).toList();
  }

  Widget _buildPromptCard(String text, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: Colors.grey[800]),
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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        // Check if we should show a timestamp header
        bool showHeader = false;
        if (index == 0) {
          showHeader = true; // Always show for first message
        } else {
          // Check if this message is from a different day than previous
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
            // Optional date header
            if (showHeader)
              _buildDateHeader(message.timestamp),

            // The actual message bubble
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day
    );

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      // Format as Month Day, Year (e.g. April 15, 2023)
      final month = [
        'January', 'February', 'March', 'April',
        'May', 'June', 'July', 'August',
        'September', 'October', 'November', 'December'
      ][timestamp.month - 1];
      dateText = '$month ${timestamp.day}, ${timestamp.year}';
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

class ConversationsDrawer extends StatelessWidget {
  final String currentConversationId;

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
                const SizedBox(height: 20),
                // New Chat Button
                ElevatedButton.icon(
                  onPressed: () async {
                    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                    Navigator.pop(context); // Close drawer

                    final newConversationId = await chatProvider.createNewConversation();
                    if (newConversationId != null) {
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed(
                            '/chat',
                            arguments: newConversationId
                        );
                      }
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
                  icon: const Icon(Icons.add),
                  label: const Text('New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    minimumSize: const Size(200, 44),
                  ),
                ),
              ],
            ),
          ),

          // Conversations List
          Expanded(
            child: chatProvider.isLoadingConversations
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                ? _buildEmptyConversationsState(theme)
                : _buildConversationsList(context, conversations, chatProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversationsState(ThemeData theme) {
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
              'Start a new chat to begin cooking conversations',
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
      ChatProvider chatProvider
      ) {
    return ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
      final conversation = conversations[index];
      final isSelected = conversation.id == currentConversationId;

      // Format relative time (e.g. "2h ago", "Yesterday", etc.)
      final now = DateTime.now();
      final difference = now.difference(conversation.updatedAt);
      String timeText;

      if (difference.inMinutes < 1) {
        timeText = 'Just now';
      } else if (difference.inHours < 1) {
        timeText = '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        timeText = '${difference.inHours}h ago';
      } else if (difference.inDays < 2) {
        timeText = 'Yesterday';
      } else if (difference.inDays < 7) {
        timeText = '${difference.inDays}d ago';
      } else {
        // Format as Month Day (e.g. Apr 15)
        final DateFormat formatter = DateFormat('MMM d');
        timeText = formatter.format(conversation.updatedAt);
      }

      return Dismissible(
          key: Key(conversation.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Delete Conversation?"),
                  content: const Text(
                      "This will permanently delete this conversation history."
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("CANCEL"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        "DELETE",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) async {
            await chatProvider.deleteConversation(conversation.id);
            if (context.mounted && isSelected) {
              // If the deleted conversation was the active one, create a new chat
              final newConversationId = await chatProvider.createNewConversation();
              if (newConversationId != null && context.mounted) {
                Navigator.of(context).pushReplacementNamed(
                    '/chat',
                    arguments: newConversationId
                );
              }
            }
          },
          child: ListTile(
          leading: CircleAvatar(
          backgroundColor: isSelected
          ? Theme.of(context).primaryColor
        : Colors.grey[200],
    child: Icon(
    Icons.chat_bubble_outline,
    color: isSelected
    ? Colors.white
        : Colors.grey[600],
    size: 20,
    ),
    ),
    title: Text(
    conversation.title ?? 'Chat ${index + 1}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    ),
    ),
    subtitle: Text(
    timeText,
    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
    ),
    selected: isSelected,
    selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    ),
    onTap: () {
    Navigator.pop(context); // Close drawer
    // Only navigate if selecting a different conversation
    if (!isSelected) {
    Navigator.of(context).pushReplacementNamed(
    '/chat',
    arguments: conversation.id
    );
    }
    },
    trailing: PopupMenuButton<String>(
    icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
    onSelected: (value) async {
    if (value == 'rename') {
    // TODO: Add rename functionality
    } else if (value == 'delete') {
    final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
    title: const Text("Delete Conversation?"),
    content: const Text(
    "This will permanently delete this conversation history."
    ),
    actions: [
    TextButton(
    onPressed: () => Navigator.of(context).pop(false),
    child: const Text("CANCEL"),
    ),
    TextButton(
    onPressed: () => Navigator.of(context).pop(true),
    child: const Text(
    "DELETE",
    style: TextStyle(color: Colors.red),
    ),
    ),
    ],
    ),
    ) ?? false;

    if (confirmed && context.mounted) {
    await chatProvider.deleteConversation(conversation.id);

    if (context.mounted && isSelected) {
    // If the deleted conversation was the active one, create a new chat
    final newConversationId = await chatProvider.createNewConversation();
    if (newConversationId != null && context.mounted) {
    Navigator.of(context).pushReplacementNamed(
    '/chat',
    arguments: newConversationId
    );
    }
    }
    }
    }
    },
    itemBuilder: (context) => [
    const PopupMenuItem(
    value: 'rename',
    child: Row(
    children: [
    Icon(Icons.edit, size: 20),
    SizedBox(width: 8),
    Text('Rename'),
    ],
    ),
    ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 20, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ],
    ),
          ),
      );
        },
    );
  }
}