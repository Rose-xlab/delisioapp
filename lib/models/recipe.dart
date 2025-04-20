// lib/models/recipe.dart
import 'package:flutter/foundation.dart'; // For kDebugMode print

// Ensure these point to the correct, updated files
import 'recipe_step.dart';
import 'nutrition_info.dart'; // Assumes this is the updated NutritionInfo model

class Recipe {
  final String? id;
  final String title;
  final int servings;
  final List<String> ingredients;
  final List<RecipeStep> steps;
  final NutritionInfo nutrition; // Uses the potentially complex NutritionInfo model
  final String query;
  final DateTime createdAt;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final int? totalTimeMinutes;
  // Add requestId for cancellation support
  final String? requestId;
  // Add isFavorite flag
  final bool isFavorite;

  Recipe({
    this.id,
    required this.title,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    required this.query,
    required this.createdAt,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.totalTimeMinutes,
    this.requestId, // Added for cancellation support
    this.isFavorite = false, // Default to not favorite
  });

  // Create a copy of the recipe with updated fields
  Recipe copyWith({
    String? id,
    String? title,
    int? servings,
    List<String>? ingredients,
    List<RecipeStep>? steps,
    NutritionInfo? nutrition,
    String? query,
    DateTime? createdAt,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? totalTimeMinutes,
    String? requestId,
    bool? isFavorite,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      nutrition: nutrition ?? this.nutrition,
      query: query ?? this.query,
      createdAt: createdAt ?? this.createdAt,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      requestId: requestId ?? this.requestId,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Debug prints are helpful during development
    // if (kDebugMode) {
    //   print('--- Parsing Recipe ---');
    //   print('JSON Keys: ${json.keys.toList()}');
    // }

    // --- Helper: Safely parse nullable integer fields ---
    // Handles int, String, double (by truncation), or null input.
    int? parseIntSafe(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      // Allow parsing integers represented as strings
      if (value is String) return int.tryParse(value);
      // Handle potential doubles from JSON (e.g., 4.0)
      if (value is double) return value.toInt();
      // If type is unexpected, return null
      return null;
    }

    // --- Helper: Safely parse List<RecipeStep> ---
    // Assumes RecipeStep.fromJson exists and handles its own fields safely.
    List<RecipeStep> parseSteps(dynamic stepsJson) {
      if (stepsJson == null || stepsJson is! List || stepsJson.isEmpty) {
        return []; // Return empty list if no valid steps data
      }
      final List<RecipeStep> results = [];
      for (var stepData in stepsJson) {
        // Ensure each step is a map before passing to RecipeStep.fromJson
        if (stepData is Map<String, dynamic>) {
          try {
            // *** IMPORTANT: Ensure RecipeStep.fromJson is robust ***
            results.add(RecipeStep.fromJson(stepData));
          } catch (e, s) {
            if (kDebugMode) {
              print('Error parsing individual step: $e\nStack: $s\nStep data: $stepData');
            }
            // Optionally skip problematic steps or handle error differently
          }
        } else {
          if (kDebugMode) print('Skipping invalid step format: $stepData');
        }
      }
      return results;
    }

    // --- Helper: Safely parse List<String> for ingredients ---
    List<String> extractIngredients(dynamic ingredientsJson) {
      if (ingredientsJson == null || ingredientsJson is! List || ingredientsJson.isEmpty) {
        return [];
      }
      try {
        // Attempt to convert each item to String
        return ingredientsJson.map((item) => item.toString()).toList();
      } catch (e) {
        if (kDebugMode) print('Error extracting ingredients: $e');
        return []; // Return empty list on error
      }
    }

    // --- Helper: Safely parse DateTime ---
    DateTime parseCreatedAt(dynamic dateStr) {
      if (dateStr == null || dateStr is! String) return DateTime.now(); // Default to now
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        if (kDebugMode) print('Error parsing date: $dateStr - $e');
        return DateTime.now(); // Default to now on parsing error
      }
    }

    // --- Helper: Safely parse NutritionInfo ---
    // Uses the updated NutritionInfo.fromJson which expects numeric types.
    NutritionInfo parseNutrition(dynamic nutritionJson) {
      // Default NutritionInfo with numeric types (matching updated model)
      final defaultNutrition = NutritionInfo(calories: 0, protein: 0.0, fat: 0.0, carbs: 0.0);

      if (nutritionJson is Map<String, dynamic>) {
        try {
          // *** IMPORTANT: Ensure NutritionInfo.fromJson handles its fields robustly ***
          // (Should handle nulls, potential string numbers, etc., as implemented before)
          return NutritionInfo.fromJson(nutritionJson);
        } catch (e, s) {
          if (kDebugMode) {
            print('Error parsing nutrition info: $e\nStack: $s\nNutrition JSON: $nutritionJson');
          }
          return defaultNutrition; // Return default on error
        }
      }
      // Return default if nutritionJson is null or not a map
      return defaultNutrition;
    }

    // --- Extract Time Fields ---
    // Allows for flexibility if JSON keys are camelCase or snake_case
    int? prepTime = parseIntSafe(json['prepTime']) ?? parseIntSafe(json['prep_time_minutes']);
    int? cookTime = parseIntSafe(json['cookTime']) ?? parseIntSafe(json['cook_time_minutes']);
    int? totalTime = parseIntSafe(json['totalTime']) ?? parseIntSafe(json['total_time_minutes']);

    // --- Extract requestId for cancellation support ---
    String? requestId = json['requestId'] as String?;
    if (requestId != null && kDebugMode) {
      print('Extracted requestId from recipe JSON: $requestId');
    }

    // --- Extract isFavorite status ---
    bool isFavorite = json['isFavorite'] as bool? ?? false;

    // --- Construct the Recipe Object ---
    return Recipe(
      // Use `as String?` for nullable fields, providing default if necessary
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Untitled Recipe', // Provide default title
      servings: parseIntSafe(json['servings']) ?? 1, // Default to 1 serving if invalid/null
      ingredients: extractIngredients(json['ingredients']),
      steps: parseSteps(json['steps']), // Ensure RecipeStep model is robust
      nutrition: parseNutrition(json['nutrition']), // Uses the updated NutritionInfo
      query: json['query'] as String? ?? '', // Provide default query
      // Allow flexibility for createdAt key (camelCase or snake_case)
      createdAt: parseCreatedAt(json['createdAt'] ?? json['created_at']),
      // Assign parsed time fields
      prepTimeMinutes: prepTime,
      cookTimeMinutes: cookTime,
      totalTimeMinutes: totalTime,
      // Add requestId field
      requestId: requestId,
      // Add isFavorite status
      isFavorite: isFavorite,
    );
  }

  // --- Serialization to JSON ---
  // Ensure child models (RecipeStep, NutritionInfo) also have toJson methods.
  Map<String, dynamic> toJson() {
    return {
      // Only include non-null fields if desired, or let DB handle nulls
      if (id != null) 'id': id,
      'title': title,
      'servings': servings,
      'ingredients': ingredients,
      // *** IMPORTANT: Ensure RecipeStep.toJson exists ***
      'steps': steps.map((step) => step.toJson()).toList(),
      // *** Assumes NutritionInfo.toJson exists and is correct ***
      'nutrition': nutrition.toJson(),
      'query': query,
      'createdAt': createdAt.toIso8601String(), // Standard format
      // Use consistent keys (e.g., snake_case) if sending back to a DB
      // Only include if not null
      if (prepTimeMinutes != null) 'prep_time_minutes': prepTimeMinutes,
      if (cookTimeMinutes != null) 'cook_time_minutes': cookTimeMinutes,
      if (totalTimeMinutes != null) 'total_time_minutes': totalTimeMinutes,
      // Include requestId if available
      if (requestId != null) 'requestId': requestId,
      'isFavorite': isFavorite,
    };
  }
}