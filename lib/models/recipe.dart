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
  // --- FIELD FOR RECIPE THUMBNAIL ---
  final String? thumbnailUrl;
  // --- END THUMBNAIL FIELD ---


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
    this.thumbnailUrl, // <-- Added to constructor
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
    String? thumbnailUrl, // <-- ADDED
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
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl, // <-- ADDED
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // --- Helper: Safely parse double ---
    double? parseDoubleSafe(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final cleanValue = value.replaceAll(RegExp(r'[^\d.+-]'), '');
        return double.tryParse(cleanValue);
      }
      return null;
    }

    // Debug information (keep as is)
    if (kDebugMode) {
      // ... (keep debug prints) ...
      if (json.containsKey('thumbnail_url')) { // Add debug for thumbnail
        print('thumbnail_url from JSON: ${json['thumbnail_url']} (${json['thumbnail_url'].runtimeType})');
      }
    }

    // --- Helper: Safely parse nullable integer fields ---
    int? parseIntSafe(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      return null;
    }

    // --- Helper: Safely parse List<RecipeStep> ---
    List<RecipeStep> parseSteps(dynamic stepsJson) {
      // ... (keep existing implementation) ...
      if (stepsJson == null || stepsJson is! List || stepsJson.isEmpty) { return []; }
      final List<RecipeStep> results = [];
      for (var stepData in stepsJson) {
        if (stepData is Map<String, dynamic>) {
          try { results.add(RecipeStep.fromJson(stepData)); }
          catch (e, s) { if (kDebugMode) { print('Error parsing individual step: $e\nStack: $s\nStep data: $stepData'); } if (stepData.containsKey('text') && stepData['text'] is String) { results.add(RecipeStep(text: stepData['text'] as String, imageUrl: null));}}
        } else if (stepData is String) { results.add(RecipeStep(text: stepData, imageUrl: null));
        } else { if (kDebugMode) print('Skipping invalid step format: $stepData');}
      }
      // ... (keep debug prints for steps) ...
      return results;
    }

    // --- Helper: Safely parse List<String> for ingredients ---
    List<String> extractIngredients(dynamic ingredientsJson) {
      // ... (keep existing implementation) ...
      if (ingredientsJson == null) return [];
      if (ingredientsJson is! List) { if (ingredientsJson is String) { return ingredientsJson.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(); } return []; }
      if (ingredientsJson.isEmpty) return [];
      try { return ingredientsJson.map((item) => item.toString()).toList(); }
      catch (e) { if (kDebugMode) print('Error extracting ingredients: $e'); return []; }
    }

    // --- Helper: Safely parse List<String> for tags ---
    List<String>? extractTags(dynamic tagsJson) {
      // ... (keep existing implementation) ...
      if (tagsJson == null) return null;
      if (tagsJson is! List || tagsJson.isEmpty) return [];
      try { return tagsJson.map((item) => item.toString()).toList(); }
      catch (e) { if (kDebugMode) print('Error extracting tags: $e'); return []; }
    }

    // --- Helper: Safely parse DateTime ---
    DateTime parseCreatedAt(dynamic dateStr) {
      // ... (keep existing implementation) ...
      if (dateStr == null) return DateTime.now();
      if (dateStr is DateTime) return dateStr;
      if (dateStr is String) { try { return DateTime.parse(dateStr); } catch (e) { if (kDebugMode) print('Error parsing date: $dateStr - $e'); } }
      if (dateStr is int) { try { return DateTime.fromMillisecondsSinceEpoch(dateStr * 1000); } catch (e) { if (kDebugMode) print('Error parsing timestamp: $dateStr - $e'); } }
      return DateTime.now();
    }

    // --- Helper: Safely parse NutritionInfo ---
    NutritionInfo parseNutrition(dynamic nutritionJson) {
      // ... (keep existing implementation) ...
      final defaultNutrition = NutritionInfo(calories: 0, protein: 0.0, fat: 0.0, carbs: 0.0);
      if (nutritionJson == null || nutritionJson is! Map<String, dynamic>) { if (kDebugMode) print('Nutrition info not a Map: ${nutritionJson.runtimeType}'); return defaultNutrition; }
      try { return NutritionInfo.fromJson(nutritionJson); }
      catch (e, s) {
        if (kDebugMode) { print('Error parsing nutrition info: $e\nStack: $s\nNutrition JSON: $nutritionJson'); }
        try { return NutritionInfo(calories: parseIntSafe(nutritionJson['calories']) ?? 0, protein: parseDoubleSafe(nutritionJson['protein']) ?? 0.0, fat: parseDoubleSafe(nutritionJson['fat']) ?? 0.0, carbs: parseDoubleSafe(nutritionJson['carbs']) ?? 0.0); }
        catch (fallbackError) { if (kDebugMode) print('Fallback nutrition extraction failed: $fallbackError'); return defaultNutrition; }
      }
    }

    // --- Extract Standard Fields ---
    int? prepTime = parseIntSafe(json['prepTime']) ?? parseIntSafe(json['prep_time_minutes']);
    int? cookTime = parseIntSafe(json['cookTime']) ?? parseIntSafe(json['cook_time_minutes']);
    int? totalTime = parseIntSafe(json['totalTime']) ?? parseIntSafe(json['total_time_minutes']);
    String? requestId = json['requestId'] as String?;
    bool isFavorite = json['isFavorite'] == true;
    String? category = json['category'] as String?;
    List<String>? tags = extractTags(json['tags']);
    int? views = parseIntSafe(json['views']);
    double? qualityScore = parseDoubleSafe(json['quality_score']);
    double? progress;
    if (json.containsKey('progress')) {
      final rawProgress = json['progress'];
      if (rawProgress is num) { progress = rawProgress.toDouble() / 100.0; }
      else if (rawProgress is String) { final parsed = double.tryParse(rawProgress); if (parsed != null) progress = parsed / 100.0; }
    }
    final status = json['status'];
    bool isPartial = json['isPartial'] == true || (status != null && (status == 'active' || status == 'waiting'));

    // --- ADDED: Extract thumbnail_url ---
    String? thumbnailUrl = json['thumbnail_url'] as String?;
    // --- END ADDED ---

    // --- Construct the Recipe Object ---
    return Recipe(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Untitled Recipe',
      servings: parseIntSafe(json['servings']) ?? 1,
      ingredients: extractIngredients(json['ingredients']),
      steps: parseSteps(json['steps']),
      nutrition: parseNutrition(json['nutrition']),
      query: json['query'] as String? ?? '',
      createdAt: parseCreatedAt(json['createdAt'] ?? json['created_at']),
      prepTimeMinutes: prepTime,
      cookTimeMinutes: cookTime,
      totalTimeMinutes: totalTime,
      requestId: requestId,
      isFavorite: isFavorite,
      category: category,
      tags: tags,
      views: views,
      qualityScore: qualityScore,
      progress: progress,
      isPartial: isPartial,
      thumbnailUrl: thumbnailUrl, // <-- Pass the extracted URL
    );
  }

  // --- Serialization to JSON ---
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'servings': servings,
      'ingredients': ingredients,
      // Assume RecipeStep.toJson exists
      'steps': steps.map((step) => step.toJson()).toList(),
      // Assume NutritionInfo.toJson exists
      'nutrition': nutrition.toJson(),
      'query': query,
      'createdAt': createdAt.toIso8601String(),
      if (prepTimeMinutes != null) 'prep_time_minutes': prepTimeMinutes,
      if (cookTimeMinutes != null) 'cook_time_minutes': cookTimeMinutes,
      if (totalTimeMinutes != null) 'total_time_minutes': totalTimeMinutes,
      if (requestId != null) 'requestId': requestId,
      'isFavorite': isFavorite,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      if (views != null) 'views': views,
      if (qualityScore != null) 'quality_score': qualityScore,
      if (progress != null) 'progress': ((progress ?? 0) * 100).round(),
      'isPartial': isPartial,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl, // <-- ADDED
    };
  }
}