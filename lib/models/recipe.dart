// lib/models/recipe.dart
import 'package:flutter/foundation.dart'; // For kDebugMode print

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
  // --- ADDED TIME FIELDS ---
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final int? totalTimeMinutes;
  // --- END ADDED FIELDS ---

  Recipe({
    this.id,
    required this.title,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    required this.query,
    required this.createdAt,
    // Add new fields to constructor
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.totalTimeMinutes,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Print the raw JSON for debugging if needed
    // print('Parsing Recipe from JSON. Keys: ${json.keys}');

    // Helper functions remain the same
    List<RecipeStep> parseSteps(dynamic stepsJson) {
      if (stepsJson == null || stepsJson is! List || stepsJson.isEmpty) {
        if (kDebugMode) print('No valid steps data found in recipe JSON');
        return [];
      }
      try {
        final List<RecipeStep> results = [];
        for (var step in stepsJson) {
          if (step is Map) {
            final Map<String, dynamic> stepMap = Map<String, dynamic>.from(step);
            // Ensure RecipeStep.fromJson exists and handles its fields safely
            try {
              results.add(RecipeStep.fromJson(stepMap));
            } catch (e) {
              if (kDebugMode) print('Error parsing individual step: $e - Step data: $stepMap');
            }
          } else {
            if (kDebugMode) print('Skipping invalid step format: $step');
          }
        }
        if (kDebugMode) print('Successfully parsed ${results.length} steps');
        return results;
      } catch (e, s) {
        if (kDebugMode) print('Error parsing steps list: $e \nStack: $s');
        if (kDebugMode) print('Steps JSON format received: $stepsJson');
        return [];
      }
    }

    List<String> extractIngredients(dynamic ingredients) {
      if (ingredients == null || ingredients is! List || ingredients.isEmpty) return [];
      try {
        // Ensure all items are strings
        return ingredients.map((item) => item.toString()).toList();
      } catch (e) {
        if (kDebugMode) print('Error extracting ingredients: $e');
        return [];
      }
    }

    DateTime parseCreatedAt(dynamic dateStr) {
      if (dateStr == null || dateStr is! String) return DateTime.now();
      try { return DateTime.parse(dateStr); }
      catch (e) { if (kDebugMode) print('Error parsing date: $e'); return DateTime.now();}
    }

    // Safely parse nullable integer time fields
    int? parseIntSafe(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      // Handle double if necessary, e.g., json['servings'] could be 4.0
      if (value is double) return value.toInt();
      return null;
    }

    // Safely parse Nutrition Info
    NutritionInfo parseNutrition(dynamic nutritionJson) {
      if (nutritionJson is Map<String, dynamic>) {
        // Assuming NutritionInfo.fromJson exists and handles nulls/types safely
        try {
          return NutritionInfo.fromJson(nutritionJson);
        } catch (e) {
          if (kDebugMode) print('Error parsing nutrition info: $e');
        }
      }
      // Return default if null, not a map, or parsing fails
      return NutritionInfo(calories: 0, protein: '0g', fat: '0g', carbs: '0g');
    }


    return Recipe(
      id: json['id'] as String?, // Cast as nullable String
      title: json['title'] as String? ?? 'Untitled Recipe', // Handle null title
      servings: parseIntSafe(json['servings']) ?? 4, // Use safe parse and default
      ingredients: extractIngredients(json['ingredients']),
      steps: parseSteps(json['steps']),
      nutrition: parseNutrition(json['nutrition']), // Use safe parsing helper
      query: json['query'] as String? ?? '', // Handle null query
      // Handle both potential key names from DB/Backend
      createdAt: parseCreatedAt(json['createdAt'] ?? json['created_at']),
      // --- PARSE NEW TIME FIELDS ---
      // Keys match the database column names
      prepTimeMinutes: parseIntSafe(json['prep_time_minutes']),
      cookTimeMinutes: parseIntSafe(json['cook_time_minutes']),
      totalTimeMinutes: parseIntSafe(json['total_time_minutes']),
    );
  }

  // Optional: Update toJson if you need to serialize this model
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'servings': servings,
      'ingredients': ingredients,
      // Ensure RecipeStep and NutritionInfo have toJson methods
      'steps': steps.map((step) => step.toJson()).toList(),
      'nutrition': nutrition.toJson(),
      'query': query,
      'createdAt': createdAt.toIso8601String(),
      // Add time fields - keys match DB columns for consistency if sending back
      'prep_time_minutes': prepTimeMinutes,
      'cook_time_minutes': cookTimeMinutes,
      'total_time_minutes': totalTimeMinutes,
    };
  }
}