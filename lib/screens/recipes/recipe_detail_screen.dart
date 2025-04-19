// lib/screens/recipes/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode print

import '../../providers/recipe_provider.dart';
import '../../models/recipe.dart'; // Ensure updated model is imported
import '../../models/recipe_step.dart';
import '../../models/nutrition_info.dart'; // Import if NutritionInfo class is separate
import '../../widgets/recipes/ingredient_list.dart';
import '../../widgets/recipes/step_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({Key? key}) : super(key: key);

  // Helper widget to build the Icon + Text display for time info
  Widget _buildTimeInfo(BuildContext context, IconData icon, String text) {
    // Ensure text is not empty before building the Row
    if (text.trim().isEmpty) {
      return const SizedBox.shrink(); // Return empty widget if text is empty
    }
    return Row(
      mainAxisSize: MainAxisSize.min, // Keep elements close together
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(
            text,
            // Use ?.copyWith for safety in case textTheme or bodyLarge is null
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final recipe = recipeProvider.currentRecipe;
    final isLoading = recipeProvider.isLoading;
    final error = recipeProvider.error;

    // Add a debug print to see the recipe data the UI receives
    if (kDebugMode) {
      print("Recipe Detail Build: ID=${recipe?.id}, Prep=${recipe?.prepTimeMinutes}, Cook=${recipe?.cookTimeMinutes}, Total=${recipe?.totalTimeMinutes}");
    }


    // --- Handle Loading/Error/Null ---
    if (isLoading && recipe == null) {
      return Scaffold(appBar: AppBar(title: const Text('Loading Recipe...')), body: const LoadingIndicator(message: 'Preparing your recipe...'));
    }
    if (error != null && recipe == null) {
      return Scaffold(appBar: AppBar(title: const Text('Recipe Error')), body: ErrorDisplay(message: error));
    }
    if (recipe == null) {
      return Scaffold(appBar: AppBar(title: const Text('Recipe Not Found')), body: const Center(child: Text('Could not load the recipe details.')));
    }

    // --- Recipe Loaded UI ---
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            // Navigate to a dedicated Nutrition screen if you have one
            // Or display nutrition info in a dialog/modal
            onPressed: () {
              // Example: Show simple dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Nutrition Info (per serving)'),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calories: ${recipe.nutrition.calories}'),
                        Text('Protein: ${recipe.nutrition.protein}'),
                        Text('Fat: ${recipe.nutrition.fat}'),
                        Text('Carbs: ${recipe.nutrition.carbs}'),
                      ]
                  ),
                  actions: [ TextButton( child: const Text('OK'), onPressed: () => Navigator.of(context).pop(), ), ],
                ),
              );
              // If you have a dedicated route:
              // Navigator.of(context).pushNamed('/nutrition');
            },
            tooltip: 'Nutrition Info',
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
                    Text(recipe.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Row for Servings and Steps Count
                    Row(
                        children: [
                          Icon(Icons.people_outline, size: 18, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text('Serves ${recipe.servings}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
                          const SizedBox(width: 16),
                          Icon(Icons.list_alt, size: 18, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text('${recipe.steps.length} steps', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
                        ]
                    ), // End Servings/Steps Row
                    const SizedBox(height: 8), // Space before time info

                    // --- ADDED: Row for Time Info ---
                    Row(
                      // Adjust spacing as needed, maybe Wrap is better if space is tight
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Show Prep Time if available
                        if (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0)
                          _buildTimeInfo(context, Icons.timer_outlined, '${recipe.prepTimeMinutes} min prep'),

                        // Add spacing only if needed
                        if (recipe.prepTimeMinutes != null && recipe.prepTimeMinutes! > 0 && (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0 || recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0))
                          const SizedBox(width: 12),

                        // Show Cook Time if available
                        if (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0)
                          _buildTimeInfo(context, Icons.whatshot_outlined, '${recipe.cookTimeMinutes} min cook'),

                        // Add spacing only if needed
                        if (recipe.cookTimeMinutes != null && recipe.cookTimeMinutes! > 0 && recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0)
                          const SizedBox(width: 12),

                        // Show Total Time if available
                        if (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0)
                          _buildTimeInfo(context, Icons.schedule, '${recipe.totalTimeMinutes} min total'),
                      ],
                    ), // End Time Row
                    // --- END ADDED Row ---
                  ] // End Children of Header Column
              ), // End Header Padding
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // --- Ingredients ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ingredients', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    IngredientList(ingredients: recipe.ingredients),
                  ]
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // --- Steps ---
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
                      ListView.builder( // Use ListView.builder for potentially long lists
                        shrinkWrap: true, // Important inside SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Disable ListView's own scrolling
                        itemCount: recipe.steps.length,
                        itemBuilder: (context, index) {
                          final step = recipe.steps[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0), // Add padding between steps
                            child: StepCard(step: step, stepNumber: index + 1),
                          );
                        },
                      ),
                  ] // End children of Steps Column
              ), // End Steps Padding
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // --- Nutrition Button --- (Removed explicit check for null, assume default exists)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Center(child: OutlinedButton.icon(
                onPressed: () {
                  // Example: Show simple dialog for nutrition
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Nutrition Info (per serving)'),
                      content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Calories: ${recipe.nutrition.calories}'),
                            Text('Protein: ${recipe.nutrition.protein}'),
                            Text('Fat: ${recipe.nutrition.fat}'),
                            Text('Carbs: ${recipe.nutrition.carbs}'),
                          ]
                      ),
                      actions: [ TextButton( child: const Text('OK'), onPressed: () => Navigator.of(context).pop(), ), ],
                    ),
                  );
                  // If you create a dedicated route:
                  // Navigator.of(context).pushNamed('/nutrition');
                },
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('View Nutrition Information'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), textStyle: const TextStyle(fontSize: 16)),
              )),
            ),

            // --- Chat Button ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Ask about this recipe'),
                  style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), textStyle: const TextStyle(fontSize: 16), ),
                  onPressed: () {
                    // Potentially pass recipe title or ID to pre-fill chat?
                    // For now, just navigates to chat list
                    Navigator.of(context).pushNamed('/chatList');
                  },
                ),
              ),
            ),
            // --- END OF Chat Button ---

            const SizedBox(height: 24), // Bottom padding
          ], // End children of Main Column
        ), // End Main Column
      ), // End SingleChildScrollView
    ); // End Scaffold
  } // End build method
} // End class