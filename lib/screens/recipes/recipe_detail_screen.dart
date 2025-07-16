import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode print
import 'package:flutter/rendering.dart'; // For ScrollDirection

import '../../providers/recipe_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/recipe.dart';
// import '../../models/chat_message.dart'; // Not directly used in this file
import '../../widgets/recipes/ingredient_list.dart';
import '../../widgets/recipes/step_card.dart';
import '../../widgets/recipes/nutrition_card.dart';
import '../../widgets/recipes/recipe_generation_progress.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';
import '../../widgets/recipes/floating_cook_mode_button.dart';
// import '../../widgets/recipes/cook_mode_view.dart'; // CookModeView is launched by the button

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

  bool _showButtonOverall = true;
  bool _isAtScrollBottom = false;

  static const double _fabHeightHorizontal = 56.0;
  static const double _fabBottomMarginDefault = 20.0;
  static const double _fabSideMargin = 16.0;
  static const double _fabVerticalButtonBottomOffset = 20.0;

  String? _originatingConversationId;
  bool _creatingConversation = false;
  bool _isPerformingAction = false;
  bool _isInitialRecipeSet = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isInitialRecipeSet && widget.initialRecipe != null) {
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
            if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
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
    bool newShowButtonState = _showButtonOverall;
    bool newIsAtBottomState = _isAtScrollBottom;

    const double atBottomThreshold = 5.0;
    if (scrollPosition.maxScrollExtent > 0) {
      newIsAtBottomState = (scrollPosition.maxScrollExtent - scrollPosition.pixels) <= atBottomThreshold;
    } else {
      newIsAtBottomState = true;
    }

    if (!newIsAtBottomState) {
      if (scrollPosition.userScrollDirection == ScrollDirection.reverse) {
        newShowButtonState = true;
      } else if (scrollPosition.userScrollDirection == ScrollDirection.forward) {
        if (scrollPosition.pixels > 50) {
          newShowButtonState = false;
        }
      }
      if (scrollPosition.pixels <= scrollPosition.minScrollExtent + 10) {
        newShowButtonState = true;
      }
    } else {
      newShowButtonState = true;
    }

    if (newShowButtonState != _showButtonOverall || newIsAtBottomState != _isAtScrollBottom) {
      setState(() {
        _showButtonOverall = newShowButtonState;
        _isAtScrollBottom = newIsAtBottomState;
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

  String _formatRecipeTime(int? totalMinutes, String timeTypeLabel) {
    if (totalMinutes == null || totalMinutes <= 0) return "";
    final duration = Duration(minutes: totalMinutes);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    StringBuffer buffer = StringBuffer();
    if (hours > 0) buffer.write('$hours hr');
    if (minutes > 0) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write('$minutes min');
    }
    if (buffer.isEmpty) return '$totalMinutes min $timeTypeLabel';
    buffer.write(' $timeTypeLabel');
    return buffer.toString().trim();
  }

  Widget _buildTimeInfo(BuildContext context, IconData icon, String text, String label) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE53E3E)),
          const SizedBox(width: 6),
          Text(
            '$text $label',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildHeroSection(Recipe recipe) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isAuthenticated = authProvider.isAuthenticated;
    
    return Container(
      height: 300,
      child: Stack(
        children: [
          // Hero Image
          Positioned.fill(
            child: recipe.thumbnailUrl != null
                ? Image.network(
                    recipe.thumbnailUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => 
                        progress == null ? child : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (context, error, stack) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                    ),
                  )
                : Container(
                    color: const Color(0xFFE53E3E).withOpacity(0.1),
                    child: Center(
                      child: Icon(
                        Icons.restaurant_menu,
                        size: 60,
                        color: const Color(0xFFE53E3E).withOpacity(0.4),
                      ),
                    ),
                  ),
          ),
          
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
          ),
          
          // Favorite Button
          if (isAuthenticated && recipe.id != null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: recipe.isFavorite ? const Color(0xFFE53E3E) : Colors.grey[600],
                  ),
                  onPressed: _isPerformingAction ? null : () => _toggleFavorite(recipe),
                ),
              ),
            ),
          
          // Share Button
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.share_outlined, color: Colors.grey[600]),
                onPressed: _isPerformingAction ? null : () => _shareRecipe(recipe),
              ),
            ),
          ),
          
          // Recipe Title and Info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline, size: 14, color: Color(0xFFE53E3E)),
                            const SizedBox(width: 4),
                            Text(
                              'Serves ${recipe.servings}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.list_alt_outlined, size: 14, color: Color(0xFFE53E3E)),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.steps.length} Steps',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

        // Loading states and error handling remain the same as before
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

        if (recipeToDisplay == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe details are not available.'), backgroundColor: Colors.red));
              Navigator.of(context).pop();
            }
          });
          return Scaffold(
            appBar: AppBar(title: const Text('Recipe Not Found'), leading: IconButton(icon: const Icon(Icons.close), onPressed: ()=> Navigator.pop(context))),
            body: const Center(child: LoadingIndicator(message: "Recipe not found...")),
          );
        }

        final recipe = recipeToDisplay;
        bool hasTimeInfo = (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0) ||
            (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0) ||
            (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0);
        final askButtonLabel = (_originatingConversationId != null && _originatingConversationId!.isNotEmpty)
            ? 'Return to Chat'
            : 'Ask about this recipe';

        double scrollBottomPadding = _fabBottomMarginDefault + _fabHeightHorizontal + 20.0;
        if (_isAtScrollBottom) {
          scrollBottomPadding = 20.0;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Details'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              if (isAuthenticated && recipe.id != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete recipe',
                  onPressed: _isPerformingAction ? null : () => _deleteRecipe(recipe),
                ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Nutrition Info',
                onPressed: () => _showStyledNutritionDialog(context, recipe),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Section with overlay
                    _buildHeroSection(recipe),
                    
                    // Time Information
                    if (hasTimeInfo)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0)
                              _buildTimeInfo(context, Icons.schedule_outlined, 
                                _formatRecipeTime(recipe.prepTimeMinutes, '').replaceAll(' prep', ''), 'prep'),
                            if (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0)
                              _buildTimeInfo(context, Icons.local_fire_department_outlined, 
                                _formatRecipeTime(recipe.cookTimeMinutes, '').replaceAll(' cook', ''), 'cook'),
                            if (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0)
                              _buildTimeInfo(context, Icons.timer_outlined, 
                                _formatRecipeTime(recipe.totalTimeMinutes, '').replaceAll(' total', ''), 'total'),
                          ],
                        ),
                      ),
                    
                    // Ingredients Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ingredients',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...recipe.ingredients.map((ingredient) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 8, right: 12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE53E3E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    ingredient.toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ],
                      ),
                    ),
                    
                    // Instructions Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Instructions',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (recipe.steps.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0),
                                child: Text(
                                  'No steps available...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...recipe.steps.asMap().entries.map((entry) {
                              final index = entry.key;
                              final step = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Step Image (placeholder for now)
                                    if(step.imageUrl !=  null)

                                      Container(
                                      width: double.infinity,
                                      height: 200,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: AspectRatio(
                                        aspectRatio:16/9,
                                        child:Image.network(
                                          step.imageUrl!,
                                          fit: BoxFit.cover,
                                          )
                                      ),
                                    )  
                                    else
                                     Container(
                                      width: double.infinity,
                                      height: 200,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                    ),

                                    
                                    // Step Number and Description
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          margin: const EdgeInsets.only(right: 12, top: 2),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFE53E3E),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Step ${index + 1}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              IntrinsicHeight(
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width:4,
                                                      height:double.infinity,
                                                      color:Color(0xFFE53E3E),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                      step.text,
                                                      // "Step instruction",
                                                      style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                      height: 1.5,
                                                                                                        ),
                                                                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                    
                    // Action Buttons
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Cook Mode Button
                          if (recipe.steps.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.restaurant_menu, color: Colors.white),
                                label: const Text(
                                  'Cook Mode',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53E3E),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  // Handle cook mode
                                },
                              ),
                            ),
                          
                          // Ask About Recipe Button
                          Container(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: Icon(
                                (_originatingConversationId != null && _originatingConversationId!.isNotEmpty)
                                    ? Icons.arrow_back_ios_new
                                    : Icons.chat_bubble_outline,
                                color: const Color(0xFFE53E3E),
                              ),
                              label: Text(
                                askButtonLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE53E3E),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Color(0xFFE53E3E), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: (_creatingConversation || _isPerformingAction) 
                                  ? null 
                                  : () => _handleAskAboutRecipe(recipe),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: scrollBottomPadding),
                  ],
                ),
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