// lib/screens/recipes/recipe_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode print
import 'package:flutter/rendering.dart'; // For ScrollDirection

import '../../providers/recipe_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/recipe.dart';
import '../../models/chat_message.dart';
import '../../widgets/recipes/ingredient_list.dart';
import '../../widgets/recipes/step_card.dart';
import '../../widgets/recipes/nutrition_card.dart';
import '../../widgets/recipes/recipe_generation_progress.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';
// import '../../widgets/chat/message_input.dart'; // Not directly used by RecipeDetailScreen itself
// import '../../widgets/chat/chat_bubble.dart'; // Not directly used by RecipeDetailScreen itself
import '../../widgets/recipes/floating_cook_mode_button.dart'; // Assuming this file exists and defines FloatingCookModeButton
import '../../widgets/recipes/cook_mode_view.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe? initialRecipe;

  const RecipeDetailScreen({
    Key? key,
    this.initialRecipe,
  }) : super(key: key);

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _showFloatingButton = true;
  FloatingActionButtonLocation _currentFabLocation = FloatingActionButtonLocation.centerDocked;
  bool _isCookModeButtonCustomPositioned = false;

  String? _originatingConversationId;
  bool _creatingConversation = false;
  bool _isPerformingAction = false;
  bool _isInitialRecipeSet = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isInitialRecipeSet && widget.initialRecipe != null) {
        final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
        if (recipeProvider.currentRecipe == null || recipeProvider.currentRecipe?.id != widget.initialRecipe!.id) {
          if (kDebugMode) print("RecipeDetailScreen: Setting initial recipe from arguments: ${widget.initialRecipe!.title}");
          recipeProvider.setCurrentRecipe(widget.initialRecipe!);
        } else {
          if (kDebugMode) print("RecipeDetailScreen: Provider already has this recipe or a different one, not overriding with initialRecipe argument.");
        }
        if (mounted) {
          setState(() {
            _isInitialRecipeSet = true;
          });
        }
      } else if (mounted && !_isInitialRecipeSet) {
        if (kDebugMode) print("RecipeDetailScreen: No initial recipe provided, relying on provider state.");
        final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
        if (recipeProvider.currentRecipe == null && !recipeProvider.isLoading) {
          print("RecipeDetailScreen Error: Reached detail screen but no recipe in provider and not loading.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Recipe details not available.'), backgroundColor: Colors.red));
              Navigator.of(context).pop();
            }
          });
        }
        if (mounted) {
          setState(() {
            _isInitialRecipeSet = true;
          });
        }
      }
    });
  }

  void _handleScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final scrollPosition = _scrollController.position;
    bool newShowButtonState;
    bool newIsCookModeButtonCustomPositioned = false;

    double atBottomThreshold = 10.0;
    bool isAtVeryBottom = false;

    if (scrollPosition.maxScrollExtent > 0) {
      isAtVeryBottom = (scrollPosition.maxScrollExtent - scrollPosition.pixels) < atBottomThreshold;
    } else {
      isAtVeryBottom = false;
    }

    if (isAtVeryBottom) {
      newIsCookModeButtonCustomPositioned = true;
      newShowButtonState = true;
    } else {
      newIsCookModeButtonCustomPositioned = false;
      newShowButtonState = _showFloatingButton;

      if (scrollPosition.userScrollDirection == ScrollDirection.forward) {
        if (scrollPosition.pixels > 10) {
          newShowButtonState = false;
        }
      } else if (scrollPosition.userScrollDirection == ScrollDirection.reverse) {
        newShowButtonState = true;
      }
    }

    if (scrollPosition.pixels <= 0 && !isAtVeryBottom) {
      newShowButtonState = true;
      newIsCookModeButtonCustomPositioned = false;
    }

    if (newShowButtonState != _showFloatingButton ||
        newIsCookModeButtonCustomPositioned != _isCookModeButtonCustomPositioned) {
      setState(() {
        _showFloatingButton = newShowButtonState;
        _isCookModeButtonCustomPositioned = newIsCookModeButtonCustomPositioned;
        _currentFabLocation = newIsCookModeButtonCustomPositioned
            ? FloatingActionButtonLocation.centerFloat
            : FloatingActionButtonLocation.centerDocked;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_originatingConversationId == null) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is Map && arguments.containsKey('originatingConversationId')) {
        if (mounted) {
          setState(() {
            _originatingConversationId = arguments['originatingConversationId'] as String?;
            if (kDebugMode) print("RecipeDetailScreen: Received originatingConversationId: $_originatingConversationId");
          });
        }
      } else {
        if (kDebugMode) print("RecipeDetailScreen: No originatingConversationId found in arguments.");
      }
    }
  }

  // MODIFIED: Helper function to format duration
  String _formatRecipeTime(int? totalMinutes, String timeTypeLabel) {
    if (totalMinutes == null || totalMinutes <= 0) {
      return ""; // Return empty if no time or invalid time
    }

    final duration = Duration(minutes: totalMinutes);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);

    StringBuffer buffer = StringBuffer();

    if (hours > 0) {
      buffer.write('$hours hr');
      // 'hr' is commonly used for singular and plural, like 'min'.
      // If specific pluralization is desired:
      // if (hours > 1) buffer.write('s');
    }

    if (minutes > 0) {
      if (buffer.isNotEmpty) {
        buffer.write(' '); // Add a space if hours were added
      }
      buffer.write('$minutes min');
    }

    // This case should ideally not be hit if totalMinutes >= 1,
    // as either hours or minutes (or both) will be > 0.
    if (buffer.isEmpty) {
      // Fallback for the unlikely scenario where totalMinutes > 0 but buffer is empty
      // This might happen if logic changes or for very small sub-minute values if input wasn't int.
      // For int minutes, if totalMinutes is 1, '1 min' will be in buffer.
      return '$totalMinutes min $timeTypeLabel';
    }

    buffer.write(' $timeTypeLabel'); // Append the type of time (prep, cook, total)
    return buffer.toString().trim(); // Trim in case label is empty or for general neatness
  }
  // END MODIFIED

  Widget _buildTimeInfo(BuildContext context, IconData icon, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink(); // If formatted time is empty, don't show
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: Colors.grey[700]),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
    ]);
  }

  void _showStyledNutritionDialog(BuildContext context, Recipe recipe) {
    final nutritionInfo = recipe.nutrition;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Nutrition Info (Per Serving)'),
        content: SingleChildScrollView(child: NutritionCard(nutrition: nutritionInfo)),
        contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        actions: <Widget>[
          TextButton(child: const Text('Close'), onPressed: () => Navigator.of(dialogContext).pop()),
        ],
      ),
    );
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    if (!mounted) return;
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
        setState(() => _isPerformingAction = false);
        return;
      }
      final success = await recipeProvider.deleteRecipe(recipe.id!, authProvider.token!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe deleted successfully'), backgroundColor: Colors.green));
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

  Future<void> _toggleFavorite(Recipe recipe) async {
    if (!mounted) return;
    if (recipe.id == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot favorite recipe: Recipe has no ID.'), backgroundColor: Colors.orange));
      return;
    }
    if (_isPerformingAction) return;

    setState(() => _isPerformingAction = true);
    final bool wasFavorite = recipe.isFavorite;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to manage favorites.'), backgroundColor: Colors.orange));
        setState(() => _isPerformingAction = false);
        return;
      }
      final success = await recipeProvider.toggleFavorite(recipe.id!, authProvider.token!);

      if (success && mounted) {
        final message = wasFavorite ? 'Removed from favorites' : 'Added to favorites';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update favorites: ${recipeProvider.error ?? "Unknown error"}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating favorites: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _shareRecipe(Recipe recipe) async {
    if (!mounted) return;
    if (_isPerformingAction) return;
    setState(() => _isPerformingAction = true);

    try {
      await Provider.of<RecipeProvider>(context, listen: false).shareRecipe();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe ready to share!'), backgroundColor: Colors.blue));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing recipe: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _handleAskAboutRecipe(Recipe recipe) async {
    if (!mounted) return;
    if (_originatingConversationId != null && _originatingConversationId!.isNotEmpty) {
      if (kDebugMode) print("RecipeDetailScreen: Navigating back to originating chat: $_originatingConversationId");
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      if (kDebugMode) print("RecipeDetailScreen: No originating chat ID found, starting a new chat.");
      await _startNewChatAboutRecipe(recipe);
    }
  }

  Future<void> _startNewChatAboutRecipe(Recipe recipe) async {
    if (!mounted) return;
    if (_creatingConversation || _isPerformingAction) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please log in to start a chat.'),
          backgroundColor: Colors.orange));
      return;
    }

    if (!mounted) return;
    setState(() {
      _creatingConversation = true;
      _isPerformingAction = true;
    });

    if (!mounted) return;
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> snackBarController =
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Starting chat...'),
          duration: Duration(seconds: 10)),
    );

    String? newConversationId;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      newConversationId = await chatProvider.createNewConversation();

      if (!mounted) {
        try { snackBarController.close(); } catch (_) {}
        return;
      }

      if (newConversationId != null) {
        await chatProvider.sendMessage(
            "I'd like to discuss this recipe: ${recipe.title}");

        if (!mounted) {
          try { snackBarController.close(); } catch (_) {}
          return;
        }

        try { snackBarController.close(); } catch (_) {}

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/chat', arguments: {
            'conversationId': newConversationId,
            'initialQuery': "Let's talk about ${recipe.title}",
            'purpose': 'discussRecipeFromDetails'
          });
        }
      } else {
        if (!mounted) return;
        try { snackBarController.close(); } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not create chat conversation'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      try { snackBarController.close(); } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error starting chat: ${e.toString()}'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _creatingConversation = false;
          _isPerformingAction = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeProvider>(
      builder: (context, recipeProvider, child) {

        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        final Recipe? recipeToDisplay = recipeProvider.currentRecipe;
        final partialRecipe = recipeProvider.partialRecipe;

        final isLoading = recipeProvider.isLoading;
        final error = recipeProvider.error;
        final progress = recipeProvider.generationProgress;
        final isCancelling = recipeProvider.isCancelling;
        final wasCancelled = recipeProvider.wasCancelled;
        final bool isAuthenticated = authProvider.isAuthenticated;

        if (isLoading && recipeToDisplay == null && !wasCancelled) {
          if (partialRecipe != null) {
            return Scaffold(
              appBar: AppBar(title: Text(partialRecipe.title.isNotEmpty ? partialRecipe.title : 'Generating Recipe...'), actions: [ if (isLoading && !isCancelling) IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: ()=> recipeProvider.cancelRecipeGeneration(), tooltip: "Cancel Generation") ]),
              body: RecipeGenerationProgress(
                partialRecipe: partialRecipe, progress: progress,
                onCancel: () => recipeProvider.cancelRecipeGeneration(), isCancelling: isCancelling,
              ),
            );
          } else {
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

        if (error != null && recipeToDisplay == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recipe Error'), leading: IconButton(icon: const Icon(Icons.close), onPressed: ()=> Navigator.pop(context))),
            body: ErrorDisplay(message: error),
          );
        }

        if (recipeToDisplay == null && !isLoading && error == null && !wasCancelled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe details are not available.'), backgroundColor: Colors.red));
                Navigator.of(context).pop();
              }
            }
          });
          return Scaffold(
            appBar: AppBar(title: const Text('Recipe Not Found'), leading: IconButton(icon: const Icon(Icons.close), onPressed: ()=> Navigator.pop(context))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (recipeToDisplay == null) {
          return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('An unexpected error occurred trying to display the recipe.'))
          );
        }

        final recipe = recipeToDisplay;

        bool hasTimeInfo = (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0) ||
            (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0) ||
            (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0);

        final askButtonLabel = (_originatingConversationId != null && _originatingConversationId!.isNotEmpty)
            ? 'Return to Chat'
            : 'Ask about this recipe';

        final Widget cookModeButtonWidget = (recipe.steps.isNotEmpty)
            ? FloatingCookModeButton(steps: recipe.steps)
            : const SizedBox.shrink();

        return Scaffold(
          appBar: AppBar(
            title: Text(recipe.title, overflow: TextOverflow.ellipsis),
            actions: [
              if (isAuthenticated && recipe.id != null)
                IconButton(
                    icon: Icon(recipe.isFavorite ? Icons.favorite : Icons.favorite_border, color: recipe.isFavorite ? Colors.redAccent : null),
                    tooltip: recipe.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    onPressed: _isPerformingAction ? null : () => _toggleFavorite(recipe)
                ),
              IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Share recipe',
                  onPressed: _isPerformingAction ? null : () => _shareRecipe(recipe)
              ),
              if (isAuthenticated && recipe.id != null)
                IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete recipe',
                    onPressed: _isPerformingAction ? null : () => _deleteRecipe(recipe)
                ),
              IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Nutrition Info',
                  onPressed: () => _showStyledNutritionDialog(context, recipe)
              ),
            ],
          ),
          floatingActionButton: (!_isCookModeButtonCustomPositioned && _showFloatingButton && recipe.steps.isNotEmpty)
              ? cookModeButtonWidget
              : null,
          floatingActionButtonLocation: _currentFabLocation,
          body: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recipe.thumbnailUrl != null)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          recipe.thumbnailUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (context, error, stack) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                        ),
                      )
                    else
                      Container(
                        height: 150,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Center(child: Icon(Icons.restaurant_menu, size: 60, color: Theme.of(context).primaryColor.withOpacity(0.4))),
                      ),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(recipe.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                  children: [
                                    Icon(Icons.people_outline, size: 18, color: Colors.grey[700]), const SizedBox(width: 4),
                                    Text('Serves ${recipe.servings}', style: Theme.of(context).textTheme.titleSmall),
                                    const SizedBox(width: 16),
                                    Icon(Icons.list_alt_outlined, size: 18, color: Colors.grey[700]), const SizedBox(width: 4),
                                    Text('${recipe.steps.length} step${recipe.steps.length != 1 ? 's' : ''}', style: Theme.of(context).textTheme.titleSmall)
                                  ]
                              ),
                              // MODIFIED: Use _formatRecipeTime for displaying time
                              if (hasTimeInfo) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                    spacing: 16,
                                    runSpacing: 4,
                                    children: [
                                      if (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0)
                                        _buildTimeInfo(context, Icons.timer_outlined, _formatRecipeTime(recipe.prepTimeMinutes, 'prep')),
                                      if (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0)
                                        _buildTimeInfo(context, Icons.whatshot_outlined, _formatRecipeTime(recipe.cookTimeMinutes, 'cook')),
                                      if (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0)
                                        _buildTimeInfo(context, Icons.schedule_outlined, _formatRecipeTime(recipe.totalTimeMinutes, 'total')),
                                    ]
                                )
                              ]
                              // END MODIFIED
                            ]
                        )
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ingredients', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              IngredientList(ingredients: recipe.ingredients)
                            ]
                        )
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
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
                                        child: StepCard(
                                          step: recipe.steps[index],
                                          stepNumber: index + 1,
                                          allSteps: recipe.steps,
                                        )
                                    )
                                )
                            ]
                        )
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Center(
                            child: ElevatedButton.icon(
                                icon: Icon(
                                    (_originatingConversationId != null && _originatingConversationId!.isNotEmpty)
                                        ? Icons.arrow_back_ios_new
                                        : Icons.chat_bubble_outline
                                ),
                                label: Text(askButtonLabel),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: const TextStyle(fontSize: 16),
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: (_creatingConversation || _isPerformingAction) ? null : () => _handleAskAboutRecipe(recipe)
                            )
                        )
                    ),
                    SizedBox(height: _isCookModeButtonCustomPositioned ? 80.0 : 80.0),
                  ],
                ),
              ),
              if (_isCookModeButtonCustomPositioned && _showFloatingButton && recipe.steps.isNotEmpty)
                Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: cookModeButtonWidget,
                    )
                ),
            ],
          ),
        );
      },
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: effectiveColor, size: 20),
      label: Text(label, style: TextStyle(color: effectiveColor)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
    );
  }
}