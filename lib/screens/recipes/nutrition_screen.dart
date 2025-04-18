// screens/recipes/nutrition_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/recipe_provider.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final recipe = recipeProvider.currentRecipe;

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nutrition Information')),
        body: const Center(child: Text('No recipe found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Information'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
              Text(
                'Per Serving (Serves ${recipe.servings})',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // Calories
              _buildNutritionItem(
                'Calories',
                '${recipe.nutrition.calories}',
                'kcal',
                Colors.orange,
                Icons.local_fire_department,
              ),
              const SizedBox(height: 16),

              // Protein
              _buildNutritionItem(
                'Protein',
                recipe.nutrition.protein.replaceAll('g', ''),
                'g',
                Colors.red,
                Icons.fitness_center,
              ),
              const SizedBox(height: 16),

              // Fat
              _buildNutritionItem(
                'Fat',
                recipe.nutrition.fat.replaceAll('g', ''),
                'g',
                Colors.yellow[700]!,
                Icons.bubble_chart,
              ),
              const SizedBox(height: 16),

              // Carbs
              _buildNutritionItem(
                'Carbohydrates',
                recipe.nutrition.carbs.replaceAll('g', ''),
                'g',
                Colors.green,
                Icons.grain,
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Disclaimer
              const Text(
                'Note: Nutritional values are estimates only and may vary based on specific ingredients used and portion sizes.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionItem(
      String label,
      String value,
      String unit,
      Color color,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 40,
            color: color,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black),
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}