// screens/recipes/nutrition_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import the intl package

import '../../providers/recipe_provider.dart';
// Import the updated NutritionInfo if needed for type checks, although provider handles it
// import '../../models/nutrition_info.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final recipe = recipeProvider.currentRecipe;

    // --- Add Number Formatter ---
    // Create a formatter for grams (shows 0 or 1 decimal place)
    final gramFormat = NumberFormat("0.#");

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nutrition Information')),
        body: const Center(child: Text('No recipe found')),
      );
    }

    // Get the NutritionInfo object for easier access
    final nutrition = recipe.nutrition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Information'),
        // Optional: Add theme consistency if needed
        // backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                // Use theme text styles for consistency
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Per Serving (Serves ${recipe.servings})',
                // Use theme text styles and colors
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Calories - Already an int, just convert to String
              _buildNutritionItem(
                context, // Pass context for theme access in helper
                'Calories',
                nutrition.calories.toString(), // Convert int to String
                'kcal',
                Colors.orange, // Consider using Theme colors here too
                Icons.local_fire_department,
              ),
              const SizedBox(height: 16),

              // Protein - Format double to String
              _buildNutritionItem(
                context,
                'Protein',
                gramFormat.format(nutrition.protein), // Format double
                'g',
                Colors.red, // Consider Theme colors
                Icons.fitness_center,
              ),
              const SizedBox(height: 16),

              // Fat - Format double to String
              _buildNutritionItem(
                context,
                'Fat',
                gramFormat.format(nutrition.fat), // Format double
                'g',
                Colors.amber, // Use amber instead of yellow[700]? Or Theme colors
                Icons.water_drop_outlined, // Updated icon maybe?
              ),
              const SizedBox(height: 16),

              // Carbs - Format double to String
              _buildNutritionItem(
                context,
                'Carbohydrates',
                gramFormat.format(nutrition.carbs), // Format double
                'g',
                Colors.green, // Consider Theme colors
                Icons.grain,
              ),

              // --- Optional: Add rows for other nutrients if they exist ---
              // Example for Fiber:
              // if (nutrition.fiber != null) ...[
              //   const SizedBox(height: 16),
              //   _buildNutritionItem(
              //     context,
              //     'Fiber',
              //     gramFormat.format(nutrition.fiber!),
              //     'g',
              //     Colors.brown,
              //     Icons.grass,
              //   ),
              // ],
              // Example for Sodium:
              // if (nutrition.sodium != null) ...[
              //   const SizedBox(height: 16),
              //   _buildNutritionItem(
              //     context,
              //     'Sodium',
              //      NumberFormat("0").format(nutrition.sodium!), // Format without decimals
              //     'mg',
              //     Colors.blueGrey,
              //     Icons.science_outlined, // Placeholder icon
              //   ),
              // ],


              const SizedBox(height: 32),
              const Divider(), // Use theme divider color automatically
              const SizedBox(height: 16),

              // Disclaimer
              Text(
                'Note: Nutritional values are estimates only and may vary based on specific ingredients used and portion sizes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Updated Helper Widget ---
  // Pass BuildContext to access theme styles
  Widget _buildNutritionItem(
      BuildContext context,
      String label,
      String value, // Keep accepting the formatted string value
      String unit,
      Color color, // Keep color for now, could be derived from theme later
      IconData icon,
      ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Use theme background color with opacity
        color: color.withOpacity(0.1), // Or: colorScheme.surfaceContainerHighest
        borderRadius: BorderRadius.circular(12),
        // Optional: Add a subtle border
        // border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 40,
            color: color, // Keep icon color tied to the passed color
          ),
          const SizedBox(width: 16),
          // Use Expanded to prevent overflow if text is long
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.titleMedium, // Use theme style
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    // Use base style from theme for default text color (adapts to light/dark)
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                    children: [
                      TextSpan(
                        text: value,
                        // Make value stand out more
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color, // Or keep colorScheme.onSurface for less intensity
                        ),
                      ),
                      // Add non-breaking space before unit for better wrapping
                      const TextSpan(text: '\u00A0'), // Non-breaking space
                      TextSpan(
                          text: unit,
                          // Slightly smaller/less prominent style for unit
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          )
                      ),
                    ],
                  ),
                  // Handle text overflow
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}