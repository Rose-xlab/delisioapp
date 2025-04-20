// lib/screens/recipes/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode print

import '../../providers/recipe_provider.dart';
import '../../providers/chat_provider.dart'; // Added for chat functionality
import '../../providers/auth_provider.dart'; // Added for authentication
import '../../models/recipe.dart'; // Ensure updated model is imported
import '../../models/recipe_step.dart';
import '../../models/nutrition_info.dart'; // Ensure updated NutritionInfo model is imported
import '../../models/chat_message.dart'; // Added for chat messages
import '../../widgets/recipes/ingredient_list.dart';
import '../../widgets/recipes/step_card.dart';
import '../../widgets/recipes/nutrition_card.dart'; // Import for the styled NutritionCard
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';
import '../../widgets/chat/message_input.dart'; // Added for chat input
import '../../widgets/chat/chat_bubble.dart'; // Added for chat bubbles

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({Key? key}) : super(key: key);

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  // Added state variables for chat functionality
  bool _showChat = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;
  bool _creatingConversation = false;

  // Helper widget to build the Icon + Text display for time info - Unchanged
  Widget _buildTimeInfo(BuildContext context, IconData icon, String text) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
        ),
      ],
    );
  }

  // Helper function to show the styled Nutrition Dialog - Only title removed
  void _showStyledNutritionDialog(BuildContext context, Recipe recipe) {
    final nutritionInfo = recipe.nutrition;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // title: const Text("Nutrition Info"),  // <-- removed
          content: SingleChildScrollView(
            child: NutritionCard(nutrition: nutritionInfo),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // New function to create a chat conversation about the current recipe
  Future<void> _createChatConversation(Recipe recipe) async {
    if (_creatingConversation) return;
    setState(() {
      _creatingConversation = true;
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Create a new conversation
      final newConversationId = await chatProvider.createNewConversation();
      if (newConversationId != null) {
        setState(() {
          _conversationId = newConversationId;
          _showChat = true;
          _creatingConversation = false;
        });

        // Send initial message about the recipe to create context
        await chatProvider.sendMessage(
            "I'd like to learn more about this ${recipe.title} recipe. Can you help me with any questions I might have?"
        );

        // Scroll to the bottom of the chat
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        // Handle error creating conversation
        setState(() {
          _creatingConversation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not create chat conversation'), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      setState(() {
        _creatingConversation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  // New function to send a chat message
  Future<void> _sendMessage(String message) async {
    if (_conversationId == null) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.isSendingMessage) return;

    _messageController.clear();
    await chatProvider.sendMessage(message);

    // Scroll to the bottom of the chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Updated function to handle suggestion selection with the new signature
  void _onSuggestionSelected(String suggestion, bool generateRecipe) {
    print("Suggestion selected in Recipe Detail: $suggestion, generate: $generateRecipe");

    // Special handling for "Something else?" option
    if (suggestion.toLowerCase() == "something else?") {
      // Send this exact message to get more suggestions
      _sendMessage("Something else?");
      return;
    }

    if (generateRecipe) {
      // This is a request to generate after seeing the description
      _sendMessage("Generate a recipe for $suggestion");
    } else {
      // First click - request a description with ingredients, not full recipe
      _sendMessage("Tell me more about $suggestion and what ingredients I need for it");
    }
  }

  // New function to toggle chat visibility and show as a bottom sheet
  void _toggleChat(Recipe recipe) {
    if (_showChat) {
      // If chat is already showing, just hide it
      setState(() {
        _showChat = false;
      });
      return;
    }

    // Create conversation if needed
    if (_conversationId == null) {
      _createChatConversation(recipe);
    }

    // Show chat as a modal bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Full height possible
      backgroundColor: Colors.transparent, // Transparent background for custom shape
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setSheetState) {
              // Get the required data for chat
              final chatProvider = Provider.of<ChatProvider>(context);
              final bool isActiveConversation = chatProvider.activeConversationId == _conversationId;
              final messages = isActiveConversation ? chatProvider.activeMessages : <ChatMessage>[];
              final isLoadingMessages = isActiveConversation ? chatProvider.isLoadingMessages : false;
              final isSendingMessage = chatProvider.isSendingMessage;
              final error = isActiveConversation ? chatProvider.messagesError ?? chatProvider.sendMessageError : null;

              // Calculate height - give enough space for typing and messages
              // Use approximately 75% of screen height
              return FractionallySizedBox(
                heightFactor: 0.75, // Use 75% of screen height
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Chat header with recipe title
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chat about ${recipe.title}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Close chat',
                            ),
                          ],
                        ),
                      ),

                      // Messages area - Takes all available space
                      Expanded(
                        child: _creatingConversation || isLoadingMessages
                            ? const Center(child: CircularProgressIndicator())
                            : error != null && messages.isEmpty
                            ? Center(child: Text("Error: $error", style: TextStyle(color: Colors.red)))
                            : messages.isEmpty
                            ? const Center(child: Text('Starting conversation...'))
                            : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ChatBubble(
                                message: message,
                                onSuggestionSelected: _onSuggestionSelected,
                              ),
                            );
                          },
                        ),
                      ),

                      // Sending indicator
                      if (isSendingMessage)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.5),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Assistant is thinking...',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Message input - Add padding to avoid keyboard overlap
                      Padding(
                        padding: EdgeInsets.only(
                            left: 8, right: 8, top: 8,
                            // Add bottom padding to handle keyboard
                            bottom: MediaQuery.of(context).viewInsets.bottom + 8
                        ),
                        child: MessageInput(
                          controller: _messageController,
                          onSend: (message) {
                            _sendMessage(message);
                            // Update bottom sheet state after sending
                            setSheetState(() {});
                          },
                          isLoading: isSendingMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
        );
      },
    ).then((_) {
      // Update state after bottom sheet is closed
      setState(() {
        _showChat = false;
      });
    });

    // Update state
    setState(() {
      _showChat = true;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final recipe = recipeProvider.currentRecipe;
    final isLoading = recipeProvider.isLoading;
    final error = recipeProvider.error;

    // Debug logs - Unchanged
    if (kDebugMode && recipe != null) {
      print("Recipe Detail Debug Info:");
      print("- Recipe ID: ${recipe.id}");
      // ... other debug prints ...
    }

    // --- Handle Loading/Error/Null --- Unchanged
    if (isLoading && recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Recipe...')),
        body: const LoadingIndicator(message: 'Preparing your recipe...'),
      );
    }
    if (error != null && recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe Error')),
        body: ErrorDisplay(message: error),
      );
    }
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe Not Found')),
        body: const Center(child: Text('Could not load the recipe details.')),
      );
    }

    // --- Recipe Loaded UI ---
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        // Keep the AppBar action button for Nutrition Info
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Nutrition Info',
            onPressed: () {
              _showStyledNutritionDialog(context, recipe);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Recipe Header ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // --- Servings & Steps Row (original structure, now with flex) ---
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Serves ${recipe.servings}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.list_alt, size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${recipe.steps.length} steps',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- Time Info Row --- Unchanged
                  Wrap(
                    spacing: 12,
                    children: [
                      if (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0)
                        _buildTimeInfo(
                            context, Icons.timer_outlined, '${recipe.prepTimeMinutes} min prep'),
                      if (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0)
                        _buildTimeInfo(
                            context, Icons.whatshot_outlined, '${recipe.cookTimeMinutes} min cook'),
                      if (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0)
                        _buildTimeInfo(
                            context, Icons.schedule, '${recipe.totalTimeMinutes} min total'),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),

            // --- Ingredients --- Unchanged
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ingredients', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  IngredientList(ingredients: recipe.ingredients),
                ],
              ),
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),

            // --- Steps --- Unchanged
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (recipe.steps.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Text(
                          'No steps available for this recipe.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recipe.steps.length,
                      itemBuilder: (context, index) {
                        final step = recipe.steps[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: StepCard(step: step, stepNumber: index + 1),
                        );
                      },
                    ),
                ],
              ),
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),

            // --- Chat Button ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Ask about this recipe'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () => _toggleChat(recipe),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}