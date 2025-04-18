// models/recipe.dart
import 'recipe_step.dart';
import 'nutrition_info.dart';

class Recipe {
  final String? id;
  final String title;
  final int servings;
  final List<String> ingredients;
  final List<RecipeStep> steps;
  final NutritionInfo nutrition;
  final String query;
  final DateTime createdAt;

  Recipe({
    this.id,
    required this.title,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    required this.query,
    required this.createdAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Print the raw JSON for debugging
    print('Parsing Recipe from JSON: ${json.keys}');

    // Carefully extract and transform step data
    List<RecipeStep> parseSteps(dynamic stepsJson) {
      if (stepsJson == null) {
        print('No steps data found in recipe JSON');
        return [];
      }

      try {
        final List<RecipeStep> results = [];

        for (var step in stepsJson) {
          // Ensure step is a Map
          if (step is Map) {
            // Convert to Map<String, dynamic> if needed
            final Map<String, dynamic> stepMap =
            step is Map<String, dynamic> ? step : Map<String, dynamic>.from(step);

            // Create the step
            final recipeStep = RecipeStep.fromJson(stepMap);
            results.add(recipeStep);

            // Log for debugging
            print('Added step: "${recipeStep.text.substring(0,
                recipeStep.text.length > 30 ? 30 : recipeStep.text.length)}..." with image ${recipeStep.imageUrl != null ? "YES" : "NO"}');
          } else {
            print('Invalid step format: $step');
          }
        }

        print('Successfully parsed ${results.length} steps');
        return results;
      } catch (e) {
        print('Error parsing steps: $e');
        print('Steps JSON format: $stepsJson');
        return [];
      }
    }

    // Extract ingredients
    List<String> extractIngredients(dynamic ingredients) {
      if (ingredients == null) return [];

      try {
        if (ingredients is List) {
          return ingredients.map((item) => item.toString()).toList();
        }
      } catch (e) {
        print('Error extracting ingredients: $e');
      }
      return [];
    }

    // Handle the createdAt date safely
    DateTime parseCreatedAt(dynamic dateStr) {
      if (dateStr == null) return DateTime.now();

      try {
        if (dateStr is String) {
          return DateTime.parse(dateStr);
        }
      } catch (e) {
        print('Error parsing date: $e');
      }
      return DateTime.now();
    }

    return Recipe(
      id: json['id'],
      title: json['title'] ?? 'Untitled Recipe',
      servings: json['servings'] ?? 4,
      ingredients: extractIngredients(json['ingredients']),
      steps: parseSteps(json['steps']),
      nutrition: NutritionInfo.fromJson(json['nutrition'] ?? {}),
      query: json['query'] ?? '',
      createdAt: parseCreatedAt(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'servings': servings,
      'ingredients': ingredients,
      'steps': steps.map((step) => step.toJson()).toList(),
      'nutrition': nutrition.toJson(),
      'query': query,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}