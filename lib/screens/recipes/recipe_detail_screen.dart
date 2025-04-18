// lib/screens/recipes/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/recipe_provider.dart';
// Import other needed providers if used, e.g., for context in chat nav
// import '../../providers/chat_provider.dart';
// Ensure these widget paths are correct for your project structure
import '../../widgets/recipes/ingredient_list.dart';
import '../../widgets/recipes/step_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';
// import '../../models/recipe.dart'; // Removed as flagged unused - add back if needed

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final recipe = recipeProvider.currentRecipe;
    final isLoading = recipeProvider.isLoading;
    final error = recipeProvider.error;

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
            onPressed: () => Navigator.of(context).pushNamed('/nutrition'),
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
                    Row( children: [
                      Icon(Icons.people_outline, size: 18, color: Colors.grey[700]), const SizedBox(width: 4),
                      Text('Serves ${recipe.servings}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
                      const SizedBox(width: 16),
                      Icon(Icons.list_alt, size: 18, color: Colors.grey[700]), const SizedBox(width: 4),
                      Text('${recipe.steps.length} steps', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
                    ]),
                  ]
              ),
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

                    // Check if steps has data
                    if (recipe.steps.isEmpty)
                    // FIX: Removed const from parents and TextStyle
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Text(
                            'No steps available for this recipe.',
                            style: TextStyle( // Removed const
                              fontSize: 16,
                              color: Colors.grey[600], // Non-const value
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: List.generate(recipe.steps.length, (index) {
                          final step = recipe.steps[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: StepCard(step: step, stepNumber: index + 1),
                          );
                        }),
                      ),
                  ]
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // --- Nutrition Button ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Center(child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/nutrition'),
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    final recipeTitle = recipe.title;
                    // FIX: Commented out print statement
                    // print('Navigating to chat from recipe: $recipeTitle');
                    Navigator.of(context).pushNamed('/chatList');
                  },
                ),
              ),
            ),
            // --- END OF Chat Button ---

            const SizedBox(height: 24), // Bottom padding
          ],
        ),
      ),
    );
  }
}

