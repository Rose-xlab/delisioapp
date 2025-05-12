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
import '../../models/recipe.dart'; // Import Recipe model
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
  bool _isGenerating = false; // Tracks if recipe generation is actively running via this screen
  // Removed: _generatedRecipeId - No longer needed here

  @override
  void initState() {
    super.initState();
    print("ChatScreen: Initializing for conversation ID: ${widget.conversationId}");
    // Use post frame callback to safely access providers
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

  // Improved scroll logic
  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (jump) {
          _scrollController.jumpTo(maxScroll);
        } else {
          _scrollController.animateTo(
            maxScroll, // Scroll slightly past the end if needed
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    final text = message.trim();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // Disable sending if already sending OR if currently generating a recipe
    if (text.isEmpty || chatProvider.isSendingMessage || _isGenerating) return;
    _messageController.clear();
    FocusScope.of(context).unfocus(); // Hide keyboard

    await chatProvider.sendMessage(text);
    _scrollToBottom(); // Scroll after sending message
  }

  // Recipe Name Extraction Helper (keep as is)
  String _extractRecipeName(String text) {
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
        if (name.length >= 3 && name.length <= 100) {
          return name;
        }
      }
    }
    int colonIndex = text.indexOf(':');
    if (colonIndex > 3 && colonIndex < 100) {
      return text.substring(0, colonIndex).trim();
    }
    int periodIndex = text.indexOf('.');
    if (periodIndex > 3 && periodIndex < 100) {
      return text.substring(0, periodIndex).trim();
    }
    List<String> words = text.split(' ');
    if (words.length > 3) {
      int wordCount = words.length <= 12 ? words.length : 12; // Max 12 words
      return words.take(wordCount).join(' ').trim();
    }
    return text.substring(0, text.length > 100 ? 100 : text.length).trim();
  }

  // Handle suggestion selection from ChatBubble
  void _onSuggestionSelected(String suggestion, bool generateRecipe) {
    print("Suggestion selected in ChatScreen: $suggestion, generate: $generateRecipe");

    // Special handling for "Something else?" option
    if (suggestion.toLowerCase() == "something else?") {
      _sendMessage("Something else?"); // Send this as a normal message
      return;
    }

    if (generateRecipe) {
      // Process the suggestion for recipe generation
      String recipeQuery = suggestion;
      // --- Keep query processing/truncation logic ---
      if (recipeQuery.length > 190) {
        print("Original query (${recipeQuery.length} chars): '$recipeQuery'");
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
          // Ensure cutPoint is within bounds
          if (cutPoint >= recipeQuery.length) cutPoint = recipeQuery.length -1;
          if (cutPoint < 0) cutPoint = 0; // Safety check

          recipeQuery = recipeQuery.substring(0, cutPoint).trim();
          print("Truncated to ${recipeQuery.length} chars: '$recipeQuery'");
        }
      }
      // --- End query processing ---

      // Call the NEW asynchronous generation function
      _generateRecipeFromChat(recipeQuery);
    } else {
      // Send a message to discuss the suggestion
      _sendMessage("Tell me more about $suggestion - what it is, how it tastes, and what ingredients I need for it.");
    }
  }

  // --- MODIFIED: Handle "View Recipe" button press - Pass conversationId ---
  Future<void> _onViewRecipePressed(String recipeId) async {
    print("ChatScreen: View Recipe button pressed for ID: $recipeId from conversation: ${widget.conversationId}");
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (!authProvider.isAuthenticated || token == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to view recipe details'), backgroundColor: Colors.orange));
      return;
    }

    // Show a loading indicator while fetching
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading recipe details...'), duration: Duration(seconds: 5)) // Show longer
    );

    try {
      // Use the provider method to fetch and set the recipe in RecipeProvider
      final Recipe? recipe = await recipeProvider.fetchAndSetCurrentRecipe(recipeId, token);

      snackBar.close(); // Close loading indicator

      if (recipe != null && mounted) {
        // --- MODIFICATION START ---
        // Navigate to the recipe detail screen, passing the current conversation ID as an argument
        Navigator.of(context).pushNamed(
          '/recipe',
          arguments: {
            'originatingConversationId': widget.conversationId,
            // You could potentially pass the initialRecipe here too if needed,
            // but fetchAndSetCurrentRecipe already puts it in the provider.
            // 'initialRecipe': recipe, // Optional: Pass recipe if needed as fallback
          },
        );
        // --- MODIFICATION END ---
      } else if (mounted) {
        // Show error if fetching failed
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(recipeProvider.error ?? 'Could not load recipe details'), backgroundColor: Colors.red));
      }
    } catch (e) {
      snackBar.close(); // Close indicator on error too
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading recipe: $e'), backgroundColor: Colors.red));
      }
    }
  }
  // --- END MODIFIED ---


  // --- Generate Recipe Flow (Unchanged for this task) ---
  Future<void> _generateRecipeFromChat(String? suggestedQuery) async {
    if (_isGenerating) {
      print("Generation already in progress, ignoring request.");
      return; // Prevent multiple concurrent generations
    }

    final String recipeQuery = suggestedQuery ?? "";
    if (recipeQuery.isEmpty) {
      print("Error: Cannot generate recipe. No valid query context found.");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not determine which recipe to generate.'), backgroundColor: Colors.orange));
      return;
    }

    // Get providers and current state
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conversationId = chatProvider.activeConversationId; // Get current conversation ID

    if (conversationId == null) {
      print("Error: Cannot generate recipe. No active conversation ID.");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot generate recipe, no active chat selected.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isGenerating = true); // Set generating flag for UI feedback (e.g., disable input)
    String? placeholderId; // To store the ID of the temporary message

    try {
      print("Attempting to generate recipe for: $recipeQuery in conversation $conversationId.");
      FocusScope.of(context).unfocus(); // Hide keyboard

      // 1. Add Placeholder Message to the *current* conversation
      placeholderId = await chatProvider.addRecipePlaceholderMessage(conversationId, recipeQuery);
      _scrollToBottom(); // Scroll after adding placeholder

      // 2. Start Recipe Generation (Await Completion)
      //    generateRecipe now returns Recipe? or null/throws error
      final Recipe? generatedRecipe = await recipeProvider.generateRecipe(
        recipeQuery,
        save: authProvider.isAuthenticated, // Save if user is logged in
        token: authProvider.token,
      );

      // 3. Handle Result (check if still mounted and placeholderId is valid)
      if (mounted && placeholderId != null) {
        if (generatedRecipe != null && generatedRecipe.id != null) {
          // Success: Update placeholder to recipe result message
          print("Recipe generation successful in ChatScreen. Recipe ID: ${generatedRecipe.id}, Title: ${generatedRecipe.title}");
          await chatProvider.updatePlaceholderToRecipeMessage(conversationId, placeholderId, generatedRecipe);
        } else {
          // Failure or Cancellation: Remove placeholder, show error from RecipeProvider
          final errorMsg = recipeProvider.error ?? (recipeProvider.wasCancelled ? "Recipe generation cancelled." : "Failed to generate recipe (unknown reason).");
          print("Recipe generation failed or cancelled in ChatScreen: $errorMsg");
          await chatProvider.removePlaceholderMessage(conversationId, placeholderId);
          // Show error to user
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: recipeProvider.wasCancelled ? Colors.orange : Colors.red));
        }
      } else if (mounted && placeholderId == null) {
        print("Error: Placeholder ID was null after trying to add it.");
        // Handle case where placeholder adding failed silently? Unlikely but possible.
      }

    } catch (e) {
      print("Error caught directly in _generateRecipeFromChat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: ${e.toString()}'), backgroundColor: Colors.red));
        // Attempt to remove placeholder if an unexpected error occurred during the process
        if (placeholderId != null && conversationId != null) {
          try {
            await chatProvider.removePlaceholderMessage(conversationId, placeholderId);
          } catch (removeError) {
            print("Error trying to remove placeholder after main error: $removeError");
          }
        }
      }
    } finally {
      // Ensure the generating flag is turned off regardless of outcome
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
  // --- END Generate Recipe Flow ---


  void _showConversationsDrawer() {
    // Refresh the conversations list first
    Provider.of<ChatProvider>(context, listen: false).loadConversations();
    Scaffold.of(context).openDrawer();
  }

  void _startNewChat() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // Don't start new chat if already generating recipe in current chat
    if (_isGenerating) return;

    final newConversationId = await chatProvider.createNewConversation();

    if (newConversationId != null && mounted) {
      // Use pushReplacementNamed to replace the current chat screen with the new one
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
    // Use Consumer for ChatProvider to react to message list changes
    return Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final theme = Theme.of(context);

          final bool isActiveConversation = chatProvider.activeConversationId == widget.conversationId;
          final messages = isActiveConversation ? chatProvider.activeMessages : <ChatMessage>[];
          final isLoadingMessages = isActiveConversation ? chatProvider.isLoadingMessages : false;
          // Combine sending and generating state for input disabling
          final bool isBusy = chatProvider.isSendingMessage || _isGenerating;
          final error = isActiveConversation ? chatProvider.messagesError ?? chatProvider.sendMessageError : null;

          // Scroll to bottom whenever messages list changes and is active
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
                  title: 'New Chat' // Default title if not found yet
              ));

          final String appBarTitle = currentConversation.title ?? 'Chat';

          return Scaffold(
            appBar: AppBar(
              // Use Builder to get context for Scaffold.of(context).openDrawer()
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Show Conversations',
                ),
              ),
              title: Text(
                appBarTitle,
                style: const TextStyle(fontSize: 18), // Slightly smaller for longer titles
              ),
              actions: [
                // New chat button
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined),
                  tooltip: 'New Chat',
                  // Disable if busy
                  onPressed: isBusy ? null : _startNewChat,
                ),
                // More options (Keep existing - TODO: Implement actions)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      // TODO: Implement rename conversation
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rename not implemented yet')));
                    } else if (value == 'delete') {
                      // TODO: Implement delete conversation confirmation
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete not implemented yet')));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Rename chat'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete chat', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Drawer for conversations list
            drawer: ConversationsDrawer(
              currentConversationId: widget.conversationId,
            ),
            body: Column(
              children: [
                // Messages area
                Expanded(
                  child: Container(
                    // Use a slightly different background color for chat area
                    color: theme.colorScheme.surface.withOpacity(0.5), // Example adjustment
                    child: isLoadingMessages && messages.isEmpty
                        ? const LoadingIndicator(message: 'Loading messages...')
                        : error != null && messages.isEmpty
                        ? ErrorDisplay(message: "Error loading chat: $error")
                        : messages.isEmpty && !isBusy // Check combined busy state
                        ? _buildWelcomePrompt()
                        : _buildMessagesList(messages, isBusy), // Pass combined busy state
                  ),
                ),

                // Indicators (thinking indicator)
                if (chatProvider.isSendingMessage) // Only show for actual message sending
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

                // General Error message area (for send errors etc.)
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
                  isLoading: isBusy, // Use combined busy state
                  hintText: _isGenerating ? 'Generating recipe, please wait...' : 'Ask about recipes, cooking tips...',
                ),
              ],
            ),
          );
        } // End Consumer builder
    ); // End Consumer
  }

  Widget _buildWelcomePrompt() {
    // --- Keep existing Welcome Prompt ---
    return SingleChildScrollView( padding: const EdgeInsets.all(24.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [ const SizedBox(height: 40), Container( width: 80, height: 80, decoration: BoxDecoration( color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(20), ), child: Icon( Icons.restaurant, size: 40, color: Theme.of(context).colorScheme.primary, ), ), const SizedBox(height: 24), Text( 'Delisio Cooking Assistant', style: Theme.of(context).textTheme.headlineSmall?.copyWith( fontWeight: FontWeight.bold, ), textAlign: TextAlign.center, ), const SizedBox(height: 12), Text( 'How can I help with your cooking today?', style: Theme.of(context).textTheme.titleMedium?.copyWith( color: Colors.grey[700], ), textAlign: TextAlign.center, ), const SizedBox(height: 32), ..._buildExamplePrompts(), ], ), );
  }

  List<Widget> _buildExamplePrompts() {
    // --- Keep existing Example Prompts ---
    final prompts = [ {'text': 'What can I make with chicken and broccoli?', 'icon': Icons.shopping_basket}, {'text': 'I need a quick dinner idea', 'icon': Icons.timer}, {'text': 'How do I make pasta from scratch?', 'icon': Icons.restaurant_menu}, {'text': 'Give me a healthy breakfast recipe', 'icon': Icons.breakfast_dining}, ]; return prompts.map((prompt) { return Padding( padding: const EdgeInsets.only(bottom: 12.0), child: _buildPromptCard(prompt['text'] as String, prompt['icon'] as IconData), ); }).toList();
  }

  Widget _buildPromptCard(String text, IconData icon) {
    // --- Keep existing Prompt Card ---
    return Card( elevation: 0, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300), ), child: InkWell( onTap: () => _sendMessage(text), borderRadius: BorderRadius.circular(12), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0), child: Row( children: [ Icon(icon, size: 20, color: Colors.grey[600]), const SizedBox(width: 12), Expanded( child: Text( text, style: TextStyle(color: Colors.grey[800]), ), ), Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]), ], ), ), ), );
  }

  // --- Messages List Builder (Unchanged for this task) ---
  Widget _buildMessagesList(List<ChatMessage> messages, bool isSendingMessage) {
    // Group messages by date
    Map<DateTime, List<ChatMessage>> messagesByDate = {};
    for (var message in messages) {
      // Use UTC date for grouping to avoid issues with timezones/DST
      final date = DateTime.utc(message.timestamp.year, message.timestamp.month, message.timestamp.day);
      if (messagesByDate[date] == null) {
        messagesByDate[date] = [];
      }
      messagesByDate[date]!.add(message);
    }

    // Sort dates (most recent first? No, chronological)
    List<DateTime> sortedDates = messagesByDate.keys.toList()..sort();

    if (messages.isEmpty && isSendingMessage) {
      // If messages are empty but we are sending (or generating), show indicator maybe?
      // Handled by the main build method's loading states
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: sortedDates.length, // Number of date groups
      itemBuilder: (context, dateIndex) {
        final date = sortedDates[dateIndex];
        final dateMessages = messagesByDate[date]!;

        // Build a column for each date: Header + Messages
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date Header
            _buildDateHeader(date),
            // Messages for this date
            ListView.builder(
                shrinkWrap: true, // Important for nested ListView
                physics: const NeverScrollableScrollPhysics(), // Disable scrolling for inner list
                itemCount: dateMessages.length,
                itemBuilder: (ctx, msgIndex) {
                  final message = dateMessages[msgIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ChatBubble(
                      message: message,
                      onSuggestionSelected: _onSuggestionSelected,
                      // Pass the new handler here
                      onViewRecipePressed: _onViewRecipePressed,
                    ),
                  );
                }
            ),
          ],
        );
      },
    );
  }
  // --- END Messages List Builder ---

  Widget _buildDateHeader(DateTime timestamp) {
    // Use UTC date for comparison
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    // The timestamp passed should already be the UTC date used for grouping
    final messageDate = timestamp;

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      // Format as Month Day, Year (e.g. April 15, 2023) - Use local for display
      final localTimestamp = timestamp.toLocal(); // Convert back to local for display format
      // Use intl package for reliable formatting if added
      // dateText = DateFormat.yMMMd().format(localTimestamp);
      final month = [ 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December' ][localTimestamp.month - 1];
      dateText = '$month ${localTimestamp.day}, ${localTimestamp.year}';
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

// --- ConversationsDrawer (Keep existing - unmodified) ---
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
                        // Navigate or replace depending on desired behavior
                        Navigator.of(context).pushReplacementNamed( // Use replacement
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
        final difference = now.difference(conversation.updatedAt.toLocal()); // Use local time for difference calc
        String timeText;

        if (difference.inMinutes < 1) {
          timeText = 'Just now';
        } else if (difference.inHours < 1) {
          timeText = '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24 && conversation.updatedAt.toLocal().day == now.day) { // Check if same day
          timeText = DateFormat.jm().format(conversation.updatedAt.toLocal()); // Show time if today
        } else if (difference.inDays < 2 && conversation.updatedAt.toLocal().day == now.subtract(const Duration(days:1)).day) { // Check if yesterday
          timeText = 'Yesterday';
        } else if (difference.inDays < 7) {
          timeText = DateFormat('EEE').format(conversation.updatedAt.toLocal()); // Show Day name if within week
        } else {
          // Format as Month Day (e.g. Apr 15)
          final DateFormat formatter = DateFormat('MMM d');
          timeText = formatter.format(conversation.updatedAt.toLocal());
        }

        return Dismissible(
          key: Key(conversation.id),
          background: Container(
            color: Colors.redAccent, // Slightly different color
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(
              Icons.delete_sweep_outlined, // Different delete icon
              color: Colors.white,
            ),
          ),
          direction: DismissDirection.endToStart, // Only allow swipe left to delete
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Delete Conversation?"),
                  content: Text(
                      "Are you sure you want to permanently delete '${conversation.title ?? 'this chat'}'?" // Include title
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
            // If the deleted conversation was the active one, behavior depends:
            // Option 1: Navigate to the first remaining chat (or new if none)
            // Option 2: Navigate to a default screen (like home) - simpler
            if (context.mounted && isSelected) {
              // If deleted chat was active, maybe go home or select next?
              // Selecting next is complex, let's try creating a new one if list becomes empty
              final remainingConversations = chatProvider.conversations;
              if (remainingConversations.isEmpty) {
                final newId = await chatProvider.createNewConversation();
                if (newId != null && context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/chat', arguments: newId);
                }
              } else {
                // Select the first available one
                Navigator.of(context).pushReplacementNamed('/chat', arguments: remainingConversations.first.id);
              }
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${conversation.title ?? 'Chat'}" deleted')));
            }
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.8) // Slightly darker selected
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
              conversation.title ?? 'New Chat', // Default title
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              timeText, // Use formatted time
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
                Navigator.of(context).pushReplacementNamed( // Use replacement
                    '/chat',
                    arguments: conversation.id
                );
              }
            },
            // Remove trailing popup menu for simplicity, rely on swipe-to-delete
            // trailing: PopupMenuButton<String>( /* ... */ ),
          ),
        );
      },
    );
  }
}