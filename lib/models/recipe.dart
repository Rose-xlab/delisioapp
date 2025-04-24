// lib/models/recipe.dart
import 'package:flutter/foundation.dart'; // For kDebugMode print
import 'dart:math';

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
  // NEW: Add category and tags fields
  final String? category;
  final List<String>? tags;
  // NEW: Add popularity metrics
  final int? views;
  final double? qualityScore;
  // NEW: Add progress for partial recipes
  final double? progress;
  // NEW: Add isPartial flag for progressive display
  final bool isPartial;

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
    this.category, // NEW: Category field
    this.tags, // NEW: Tags field
    this.views, // NEW: View count
    this.qualityScore, // NEW: Quality score
    this.progress, // NEW: Progress percentage
    this.isPartial = false, // NEW: Flag for partial recipes
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
    String? category,
    List<String>? tags,
    int? views,
    double? qualityScore,
    double? progress,
    bool? isPartial,
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
      category: category ?? this.category,
      tags: tags ?? this.tags,
      views: views ?? this.views,
      qualityScore: qualityScore ?? this.qualityScore,
      progress: progress ?? this.progress,
      isPartial: isPartial ?? this.isPartial,
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // --- Helper: Safely parse double ---
    // MOVED THIS FUNCTION EARLIER to fix "can't be referenced before it is declared" errors
    double? parseDoubleSafe(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        // Remove any 'g' or other unit indicators
        final cleanValue = value.replaceAll(RegExp(r'[^\d.+-]'), '');
        return double.tryParse(cleanValue);
      }
      return null;
    }

    // Debug information to help diagnose issues
    if (kDebugMode) {
      print('--- Parsing Recipe ---');
      print('JSON Keys: ${json.keys.toList()}');

      // Log key time fields
      if (json.containsKey('prep_time_minutes')) {
        print('prep_time_minutes: ${json['prep_time_minutes']} (${json['prep_time_minutes'].runtimeType})');
      }
      if (json.containsKey('prepTime')) {
        print('prepTime: ${json['prepTime']} (${json['prepTime'].runtimeType})');
      }

      // Log partial recipe info
      if (json.containsKey('progress')) {
        print('progress: ${json['progress']} (${json['progress'].runtimeType})');
      }
      if (json.containsKey('isPartial')) {
        print('isPartial: ${json['isPartial']}');
      }
      if (json.containsKey('status')) {
        print('status: ${json['status']}');
      }
    }

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
            // Check for image_url key specifically
            if (kDebugMode) {
              print('Processing step with keys: ${stepData.keys.toList()}');
              if (stepData.containsKey('image_url')) {
                print('Found image_url: ${stepData['image_url']}');
              }
            }

            results.add(RecipeStep.fromJson(stepData));
          } catch (e, s) {
            if (kDebugMode) {
              print('Error parsing individual step: $e\nStack: $s\nStep data: $stepData');
            }
            // Create a basic step with available text
            if (stepData.containsKey('text') && stepData['text'] is String) {
              results.add(RecipeStep(
                text: stepData['text'] as String,
                imageUrl: null,
              ));
            }
          }
        } else if (stepData is String) {
          // Handle case where step might just be a string
          results.add(RecipeStep(text: stepData, imageUrl: null));
        } else {
          if (kDebugMode) print('Skipping invalid step format: $stepData');
        }
      }

      // Debug output to verify steps have their images
      if (kDebugMode && results.isNotEmpty) {
        print('Parsed ${results.length} steps:');
        for (int i = 0; i < results.length; i++) {
          print('Step ${i+1}: ${results[i].text.substring(0, min(20, results[i].text.length))}... - Has image: ${results[i].imageUrl != null}');
          if (results[i].imageUrl != null) {
            print('  Image URL: ${results[i].imageUrl}');
          }
        }
      }

      return results;
    }

    // --- Helper: Safely parse List<String> for ingredients ---
    List<String> extractIngredients(dynamic ingredientsJson) {
      if (ingredientsJson == null) return [];

      if (ingredientsJson is! List) {
        // Try to handle string case (e.g., comma-separated)
        if (ingredientsJson is String) {
          return ingredientsJson.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
        return [];
      }

      if (ingredientsJson.isEmpty) return [];

      try {
        // Attempt to convert each item to String
        return ingredientsJson.map((item) => item.toString()).toList();
      } catch (e) {
        if (kDebugMode) print('Error extracting ingredients: $e');
        return []; // Return empty list on error
      }
    }

    // --- Helper: Safely parse List<String> for tags ---
    List<String>? extractTags(dynamic tagsJson) {
      if (tagsJson == null) return null;
      if (tagsJson is! List || tagsJson.isEmpty) return [];

      try {
        // Attempt to convert each item to String
        return tagsJson.map((item) => item.toString()).toList();
      } catch (e) {
        if (kDebugMode) print('Error extracting tags: $e');
        return []; // Return empty list on error
      }
    }

    // --- Helper: Safely parse DateTime ---
    DateTime parseCreatedAt(dynamic dateStr) {
      if (dateStr == null) return DateTime.now(); // Default to now

      if (dateStr is DateTime) return dateStr;

      if (dateStr is String) {
        try {
          return DateTime.parse(dateStr);
        } catch (e) {
          if (kDebugMode) print('Error parsing date: $dateStr - $e');
        }
      }

      if (dateStr is int) {
        try {
          // Handle Unix timestamp (seconds)
          return DateTime.fromMillisecondsSinceEpoch(dateStr * 1000);
        } catch (e) {
          if (kDebugMode) print('Error parsing timestamp: $dateStr - $e');
        }
      }

      return DateTime.now(); // Default to now on parsing error
    }

    // --- Helper: Safely parse NutritionInfo ---
    NutritionInfo parseNutrition(dynamic nutritionJson) {
      // Default nutrition with zeros
      final defaultNutrition = NutritionInfo(calories: 0, protein: 0.0, fat: 0.0, carbs: 0.0);

      // If null or not an object, return default
      if (nutritionJson == null) return defaultNutrition;
      if (nutritionJson is! Map<String, dynamic>) {
        if (kDebugMode) print('Nutrition info not a Map: ${nutritionJson.runtimeType}');
        return defaultNutrition;
      }

      try {
        return NutritionInfo.fromJson(nutritionJson);
      } catch (e, s) {
        if (kDebugMode) {
          print('Error parsing nutrition info: $e\nStack: $s\nNutrition JSON: $nutritionJson');
        }

        // Try to extract individual fields if regular parsing fails
        try {
          return NutritionInfo(
            calories: parseIntSafe(nutritionJson['calories']) ?? 0,
            protein: parseDoubleSafe(nutritionJson['protein']) ?? 0.0,
            fat: parseDoubleSafe(nutritionJson['fat']) ?? 0.0,
            carbs: parseDoubleSafe(nutritionJson['carbs']) ?? 0.0,
          );
        } catch (fallbackError) {
          if (kDebugMode) print('Fallback nutrition extraction failed: $fallbackError');
          return defaultNutrition;
        }
      }
    }

    // --- Extract Time Fields ---
    // Allows for flexibility if JSON keys are camelCase or snake_case
    int? prepTime = parseIntSafe(json['prepTime']) ?? parseIntSafe(json['prep_time_minutes']);
    int? cookTime = parseIntSafe(json['cookTime']) ?? parseIntSafe(json['cook_time_minutes']);
    int? totalTime = parseIntSafe(json['totalTime']) ?? parseIntSafe(json['total_time_minutes']);

    // --- Extract requestId for cancellation support ---
    String? requestId = json['requestId'] as String?;

    // --- Extract isFavorite status ---
    bool isFavorite = json['isFavorite'] == true;

    // --- Extract category and tags ---
    String? category = json['category'] as String?;
    List<String>? tags = extractTags(json['tags']);

    // --- Extract views and quality score ---
    int? views = parseIntSafe(json['views']);
    double? qualityScore = parseDoubleSafe(json['quality_score']);

    // --- Extract progress and partial status for progressive display ---
    double? progress;
    if (json.containsKey('progress')) {
      final rawProgress = json['progress'];
      if (rawProgress is num) {
        progress = rawProgress.toDouble() / 100.0; // Convert percentage to 0.0-1.0
      } else if (rawProgress is String) {
        final parsed = double.tryParse(rawProgress);
        if (parsed != null) progress = parsed / 100.0;
      }
    }

    // Check if this is a partial recipe - FIX for null check error
    final status = json['status'];
    bool isPartial = json['isPartial'] == true ||
        (status != null && (status == 'active' || status == 'waiting'));

    // --- Construct the Recipe Object ---
    return Recipe(
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
      // Add category and tags
      category: category,
      tags: tags,
      // Add popularity metrics
      views: views,
      qualityScore: qualityScore,
      // Add progress and partial status
      progress: progress,
      isPartial: isPartial,
    );
  }

  // --- Serialization to JSON ---
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
      // Include category and tags if available
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      // Include popularity metrics if available
      if (views != null) 'views': views,
      if (qualityScore != null) 'quality_score': qualityScore,
      // Include progress info if available
      // FIX: Fixed null safety issue with multiplication operator
      if (progress != null) 'progress': ((progress ?? 0) * 100).round(), // Convert back to percentage with null safety
      'isPartial': isPartial,
    };
  }
}