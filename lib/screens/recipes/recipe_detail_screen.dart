// lib/screens/recipes/recipe_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode print

import '../../providers/recipe_provider.dart';
import '../../models/recipe.dart'; // Ensure updated model is imported
import '../../models/recipe_step.dart';
import '../../models/nutrition_info.dart'; // Ensure updated NutritionInfo model is imported
import '../../widgets/recipes/ingredient_list.dart';
import '../../widgets/recipes/step_card.dart';
import '../../widgets/recipes/nutrition_card.dart'; // Import for the styled NutritionCard
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({Key? key}) : super(key: key);

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

            // --- Chat Button --- Unchanged
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Ask about this recipe'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/chatList');
                  },
                ),
              ),
            ),

            const SizedBox(height: 24), // Bottom padding - Unchanged
          ],
        ),
      ),
    );
  }
}
