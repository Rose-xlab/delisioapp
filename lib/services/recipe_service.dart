// services/recipe_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/recipe.dart';

class RecipeService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

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

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
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
        final responseData = json.decode(response.body);
        return (responseData['recipes'] as List)
            .map((recipeJson) => Recipe.fromJson(recipeJson))
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
        Uri.parse('$baseUrl${ApiConfig.userRecipes}/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('getRecipeById response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Recipe.fromJson(responseData['recipe']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get recipe');
      }
    } catch (e) {
      print('Error in getRecipeById: $e');
      rethrow;
    }
  }
}