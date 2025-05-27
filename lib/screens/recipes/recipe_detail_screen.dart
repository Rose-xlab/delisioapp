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
  static const double _fabVerticalButtonBottomOffset = 20.0; // How far from bottom edge for vertical button (if not perfectly centered)
  // For true vertical center, this isn't used, top/bottom:0 + Align is used.


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
    // ... (implementation as before)
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

  Widget _buildTimeInfo(BuildContext context, IconData icon, String text) {
    // ... (implementation as before)
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: Colors.grey[700]),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
    ]);
  }

  void _showStyledNutritionDialog(BuildContext context, Recipe recipe) {
    // ... (implementation as before)
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
    // ... (implementation as before)
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    // ... (implementation as before)
  }

  Future<void> _shareRecipe(Recipe recipe) async {
    // ... (implementation as before)
  }

  Future<void> _handleAskAboutRecipe(Recipe recipe) async {
    // ... (implementation as before)
  }

  Future<void> _startNewChatAboutRecipe(Recipe recipe) async {
    // ... (implementation as before)
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeProvider>(
      builder: (context, recipeProvider, child) {

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final Recipe? recipeToDisplay = recipeProvider.currentRecipe;
        // ... (rest of your loading, error, and recipe null checks as before) ...
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
                    SizedBox(height: scrollBottomPadding),
                  ],
                ),
              ),

              // Cook Mode Button positioned with AnimatedPositioned
              if (recipe.steps.isNotEmpty)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,

                  // Logic for positioning
                  top: (_isAtScrollBottom && _showButtonOverall)
                      ? 0 // Allows Align to vertically center in the full height of the Stack
                      : null, // Not constrained by top when horizontal or hidden

                  bottom: (_isAtScrollBottom && _showButtonOverall)
                      ? 0 // Allows Align to vertically center in the full height of the Stack
                      : (_showButtonOverall
                      ? _fabBottomMarginDefault // Default bottom margin for horizontal FAB
                      : -(_fabHeightHorizontal + 40.0)), // Position off-screen when hidden

                  right: (_isAtScrollBottom && _showButtonOverall)
                      ? _fabSideMargin // Pinned to the right edge
                      : (!_isAtScrollBottom && _showButtonOverall
                      ? _fabSideMargin // For horizontal centering with left
                      : _fabSideMargin), // Maintain right constraint for slide-out from bottom
                  // Or if sliding out from right: -100.0 (some off-screen value)

                  left: (_isAtScrollBottom && _showButtonOverall)
                      ? null // Not constrained from left when vertical on right
                      : (!_isAtScrollBottom && _showButtonOverall
                      ? _fabSideMargin // For horizontal centering with right
                      : _fabSideMargin), // Maintain left constraint for slide-out from bottom

                  // Width is null for the vertical button (intrinsic size)
                  // and for the horizontal button (AnimatedPositioned with left/right handles centering)
                  width: null,

                  child: AnimatedOpacity(
                    opacity: _showButtonOverall ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: (_isAtScrollBottom && _showButtonOverall)
                        ? Align(
                      alignment: Alignment.center, // Vertically centers the button in the right-edge strip
                      child: FloatingCookModeButton(
                        steps: recipe.steps,
                        isAtScrollBottom: true, // Renders vertically
                      ),
                    )
                        : Center( // Ensures the horizontal FAB is centered in its allocated space
                      child: FloatingCookModeButton(
                        steps: recipe.steps,
                        isAtScrollBottom: false, // Renders horizontally
                      ),
                    ),
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
