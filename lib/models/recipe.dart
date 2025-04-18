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
    return Recipe(
      id: json['id'],
      title: json['title'],
      servings: json['servings'] ?? 0,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: (json['steps'] as List?)
          ?.map((step) => RecipeStep.fromJson(step))
          .toList() ?? [],
      nutrition: NutritionInfo.fromJson(json['nutrition'] ?? {}),
      query: json['query'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
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