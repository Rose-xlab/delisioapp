// lib/services/recipe_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart'; // Import for sharing functionality
import '../config/api_config.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';
import '../models/nutrition_info.dart';

class RecipeService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  // Track current recipe generation requestId
  String? _currentRequestId;

  // Getter for current request ID
  String? get currentRequestId => _currentRequestId;

  // Generate a new recipe
  Future<Recipe> generateRecipe(String query, {bool save = false, String? token}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    // Add auth token if provided
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      print('Sending recipe generation request for: $query');
      print('API endpoint: $baseUrl${ApiConfig.recipes}');
      print('Request headers: $headers');

      final requestBody = {
        'query': query,
        'save': save,
      };
      print('Request body: $requestBody');

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.recipes}'),
        headers: headers,
        body: json.encode(requestBody),
      );

      print('Recipe API response code: ${response.statusCode}');

      // Handle cancellation response
      if (response.statusCode == 499) {
        print('Recipe generation was cancelled by the server');
        throw Exception('Recipe generation was cancelled');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Store the requestId for potential cancellation
        _currentRequestId = responseData['requestId'] as String?;
        print('Stored requestId for cancellation: $_currentRequestId');

        // ADD DETAILED LOGGING TO SEE RAW TIME FIELDS
        print('Raw recipe response data: $responseData');
        print('Time fields in response:');
        print('- prepTime: ${responseData['prepTime']}');
        print('- cookTime: ${responseData['cookTime']}');
        print('- totalTime: ${responseData['totalTime']}');
        print('- prep_time_minutes: ${responseData['prep_time_minutes']}');
        print('- cook_time_minutes: ${responseData['cook_time_minutes']}');
        print('- total_time_minutes: ${responseData['total_time_minutes']}');

        print('Recipe generation successful. Recipe title: ${responseData['title']}');

        // Log the structure of steps and images for debugging
        if (responseData['steps'] != null) {
          print('Recipe contains ${responseData['steps'].length} steps');
          for (var i = 0; i < responseData['steps'].length; i++) {
            final step = responseData['steps'][i];
            print('Step ${i+1} image URL: ${step['image_url'] ?? 'none'}');
          }
        }

        return Recipe.fromJson(responseData);
      } else {
        // Log detailed error information
        print('Error response body: ${response.body}');
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Failed to generate recipe';
        print('Error message: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in generateRecipe: $e');
      rethrow;
    }
  }

  // Cancel current recipe generation
  Future<bool> cancelRecipeGeneration() async {
    if (_currentRequestId == null) {
      print('No active recipe generation to cancel');
      return false;
    }

    try {
      print('Sending cancellation request for requestId: $_currentRequestId');

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.recipes}/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'requestId': _currentRequestId}),
      );

      print('Cancel API response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final success = responseData['success'] as bool? ?? false;

        print('Cancellation request ${success ? 'successful' : 'failed'}: ${responseData['message']}');

        // Clear the requestId if cancellation was successful
        if (success) {
          _currentRequestId = null;
        }

        return success;
      } else {
        print('Error response from cancel API: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error in cancelRecipeGeneration: $e');
      return false;
    }
  }

  // Get all recipes for current user
  Future<List<Recipe>> getUserRecipes(String token) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.userRecipes}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('getUserRecipes response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Add logging for time fields in the first recipe (if available)
        if (responseData['recipes'] is List && responseData['recipes'].isNotEmpty) {
          final firstRecipe = responseData['recipes'][0];
          print('Sample recipe time fields from list:');
          print('- prep_time_minutes: ${firstRecipe['prep_time_minutes']}');
          print('- cook_time_minutes: ${firstRecipe['cook_time_minutes']}');
          print('- total_time_minutes: ${firstRecipe['total_time_minutes']}');
        }

        final List<dynamic> recipesList = responseData['recipes'];
        return recipesList
            .map((recipeJson) => Recipe.fromJson(Map<String, dynamic>.from(recipeJson)))
            .toList();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get recipes');
      }
    } catch (e) {
      print('Error in getUserRecipes: $e');
      rethrow;
    }
  }

  // Get a specific recipe by ID
  Future<Recipe> getRecipeById(String id, String token) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.recipeById(id)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('getRecipeById response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Check if the recipe is a favorite
        final bool isFavorite = responseData['isFavorite'] ?? false;

        // Add logging for time fields
        final Map<String, dynamic> recipeData = responseData['recipe'];
        print('Recipe by ID time fields:');
        print('- prep_time_minutes: ${recipeData['prep_time_minutes']}');
        print('- cook_time_minutes: ${recipeData['cook_time_minutes']}');
        print('- total_time_minutes: ${recipeData['total_time_minutes']}');

        // Create the recipe object
        final recipe = Recipe.fromJson(recipeData);

        // Return a new recipe with the favorite status (potentially adding this to Recipe model)
        return recipe;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get recipe');
      }
    } catch (e) {
      print('Error in getRecipeById: $e');
      rethrow;
    }
  }

  // Delete a recipe
  Future<bool> deleteRecipe(String recipeId, String token) async {
    try {
      print('Deleting recipe: $recipeId');

      final response = await client.delete(
        Uri.parse('$baseUrl${ApiConfig.recipeById(recipeId)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Delete recipe response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Recipe deleted successfully');
        return true;
      } else {
        print('Error response from delete API: ${response.body}');
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete recipe');
      }
    } catch (e) {
      print('Error in deleteRecipe: $e');
      rethrow;
    }
  }

  // Add a recipe to favorites
  Future<bool> addToFavorites(String recipeId, String token) async {
    try {
      print('Adding recipe to favorites: $recipeId');

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.favoriteRecipe(recipeId)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Add to favorites response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Recipe added to favorites successfully');
        return true;
      } else {
        print('Error response from favorites API: ${response.body}');
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to add recipe to favorites');
      }
    } catch (e) {
      print('Error in addToFavorites: $e');
      rethrow;
    }
  }

  // Remove a recipe from favorites
  Future<bool> removeFromFavorites(String recipeId, String token) async {
    try {
      print('Removing recipe from favorites: $recipeId');

      final response = await client.delete(
        Uri.parse('$baseUrl${ApiConfig.favoriteRecipe(recipeId)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Remove from favorites response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Recipe removed from favorites successfully');
        return true;
      } else {
        print('Error response from favorites API: ${response.body}');
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to remove recipe from favorites');
      }
    } catch (e) {
      print('Error in removeFromFavorites: $e');
      rethrow;
    }
  }

  // Get all favorite recipes
  Future<List<Recipe>> getFavoriteRecipes(String token) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.recipesFavorites}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('getFavoriteRecipes response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> recipesList = responseData['recipes'];
        return recipesList
            .map((recipeJson) => Recipe.fromJson(Map<String, dynamic>.from(recipeJson)))
            .toList();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get favorite recipes');
      }
    } catch (e) {
      print('Error in getFavoriteRecipes: $e');
      rethrow;
    }
  }

  // Share a recipe
  Future<void> shareRecipe(Recipe recipe) async {
    try {
      // Create a formatted text representation of the recipe
      final StringBuilder recipeText = StringBuilder();

      recipeText.appendLine('🍳 ${recipe.title.toUpperCase()}');
      recipeText.appendLine('');

      if (recipe.prepTimeMinutes != null || recipe.cookTimeMinutes != null || recipe.totalTimeMinutes != null) {
        recipeText.appendLine('⏱️ Time Info:');
        if (recipe.prepTimeMinutes != null) {
          recipeText.appendLine('  Prep: ${recipe.prepTimeMinutes} min');
        }
        if (recipe.cookTimeMinutes != null) {
          recipeText.appendLine('  Cook: ${recipe.cookTimeMinutes} min');
        }
        if (recipe.totalTimeMinutes != null) {
          recipeText.appendLine('  Total: ${recipe.totalTimeMinutes} min');
        }
        recipeText.appendLine('');
      }

      recipeText.appendLine('👥 Serves: ${recipe.servings}');
      recipeText.appendLine('');

      recipeText.appendLine('🛒 Ingredients:');
      for (final ingredient in recipe.ingredients) {
        recipeText.appendLine('  • $ingredient');
      }
      recipeText.appendLine('');

      recipeText.appendLine('📝 Instructions:');
      for (int i = 0; i < recipe.steps.length; i++) {
        recipeText.appendLine('  ${i+1}. ${recipe.steps[i].text}');
      }
      recipeText.appendLine('');

      recipeText.appendLine('🥗 Nutrition (per serving):');
      recipeText.appendLine('  • Calories: ${recipe.nutrition.calories}');
      recipeText.appendLine('  • Protein: ${recipe.nutrition.protein}');
      recipeText.appendLine('  • Fat: ${recipe.nutrition.fat}');
      recipeText.appendLine('  • Carbs: ${recipe.nutrition.carbs}');
      recipeText.appendLine('');

      recipeText.appendLine('Generated by Delisio Cooking Assistant');

      // Share the text
      await Share.share(recipeText.toString(), subject: 'Check out this recipe: ${recipe.title}');

    } catch (e) {
      print('Error in shareRecipe: $e');
      rethrow;
    }
  }
}

// Helper class for building multi-line strings
class StringBuilder {
  final StringBuffer _buffer = StringBuffer();

  void appendLine(String line) {
    _buffer.writeln(line);
  }

  @override
  String toString() {
    return _buffer.toString();
  }
}