// lib/screens/recipes/recipe_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode print

import '../../providers/recipe_provider.dart';
import '../../providers/chat_provider.dart'; // Added for chat functionality
import '../../providers/auth_provider.dart'; // Added for authentication
import '../../models/recipe.dart'; // Ensure updated model is imported
// Ensure updated NutritionInfo model is imported if NutritionCard uses it explicitly
import '../../models/chat_message.dart'; // Added for chat messages
import '../../widgets/recipes/ingredient_list.dart';
import '../../widgets/recipes/step_card.dart';
import '../../widgets/recipes/nutrition_card.dart'; // Import for the styled NutritionCard
import '../../widgets/recipes/recipe_generation_progress.dart'; // New widget for progressive display
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';
import '../../widgets/chat/message_input.dart'; // Added for chat input
import '../../widgets/chat/chat_bubble.dart'; // Added for chat bubbles

class RecipeDetailScreen extends StatefulWidget {
  // Accept optional initialRecipe (less critical now, but useful fallback)
  final Recipe? initialRecipe;

  // --- ADDED: Optional originating conversation ID ---
  // This is passed via arguments, not constructor for this implementation
  // final String? originatingConversationId;

  const RecipeDetailScreen({
    Key? key,
    this.initialRecipe,
    // this.originatingConversationId, // Not using constructor arg here
  }) : super(key: key);

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  // State variables for chat functionality
  // bool _showChat = false; // Not used for bottom sheet anymore // REMOVED
  final TextEditingController _messageController = TextEditingController(); // Kept for potential future use if chat expands here
  final ScrollController _scrollController = ScrollController(); // Kept for potential future use

  // --- MODIFIED: Changed conversationId name and added boolean flag ---
  String? _originatingConversationId; // Store conversation ID IF passed via arguments
  bool _creatingConversation = false; // Track NEW chat creation status

  // State for action buttons (like delete, favorite)
  bool _isPerformingAction = false;

  // Flag to track if initial recipe was processed
  bool _isInitialRecipeSet = false;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback for safe provider access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if mounted and if initial recipe hasn't been processed yet
      if (mounted && !_isInitialRecipeSet && widget.initialRecipe != null) {
        final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

        // Set the initial recipe in the provider ONLY if the provider doesn't
        // already have a recipe or if the initialRecipe is different.
        // This acts as a fallback if navigation happens without provider being set.
        if (recipeProvider.currentRecipe == null || recipeProvider.currentRecipe?.id != widget.initialRecipe!.id) {
          if (kDebugMode) print("RecipeDetailScreen: Setting initial recipe from arguments: ${widget.initialRecipe!.title}");
          // This method should update the provider's state and notify listeners
          recipeProvider.setCurrentRecipe(widget.initialRecipe!);
        } else {
          if (kDebugMode) print("RecipeDetailScreen: Provider already has this recipe or a different one, not overriding with initialRecipe argument.");
        }
        _isInitialRecipeSet = true; // Mark as processed

      } else if (!_isInitialRecipeSet) { // Handle case where no initialRecipe is passed
        if (kDebugMode) print("RecipeDetailScreen: No initial recipe provided, relying on provider state.");
        // Ensure provider has a recipe, otherwise show error/pop?
        final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
        if (recipeProvider.currentRecipe == null && !recipeProvider.isLoading) {
          print("RecipeDetailScreen Error: Reached detail screen but no recipe in provider and not loading.");
          // Optionally pop or show an error immediately
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Recipe details not available.'), backgroundColor: Colors.red));
              Navigator.of(context).pop();
            }
          });
        }
        _isInitialRecipeSet = true; // Mark as processed even if no initial recipe was passed.
      }
    });
  }

  // --- ADDED: Extract navigation arguments ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract originatingConversationId from arguments only once
    if (_originatingConversationId == null) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is Map && arguments.containsKey('originatingConversationId')) {
        setState(() { // Use setState here if needed elsewhere in build, otherwise direct assignment is fine
          _originatingConversationId = arguments['originatingConversationId'] as String?;
          if (kDebugMode) print("RecipeDetailScreen: Received originatingConversationId: $_originatingConversationId");
        });
      } else {
        if (kDebugMode) print("RecipeDetailScreen: No originatingConversationId found in arguments.");
      }
    }
  }
  // --- END ADDED ---


  // Helper widget for time info
  Widget _buildTimeInfo(BuildContext context, IconData icon, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: Colors.grey[700]),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
    ]);
  }

  // Helper function for Nutrition Dialog
  void _showStyledNutritionDialog(BuildContext context, Recipe recipe) {
    final nutritionInfo = recipe.nutrition;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Nutrition Info (Per Serving)'), // Add title
        content: SingleChildScrollView(child: NutritionCard(nutrition: nutritionInfo)),
        contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        actions: <Widget>[
          TextButton(child: const Text('Close'), onPressed: () => Navigator.of(dialogContext).pop()),
        ],
      ),
    );
  }

  // Handle deleting a recipe
  Future<void> _deleteRecipe(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Delete Recipe?'),
            content: Text('Are you sure you want to delete "${recipe.title}"? This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete'))
            ]
        )
    ) ?? false;

    if (!confirmed || !mounted) return;

    setState(() => _isPerformingAction = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      if (!authProvider.isAuthenticated || recipe.id == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete recipe: Not logged in or recipe has no ID.'), backgroundColor: Colors.orange));
        return;
      }
      final success = await recipeProvider.deleteRecipe(recipe.id!, authProvider.token!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe deleted successfully'), backgroundColor: Colors.green));
        // Pop back to the previous screen (likely recipe list or home)
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete recipe: ${recipeProvider.error ?? "Unknown error"}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting recipe: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  // Handle toggling favorite status
  Future<void> _toggleFavorite(Recipe recipe) async {
    if (recipe.id == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot favorite recipe: Recipe has no ID.'), backgroundColor: Colors.orange));
      return;
    }
    if (_isPerformingAction) return; // Prevent double taps

    setState(() => _isPerformingAction = true);
    final bool wasFavorite = recipe.isFavorite; // Check state before action

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to manage favorites.'), backgroundColor: Colors.orange));
        return;
      }
      final success = await recipeProvider.toggleFavorite(recipe.id!, authProvider.token!);

      if (success && mounted) {
        // The provider state (_currentRecipe.isFavorite) will be updated by toggleFavorite,
        // so the button icon will rebuild correctly. Show confirmation.
        final message = wasFavorite ? 'Removed from favorites' : 'Added to favorites';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update favorites: ${recipeProvider.error ?? "Unknown error"}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating favorites: $e'), backgroundColor: Colors.red));
    } finally {
      // Check mounted again before setting state in finally block
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  // Handle sharing a recipe
  Future<void> _shareRecipe(Recipe recipe) async {
    // Prevent action if already performing one
    if (_isPerformingAction) return;
    setState(() => _isPerformingAction = true); // Indicate action started

    try {
      // Use provider's share method which uses the current recipe state
      await Provider.of<RecipeProvider>(context, listen: false).shareRecipe();
      // Optional: Show confirmation
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe ready to share!'), backgroundColor: Colors.blue));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing recipe: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isPerformingAction = false); // Indicate action finished
    }
  }

  // --- MODIFIED: Navigate back to origin chat or create new chat ---
  Future<void> _handleAskAboutRecipe(Recipe recipe) async {
    // Check if we have an originating conversation ID
    if (_originatingConversationId != null && _originatingConversationId!.isNotEmpty) {
      // --- Navigate back to the existing chat ---
      if (kDebugMode) print("RecipeDetailScreen: Navigating back to originating chat: $_originatingConversationId");
      // Simply pop the current screen, assuming ChatScreen is the previous one
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // --- Original behavior: Start a NEW chat conversation ---
      if (kDebugMode) print("RecipeDetailScreen: No originating chat ID found, starting a new chat.");
      await _startNewChatAboutRecipe(recipe);
    }
  }


  // --- RENAMED & KEPT: Function to create a *new* chat ---
  Future<void> _startNewChatAboutRecipe(Recipe recipe) async {
    if (_creatingConversation || _isPerformingAction) return; // Prevent double taps

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to start a chat.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() {
      _creatingConversation = true;
      _isPerformingAction = true; // Also block other actions
    });
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting chat...'), duration: Duration(seconds: 5))
    );

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final newConversationId = await chatProvider.createNewConversation(); // Creates and selects

      if (newConversationId != null) {
        // _conversationId = newConversationId; // No longer need to store locally in this screen state

        // Send initial message about the recipe
        await chatProvider.sendMessage("I'd like to discuss this recipe: ${recipe.title}");

        snackBar.close(); // Close loading indicator

        if (mounted) {
          // Navigate to the newly created and selected chat screen
          // Replace current screen if desired, or push
          Navigator.of(context).pushReplacementNamed('/chat', arguments: newConversationId);
          // Alternative: Navigator.of(context).pushNamed('/chat', arguments: newConversationId);
        }
      } else {
        snackBar.close();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create chat conversation'), backgroundColor: Colors.red));
      }
    } catch (e) {
      snackBar.close();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting chat: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _creatingConversation = false;
          _isPerformingAction = false;
        });
      }
    }
  }
  // --- END CHAT FUNCTION ---


  @override
  Widget build(BuildContext context) {
    // Use Consumer for RecipeProvider to react to its changes (e.g., favorite status)
    return Consumer<RecipeProvider>(
      builder: (context, recipeProvider, child) {

        final authProvider = Provider.of<AuthProvider>(context, listen: false); // Read once

        // --- Determine Recipe to Display ---
        // This screen should ONLY be reached if recipeProvider.currentRecipe is set.
        // The initState logic tries to ensure this or pops the screen.
        final Recipe? recipeToDisplay = recipeProvider.currentRecipe;
        final partialRecipe = recipeProvider.partialRecipe; // Still needed for generation progress view

        final isLoading = recipeProvider.isLoading;
        final error = recipeProvider.error;
        final progress = recipeProvider.generationProgress;
        final isCancelling = recipeProvider.isCancelling;
        final wasCancelled = recipeProvider.wasCancelled; // Get cancellation status
        final bool isAuthenticated = authProvider.isAuthenticated;


        // --- Handle Generation State (if user lands here while generating) ---
        if (isLoading && recipeToDisplay == null && !wasCancelled) {
          // Show generation progress UI instead of recipe details
          if (partialRecipe != null) { // Show progress with partial recipe
            return Scaffold(
              appBar: AppBar(title: Text(partialRecipe.title.isNotEmpty ? partialRecipe.title : 'Generating Recipe...'), actions: [ if (isLoading && !isCancelling) IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: ()=> recipeProvider.cancelRecipeGeneration(), tooltip: "Cancel Generation") ]),
              body: RecipeGenerationProgress(
                partialRecipe: partialRecipe, progress: progress,
                onCancel: () => recipeProvider.cancelRecipeGeneration(), isCancelling: isCancelling,
              ),
            );
          } else { // Show generic loading/polling indicator
            return Scaffold(
              appBar: AppBar(title: const Text('Loading Recipe...'), actions: [ if (isLoading && !isCancelling) IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: ()=> recipeProvider.cancelRecipeGeneration(), tooltip: "Cancel Generation") ]),
              body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
                if (recipeProvider.isQueueActive) Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(children: [
                      LinearProgressIndicator(value: progress > 0 ? progress : null, backgroundColor: Colors.grey[300], valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                      const SizedBox(height: 16),
                      if (progress > 0) Text('${(progress * 100).toInt()}% complete', style: TextStyle(color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 24),
                    ])
                ) else const Text("Generating your recipe..."),
              ]),
            );
          }
        }


        // --- Handle Cancellation State ---
        if (wasCancelled) {
          return Scaffold(
            appBar: AppBar(title: const Text('Generation Cancelled'), leading: IconButton(icon: const Icon(Icons.close), onPressed: ()=> Navigator.pop(context))),
            body: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.cancel_outlined, size: 60, color: Colors.orange), const SizedBox(height: 16),
              Text('Recipe Generation Cancelled', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center,),
              if (recipeProvider.error != null && recipeProvider.error != 'Recipe generation cancelled') Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(recipeProvider.error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center,)),
              const SizedBox(height: 20), ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go Back'))
            ]))),
          );
        }


        // --- Handle Error State ---
        // If error is present AND we still don't have a recipe to display
        if (error != null && recipeToDisplay == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recipe Error'), leading: IconButton(icon: const Icon(Icons.close), onPressed: ()=> Navigator.pop(context))),
            body: ErrorDisplay(message: error), // Use your standard error widget
          );
        }

        // --- Handle Recipe Not Found State ---
        // If not loading, no error, not cancelled, but recipe is still null
        if (recipeToDisplay == null && !isLoading && error == null && !wasCancelled) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recipe Not Found'), leading: IconButton(icon: const Icon(Icons.close), onPressed: ()=> Navigator.pop(context))),
            body: const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Could not load the recipe details. Please try again later.', textAlign: TextAlign.center,),
            )),
          );
        }

        // --- Recipe Loaded UI ---
        // At this point, recipeToDisplay MUST be non-null
        final recipe = recipeToDisplay!;

        // Determine if any time info is available to adjust padding
        bool hasTimeInfo = (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0) ||
            (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0) ||
            (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0);

        // --- ADDED: Determine button text based on context ---
        final askButtonLabel = (_originatingConversationId != null && _originatingConversationId!.isNotEmpty)
            ? 'Return to Chat'
            : 'Ask about this recipe';
        // --- END ADDED ---


        return Scaffold(
          appBar: AppBar(
            title: Text(recipe.title, overflow: TextOverflow.ellipsis), // Use loaded recipe
            actions: [ // Use loaded recipe for actions
              // Favorite Button
              if (isAuthenticated && recipe.id != null)
                IconButton(
                    icon: Icon(recipe.isFavorite ? Icons.favorite : Icons.favorite_border, color: recipe.isFavorite ? Colors.redAccent : null),
                    tooltip: recipe.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    onPressed: _isPerformingAction ? null : () => _toggleFavorite(recipe) // Disable while action is running
                ),
              // Share Button
              IconButton(
                  icon: const Icon(Icons.share_outlined), // Use outlined icon
                  tooltip: 'Share recipe',
                  onPressed: _isPerformingAction ? null : () => _shareRecipe(recipe)
              ),
              // Delete Button (only if authenticated and recipe has an ID)
              if (isAuthenticated && recipe.id != null)
                IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete recipe',
                    onPressed: _isPerformingAction ? null : () => _deleteRecipe(recipe)
                ),
              // Nutrition Button
              IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Nutrition Info',
                  onPressed: () => _showStyledNutritionDialog(context, recipe)
              ),
            ],
          ),
          // --- Updated Body Structure ---
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optional: Display Thumbnail if available
                if (recipe.thumbnailUrl != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      recipe.thumbnailUrl!,
                      fit: BoxFit.cover,
                      // Add loading/error builders for network image
                      loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stack) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                    ),
                  )
                else // Show placeholder if no thumbnail
                  Container(
                    height: 150,
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Center(child: Icon(Icons.restaurant_menu, size: 60, color: Theme.of(context).primaryColor.withOpacity(0.4))),
                  ),


                // Recipe Title and Meta Info
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(recipe.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), // Larger title
                          const SizedBox(height: 12),
                          // Meta info row (Servings, Steps)
                          Row(
                              children: [
                                Icon(Icons.people_outline, size: 18, color: Colors.grey[700]), const SizedBox(width: 4),
                                Text('Serves ${recipe.servings}', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(width: 16),
                                Icon(Icons.list_alt_outlined, size: 18, color: Colors.grey[700]), const SizedBox(width: 4),
                                Text('${recipe.steps.length} step${recipe.steps.length != 1 ? 's' : ''}', style: Theme.of(context).textTheme.titleSmall) // Pluralize steps
                              ]
                          ),
                          // Time info row (only if available)
                          if (hasTimeInfo) ...[
                            const SizedBox(height: 8),
                            Wrap(
                                spacing: 16, // Increased spacing
                                runSpacing: 4,
                                children: [
                                  if (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0) _buildTimeInfo(context, Icons.timer_outlined, '${recipe.prepTimeMinutes} min prep'),
                                  if (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0) _buildTimeInfo(context, Icons.whatshot_outlined, '${recipe.cookTimeMinutes} min cook'),
                                  if (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0) _buildTimeInfo(context, Icons.schedule_outlined, '${recipe.totalTimeMinutes} min total')
                                ]
                            )
                          ]
                        ]
                    )
                ),

                const Divider(height: 1, indent: 16, endIndent: 16),

                // Ingredients Section
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ingredients', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          IngredientList(ingredients: recipe.ingredients) // Use dedicated widget
                        ]
                    )
                ),

                const Divider(height: 1, indent: 16, endIndent: 16),

                // Instructions Section
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Instructions', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          if (recipe.steps.isEmpty)
                            Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 32.0), child: Text('No steps available...', style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic))))
                          else
                            ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: recipe.steps.length,
                                itemBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: StepCard(step: recipe.steps[index], stepNumber: index + 1) // Use dedicated widget
                                )
                            )
                        ]
                    )
                ),

                // Divider before chat button
                const Divider(height: 1, indent: 16, endIndent: 16),

                // --- MODIFIED: Chat Button uses new handler and dynamic label ---
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), // Add more bottom padding
                    child: Center(
                        child: ElevatedButton.icon(
                          // --- Use dynamic icon based on context ---
                            icon: Icon(
                                (_originatingConversationId != null && _originatingConversationId!.isNotEmpty)
                                    ? Icons.arrow_back_ios_new // Icon for returning
                                    : Icons.chat_bubble_outline // Icon for asking/new chat
                            ),
                            label: Text(askButtonLabel), // --- Use dynamic label ---
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              textStyle: const TextStyle(fontSize: 16),
                              // Disable button while creating chat or performing other actions
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            // --- Use the new handler function ---
                            onPressed: (_creatingConversation || _isPerformingAction) ? null : () => _handleAskAboutRecipe(recipe) // Disable if busy
                        )
                    )
                ),
                // --- END MODIFIED ---
              ],
            ),
          ),
        );
      }, // End Consumer builder
    ); // End Consumer
  } // End build method
} // End _RecipeDetailScreenState class


// Helper widget for action buttons (remains the same)
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color; // Optional color override

  const ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the color to use for icon and text
    final effectiveColor = color ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: effectiveColor, size: 20), // Slightly smaller icon
      label: Text(label, style: TextStyle(color: effectiveColor)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        // Add visual density for tighter spacing if needed
        // visualDensity: VisualDensity.compact,
      ),
    );
  }
}