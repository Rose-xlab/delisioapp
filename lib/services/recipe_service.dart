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

    final response = await client.post(
      Uri.parse('$baseUrl${ApiConfig.recipes}'),
      headers: headers,
      body: json.encode({
        'query': query,
        'save': save,
      }),
    );

    if (response.statusCode == 200) {
      return Recipe.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error']['message'] ?? 'Failed to generate recipe');
    }
  }

  // Get all recipes for current user
  Future<List<Recipe>> getUserRecipes(String token) async {
    final response = await client.get(
      Uri.parse('$baseUrl${ApiConfig.userRecipes}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return (responseData['recipes'] as List)
          .map((recipeJson) => Recipe.fromJson(recipeJson))
          .toList();
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error']['message'] ?? 'Failed to get recipes');
    }
  }

  // Get a specific recipe by ID
  Future<Recipe> getRecipeById(String id, String token) async {
    final response = await client.get(
      Uri.parse('$baseUrl${ApiConfig.userRecipes}/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return Recipe.fromJson(responseData['recipe']);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error']['message'] ?? 'Failed to get recipe');
    }
  }
}