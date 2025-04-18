// screens/recipes/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/recipes/ingredient_list.dart';
import '../../widgets/recipes/step_card.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final recipe = recipeProvider.currentRecipe;

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: const Center(child: Text('No recipe found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).pushNamed('/nutrition');
            },
            tooltip: 'Nutrition Info',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 20, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Serves ${recipe.servings}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.timelapse, size: 20, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.steps.length} steps',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            const Divider(height: 1),

            // Ingredients Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  IngredientList(ingredients: recipe.ingredients),
                ],
              ),
            ),

            // Divider
            const Divider(height: 1),

            // Steps Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Step cards with illustrations
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recipe.steps.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: StepCard(
                          step: recipe.steps[index],
                          stepNumber: index + 1,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Nutrition Button
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/nutrition');
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('View Nutrition Information'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}