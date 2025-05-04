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

class ChatScreen extends StatefulWidget {
  final String conversationId;

  const ChatScreen({
    required this.conversationId,
    Key? key,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGenerating = false;
  // String? _generatedRecipeId; // This seemed unused, commented out. If needed, uncomment.



  

  @override
  void initState() {
    super.initState();
    debugPrint("ChatScreen: Initializing for conversation ID: ${widget.conversationId} ********");
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

  // This local _sendMessage is for messages typed by the user in the input field.
  // These messages SHOULD appear in the UI.
  Future<void> _sendMessage(String message) async {
    final text = message.trim();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (text.isEmpty || chatProvider.isSendingMessage) return;
    _messageController.clear();

    // Calls ChatProvider.sendMessage with default addToUi: true
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
    final chatProvider = Provider.of<ChatProvider>(context, listen: false); // Get provider

    // Special handling for "Something else?" option
    if (suggestion.toLowerCase() == "something else?") {
      // This is a user-initiated conversational turn, so it should be visible.
      // Use the local _sendMessage which handles the text controller and calls
      // chatProvider.sendMessage() with default addToUi: true.
      _sendMessage("Something else?");
      return;
    }

    if (generateRecipe) {
      // --- Your existing recipe generation logic ---
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
      // --- End of your existing recipe generation logic ---
    } else {
      // ** MODIFIED PART **
      // Send the follow-up query in the background WITHOUT adding it to the UI.
      // The "Assistant is thinking..." indicator will show because ChatProvider's
      // _isSendingMessage state will be true.
      final backgroundQuery = "Tell me more about $suggestion - what it is, how it tastes, and what ingredients I need for it.";
      debugPrint("Sending background query (will not be shown in UI): $backgroundQuery");

      // Directly call the ChatProvider's sendMessage with addToUi: false
      chatProvider.sendMessage(backgroundQuery, addToUi: false);

      // _messageController.clear(); // Not strictly needed here as this action doesn't originate from the text field.
      _scrollToBottom(); // Still good to scroll if messages are long, to see thinking indicator.
    }
  }

  // This seemed unused (_generatedRecipeId was never set), so commented out.
  // If you need it, ensure _generatedRecipeId is being set appropriately.
  // void _viewExistingRecipe() {
  //   if (_generatedRecipeId == null) return;
  //   Navigator.of(context).pushNamed('/recipe');
  // }

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

    if (mounted) setState(() => _isGenerating = true);
    debugPrint("Attempting to generate recipe for: $recipeQuery from chat context.");

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      recipeProvider.clearCurrentRecipe();
      Navigator.of(context).pushNamed('/recipe');
      await recipeProvider.generateRecipe(
        recipeQuery,
        save: authProvider.isAuthenticated,
        token: authProvider.token,
      );
      debugPrint("Recipe generation initiated via RecipeProvider...");
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
    Provider.of<ChatProvider>(context, listen: false).loadConversations();
    Scaffold.of(context).openDrawer(); // Use Scaffold.of(context) if inside Scaffold's child
  }

  void _startNewChat() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final newConversationId = await chatProvider.createNewConversation();

    if (newConversationId != null && mounted) {
      // Use pushReplacement to avoid stacking chat screens if already in one
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
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);

    final bool isActiveConversation = chatProvider.activeConversationId == widget.conversationId;
    final messages = isActiveConversation ? chatProvider.activeMessages : <ChatMessage>[];
    final isLoadingMessages = isActiveConversation ? chatProvider.isLoadingMessages : false;
    final isSendingMessage = chatProvider.isSendingMessage; // This triggers "Assistant is thinking..."
    final error = isActiveConversation ? chatProvider.messagesError ?? chatProvider.sendMessageError : null;
    double screenWidth = MediaQuery.sizeOf(context).width;
    final user = authProvider.user;
    
    if (!authProvider.isAuthenticated || user == null) {
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

     // User object from AuthProvider
    final user = authProvider.user;


     // --- Authentication Check ---
    if (!authProvider.isAuthenticated || user == null) { // Also check if user object is null
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
                  // Use pushReplacementNamed for login to replace the current screen
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                  child: const Text('Login / Sign Up'), // More inviting text
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isActiveConversation && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) _scrollToBottom();
      });
    }

    final currentConversation = chatProvider.conversations
        .firstWhere((conv) => conv.id == widget.conversationId,
        orElse: () => Conversation(
            id: widget.conversationId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            title: 'New Chat' // Default title if not found (e.g., truly new)
        ));

    final String appBarTitle = currentConversation.title ?? 'Chat'; // Use loaded title or default

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
            onPressed: _startNewChat,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              // TODO: Implement rename and delete conversation actions
              if (value == 'rename') {
                debugPrint('Rename action selected');
              } else if (value == 'delete') {
                debugPrint('Delete action selected');
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
      drawer: ConversationsDrawer( // Ensure ConversationsDrawer is correctly implemented
        currentConversationId: widget.conversationId,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: screenWidth > 600 ? 100 : 8),
        child: Column(
          children: [
            Expanded(
              child: Container(
                // Consider a slightly different color or an explicit border
                // if theme.colorScheme.surface.withOpacity(0.3) is too subtle.
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.1), // Adjusted opacity for subtlety
                  borderRadius: BorderRadius.circular(8), // Optional: adds rounded corners
                  // border: Border.all(color: theme.dividerColor) // Optional: adds a border
                ),
                child: isLoadingMessages && messages.isEmpty
                    ? const LoadingIndicator(message: 'Loading messages...')
                    : error != null && messages.isEmpty
                    ? ErrorDisplay(message: "Error loading chat: $error")
                    : messages.isEmpty && !isSendingMessage // Don't show welcome if currently sending initial message
                    ? _buildWelcomePrompt()
                    : _buildMessagesList(messages, isSendingMessage),
              ),
            ),
            if (isSendingMessage) // This is the "Assistant is thinking..." indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant, // Use theme color
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
            if (chatProvider.sendMessageError != null && isActiveConversation)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text(
                    chatProvider.sendMessageError!,
                    style: TextStyle(color: theme.colorScheme.error)
                ),
              ),
            MessageInput(
              controller: _messageController,
              onSend: _sendMessage, // Uses the local _sendMessage for user-typed messages
              isLoading: isSendingMessage || _isGenerating,
              hintText: 'Ask about recipes, cooking tips, or meal ideas...',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePrompt() {
    return SingleChildScrollView( // Ensures content is scrollable if it overflows
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40), // Pushes content down a bit
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.restaurant, // Consider a more specific chat/AI icon if available
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
              color: Colors.grey[700], // Or use theme.colorScheme.onSurface.withOpacity(0.7)
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
    final prompts = [
      {'text': 'What can I make with chicken and broccoli?', 'icon': Icons.shopping_basket_outlined},
      {'text': 'I need a quick dinner idea for tonight', 'icon': Icons.timer_outlined},
      {'text': 'How do I make pasta from scratch?', 'icon': Icons.menu_book_outlined}, // Changed icon
      {'text': 'Give me a healthy breakfast recipe', 'icon': Icons.breakfast_dining_outlined}, // Changed icon
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
      elevation: 0, // Minimal elevation for a cleaner look
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)), // Theme-aware border
      ),
      child: InkWell(
        onTap: () => _sendMessage(text), // This will send the prompt text as a user message
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), // Theme color for icon
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface), // Theme color for text
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
      itemCount: messages.length, // Only active messages
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
              padding: const EdgeInsets.only(bottom: 8.0), // Spacing between bubbles
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
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else if (now.year == timestamp.year) {
      // If same year, just show Month Day (e.g. April 15)
      dateText = DateFormat('MMM d').format(timestamp);
    }
    else {
      // If different year, show Month Day, Year (e.g. April 15, 2023)
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

// Assuming ConversationsDrawer is defined elsewhere or in this file if it's small
// For this example, I'll include a placeholder for ConversationsDrawer if it's not already.
// If ConversationsDrawer is large, it should be in its own file.
// For brevity, I'm assuming ConversationsDrawer is correctly implemented.
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
              crossAxisAlignment: CrossAxisAlignment.stretch, // Make content stretch
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
                const Spacer(), // Pushes button to bottom of header space
                ElevatedButton.icon(
                  onPressed: () async {
                    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                    Navigator.pop(context); // Close drawer first

                    final newConversationId = await chatProvider.createNewConversation();
                    if (newConversationId != null) {
                      if (context.mounted) { // Check mount status before navigating
                        Navigator.of(context).pushReplacementNamed(
                            '/chat', // Use root /chat for new, not /chat/history
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
                  icon: const Icon(Icons.add_comment_outlined), // More specific icon
                  label: const Text('Start New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.onPrimary, // Contrasting bg
                    foregroundColor: theme.primaryColor,        // Contrasting text/icon
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    // minimumSize: const Size(200, 44), // Ensure it's wide enough
                  ),
                ),
                const SizedBox(height: 8), // Some padding at the bottom
              ],
            ),
          ),
          Expanded(
            child: chatProvider.isLoadingConversations
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                ? _buildEmptyConversationsState(theme, context)
                : _buildConversationsList(context, conversations, chatProvider),
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
                color: Colors.grey[800], // Use theme color
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new chat to begin your culinary journey!', // More engaging text
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600], // Use theme color
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
          key: Key(conversation.id), // Unique key for each item
          background: Container(
            color: Colors.redAccent, // Slightly less harsh red
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete_sweep_outlined, color: Colors.white), // Different icon
          ),
          direction: DismissDirection.endToStart, // Only allow swipe from right to left
          confirmDismiss: (direction) async {
            return await showDialog<bool>( // Ensure type safety
              context: context,
              builder: (BuildContext dialogContext) { // Use different context name
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
            ) ?? false; // Handle null case from showDialog
          },
          onDismissed: (direction) async {
            await chatProvider.deleteConversation(conversation.id);
            if (context.mounted && isSelected) {
              final newConversationId = await chatProvider.createNewConversation();
              if (newConversationId != null && context.mounted) {
                Navigator.of(context).pushReplacementNamed('/chat', arguments: newConversationId);
              }
            }
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
              child: Icon(
                isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline, // Different icon for selected
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
            ),
            title: Text(
              conversation.title ?? 'Chat', // Default title
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: Text(
              timeText, // Display formatted time
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            selected: isSelected,
            selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              if (!isSelected) {
                // When selecting existing conversation, it should be /chat and not /chat/history
                // if /chat/history is a special read-only view.
                // Assuming /chat can handle existing IDs.
                Provider.of<ChatProvider>(context, listen: false).selectConversation(conversation.id);
                // If your /chat route doesn't automatically update based on provider's activeId change,
                // you might need to push the route.
                // However, if ChatScreen rebuilds based on provider state, just selecting is enough.
                // Let's assume ChatScreen is already designed to react to `selectConversation`.
                // If direct navigation is needed for an existing chat:
                // Navigator.of(context).pushReplacementNamed('/chat', arguments: conversation.id);
              }
            },
            // Removed trailing PopupMenuButton for simplicity in this example,
            // can be added back if individual item actions are complex.
            // Consider long-press for actions or a more subtle options icon if needed.
          ),
        );
      },
    );
  }
}