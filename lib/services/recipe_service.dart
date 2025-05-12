// lib/services/recipe_service.dart - with enhanced status checking and error handling
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../config/api_config.dart';
import '../models/recipe.dart';
import 'dart:async';

class RecipeService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  // Cache of completed and partial recipes to reduce status check requests
  final Map<String, dynamic> _recipeStatusCache = {};

  // Track current recipe generation requestId
  String? _currentRequestId;

  // Getter for current request ID
  String? get currentRequestId => _currentRequestId;

  // Check if backend is using queues
  Future<bool> isUsingQueue() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.recipes}/queue-status'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Queue status API response: ${responseData['isQueueActive']}');
        return responseData['isQueueActive'] == true;
      } else {
        // If endpoint doesn't exist, assume no queue
        print('Queue status API returned non-200 status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      // If error, assume no queue
      print('Error checking queue status: $e');
      return false;
    }
  }

  // Start recipe generation (for queue-based generation)
  Future<Map<String, dynamic>> startRecipeGeneration(String query, {bool save = false, String? token}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    // Add auth token if provided
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      print('Starting recipe generation request for: $query');

      final requestBody = {
        'query': query,
        'save': save,
      };

      // Start the recipe generation process
      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.recipes}'),
        headers: headers,
        body: json.encode(requestBody),
      );

      print('Recipe API response code: ${response.statusCode}');

      if (response.statusCode == 202) {
        // Queue-based response (async)
        final Map<String, dynamic> responseData = json.decode(response.body);
        _currentRequestId = responseData['requestId'] as String?;
        print('Received requestId for polling: $_currentRequestId');

        if (_currentRequestId == null) {
          throw Exception('No requestId received for recipe generation');
        }

        // Clear previous cache for this requestId if it exists
        _recipeStatusCache.remove(_currentRequestId);

        return responseData;
      } else if (response.statusCode == 200) {
        // Direct response - backend might not be using queue despite what it reported
        print('Warning: Expected 202 but got 200 - server might not be using queues as expected');

        final Map<String, dynamic> responseData = json.decode(response.body);

        // Create a fake requestId to track this "direct" response
        final String fakeRequestId = 'direct-${DateTime.now().millisecondsSinceEpoch}';
        _currentRequestId = fakeRequestId;

        // Add to cache
        _recipeStatusCache[fakeRequestId] = {
          'status': 'completed',
          'progress': 100,
          ...responseData
        };

        // Return a structure that the polling system can understand
        return {
          'requestId': fakeRequestId,
          'status': 'completed',
          'message': 'Recipe generated directly',
          // Store the complete recipe to return immediately on first poll
          'recipe': responseData
        };
      } else {
        // Handle error
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error']?['message'] ??
              errorData['message'] ??
              'Failed to start recipe generation (status: ${response.statusCode})';
        } catch (parseError) {
          errorMessage = 'Failed to start recipe generation (status: ${response.statusCode})';
        }

        print('Error response: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in startRecipeGeneration: $e');
      rethrow;
    }
  }

  // Improved check recipe generation status with caching
  Future<Map<String, dynamic>> checkRecipeStatus(String requestId) async {
    try {
      // First check our local cache - if we already know it's completed
      if (_recipeStatusCache.containsKey(requestId)) {
        print('Using cached recipe status for requestId: $requestId');
        return _recipeStatusCache[requestId];
      }

      print('Checking recipe status for requestId: $requestId');

      // Handle our fake "direct" requestIds from startRecipeGeneration
      if (requestId.startsWith('direct-')) {
        print('This is a direct response (non-queued) with fake requestId');
        // Return cached data if available
        if (_recipeStatusCache.containsKey(requestId)) {
          return _recipeStatusCache[requestId];
        }
        // Return empty map to signal that polling should stop
        return {};
      }

      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.recipes}/status/$requestId'),
      );

      print('Status check response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('Status check response data: ${responseData.keys}');

        // Check if this is a complete recipe (no status field, but has recipe data)
        if (responseData['status'] == null &&
            (responseData['title'] != null || responseData['id'] != null)) {
          print('Recipe is complete! Title: ${responseData['title']}');

          // Cache the completed recipe
          _recipeStatusCache[requestId] = responseData;

          return responseData; // This is the complete recipe
        }
        else if (responseData['status'] != null) {
          // Still processing - return status info
          print('Recipe still processing: ${responseData['status']}, progress: ${responseData['progress']}%');

          // Check if there's a partial recipe
          if (responseData.containsKey('partialRecipe')) {
            print('Partial recipe data received');

            // Basic validation on the partial recipe
            final partialRecipe = responseData['partialRecipe'];
            if (partialRecipe != null) {
              if (partialRecipe is Map<String, dynamic>) {
                if (partialRecipe.containsKey('title')) {
                  print('Partial title: ${partialRecipe['title']}');
                }
                if (partialRecipe.containsKey('steps')) {
                  final steps = partialRecipe['steps'];
                  if (steps is List) {
                    print('Partial recipe has ${steps.length} steps');
                  }
                }
              } else {
                print('Warning: partialRecipe is not a Map: ${partialRecipe.runtimeType}');
                responseData['partialRecipe'] = null;
              }
            }
          }

          // If progress is 100 but status is not "completed", cache this
          // This helps prevent further unnecessary status checks
          if (responseData['progress'] == 100) {
            _recipeStatusCache[requestId] = responseData;
          } else if (responseData['progress'] > 80) {
            // For high progress, cache briefly to reduce API calls
            _recipeStatusCache[requestId] = responseData;

            // Remove from cache after 30 seconds to force a refresh
            Future.delayed(const Duration(seconds: 30), () {
              _recipeStatusCache.remove(requestId);
            });
          }

          return responseData;
        } else {
          // Unexpected response format
          print('Unexpected response format: $responseData');
          return responseData; // Return whatever we got
        }
      } else if (response.statusCode == 499) {
        // Cancelled - cache this so we don't check again
        _recipeStatusCache[requestId] = {
          'status': 'cancelled',
          'message': 'Recipe generation was cancelled',
          'progress': 100
        };
        print('Recipe generation was cancelled (499)');
        throw Exception('Recipe generation was cancelled');
      } else if (response.statusCode == 404) {
        // Not found
        print('Recipe job not found (404)');
        throw Exception('Recipe generation job not found');
      } else if (response.statusCode == 429) {
        // Rate limit - use cache with current progress if available
        print('Rate limited (429)');

        // If we have partial progress in cache, return that instead of failing
        if (_recipeStatusCache.containsKey(requestId)) {
          print('Using cached data while rate limited');
          return _recipeStatusCache[requestId];
        }

        throw Exception('Too many status check requests. Please wait and try again.');
      } else {
        // Other error
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error']?['message'] ??
              errorData['message'] ??
              'Failed to check recipe status (${response.statusCode})';
        } catch (parseError) {
          errorMessage = 'Failed to check recipe status (${response.statusCode})';
        }

        print('Error response: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error checking recipe status: $e');
      rethrow;
    }
  }

  // Cache a partial recipe result (can be called from provider)
  void cachePartialRecipe(String requestId, Map<String, dynamic> data) {
    if (requestId.isNotEmpty) {
      _recipeStatusCache[requestId] = {
        'status': 'processing',
        'progress': data['progress'] ?? 50,
        'partialRecipe': data,
      };

      // Remove from cache after 60 seconds to force a refresh
      Future.delayed(const Duration(seconds: 60), () {
        if (_recipeStatusCache.containsKey(requestId) &&
            _recipeStatusCache[requestId]['status'] == 'processing') {
          _recipeStatusCache.remove(requestId);
        }
      });
    }
  }

  // Generate a new recipe (non-queue method)
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

      final requestBody = {
        'query': query,
        'save': save,
      };

      // Start the recipe generation process
      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.recipes}'),
        headers: headers,
        body: json.encode(requestBody),
      );

      print('Recipe API response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Direct response (legacy mode)
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('Recipe generation successful (direct mode)');

        try {
          return Recipe.fromJson(responseData);
        } catch (parseError) {
          print('Error parsing recipe: $parseError');
          throw Exception('Failed to parse recipe response: $parseError');
        }
      } else if (response.statusCode == 202) {
        // We got a 202 (queued) response but we're in the direct path
        // This could happen if the backend unexpectedly uses the queue
        print('Warning: Got 202 Accepted in direct recipe generation path');
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String? requestId = responseData['requestId'] as String?;

        if (requestId != null) {
          throw Exception('Recipe generation was queued. Please use startRecipeGeneration instead. RequestId: $requestId');
        } else {
          throw Exception('Recipe generation was queued but no request ID was provided');
        }
      } else {
        // Handle error
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error']?['message'] ??
              errorData['message'] ??
              'Failed to generate recipe (status: ${response.statusCode})';
        } catch (parseError) {
          errorMessage = 'Failed to generate recipe (status: ${response.statusCode})';
        }

        print('Error response: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in generateRecipe: $e');
      rethrow;
    }
  }

  // Cancel recipe generation with improved error handling
  Future<bool> cancelRecipeGeneration(String requestId) async {
    try {
      print('Sending cancellation request for requestId: $requestId');

      // Immediately return success for direct request IDs (they're already "complete")
      if (requestId.startsWith('direct-')) {
        print('This is a fake direct requestId, no need to cancel');
        return true;
      }

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.cancelRecipe}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'requestId': requestId}),
      );

      print('Cancel API response code: ${response.statusCode}');
      print('Cancel API response body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData;
        try {
          responseData = json.decode(response.body);
        } catch (e) {
          print('Error parsing cancel response: $e');
          return false;
        }

        final success = responseData['success'] == true;
        print('Cancellation request ${success ? 'successful' : 'failed'}: ${responseData['message'] ?? 'No message'}');

        // Clear the requestId if cancellation was successful
        if (success && requestId == _currentRequestId) {
          _currentRequestId = null;
        }

        // Add to cache to indicate cancelled status
        _recipeStatusCache[requestId] = {
          'status': 'cancelled',
          'message': 'Recipe generation was cancelled',
          'progress': 100
        };

        return success;
      } else if (response.statusCode == 404) {
        // Recipe may have already completed or not found
        print('Recipe job not found for cancellation (404) - may have already completed');
        return true; // Consider this a success - nothing to cancel
      } else {
        print('Error response from cancel API: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error in cancelRecipeGeneration: $e');
      return false;
    }
  }

  // Clean cache entries
  void cleanCache() {
    // Remove entries older than 2 hours
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _recipeStatusCache.forEach((key, value) {
      final timestamp = value['timestamp'] as DateTime?;
      if (timestamp != null && now.difference(timestamp).inHours > 2) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _recipeStatusCache.remove(key);
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
        final bool isFavorite = responseData['isFavorite'] ?? false;
        final Map<String, dynamic> recipeData = responseData['recipe'];

        try {
          final recipe = Recipe.fromJson(recipeData);
          return recipe.copyWith(isFavorite: isFavorite);
        } catch (parseError) {
          print('Error parsing recipe: $parseError');
          throw Exception('Failed to parse recipe data: $parseError');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Recipe not found');
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
      } else if (response.statusCode == 404) {
        throw Exception('Recipe not found');
      } else if (response.statusCode == 403) {
        throw Exception('Not authorized to delete this recipe');
      } else {
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
      } else if (response.statusCode == 404) {
        throw Exception('Recipe not found');
      } else {
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
      } else if (response.statusCode == 404) {
        print('Recipe not found in favorites (404)');
        return true; // Already not a favorite
      } else {
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

      recipeText.appendLine('Generated by Kitchen Assistant');

      // Share the text
      await Share.share(recipeText.toString(), subject: 'Check out this recipe: ${recipe.title}');

    } catch (e) {
      print('Error in shareRecipe: $e');
      rethrow;
    }
  }

  // Get recipes for discovery
  Future<List<Recipe>> getDiscoverRecipes({
    String? category,
    List<String>? tags,
    String sort = 'recent',
    int limit = 20,
    int offset = 0,
    String? token,
    String? query,
  }) async {
    try {
      // Build query parameters
      final Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort': sort,
      };

      if (category != null && category.toLowerCase() != 'all') {
        queryParams['category'] = category;
      }

      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags.join(',');
      }

      if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
      }

      final headers = {
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$baseUrl${ApiConfig.recipes}/discover').replace(
        queryParameters: queryParams,
      );

      print('Fetching discover recipes: $uri');

      final response = await client.get(uri, headers: headers);

      print('getDiscoverRecipes response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> recipesList = responseData['recipes'];

        if (recipesList.isEmpty) {
          print('No recipes found matching the criteria');
          return [];
        }

        print('Found ${recipesList.length} recipes');

        return recipesList
            .map((recipeJson) => Recipe.fromJson(Map<String, dynamic>.from(recipeJson)))
            .toList();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get discover recipes');
      }
    } catch (e) {
      print('Error in getDiscoverRecipes: $e');
      rethrow;
    }
  }

  // Get popular recipes
  Future<List<Recipe>> getPopularRecipes({
    int limit = 5,
    String? token,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$baseUrl${ApiConfig.recipes}/popular?limit=$limit');

      print('Fetching popular recipes: $uri');

      final response = await client.get(uri, headers: headers);

      print('getPopularRecipes response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> recipesList = responseData['recipes'];

        if (recipesList.isEmpty) {
          print('No popular recipes found');
          return [];
        }

        print('Found ${recipesList.length} popular recipes');

        return recipesList
            .map((recipeJson) => Recipe.fromJson(Map<String, dynamic>.from(recipeJson)))
            .toList();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get popular recipes');
      }
    } catch (e) {
      print('Error in getPopularRecipes: $e');
      rethrow;
    }
  }

  // Get recipes by category
  Future<List<Recipe>> getCategoryRecipes(
      String categoryId, {
        String sort = 'recent',
        int limit = 20,
        int offset = 0,
        String? token,
      }) async {
    try {
      // Build query parameters
      final Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort': sort,
      };

      final headers = {
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$baseUrl${ApiConfig.recipes}/category/$categoryId').replace(
        queryParameters: queryParams,
      );

      print('Fetching category recipes: $uri');

      final response = await client.get(uri, headers: headers);

      print('getCategoryRecipes response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> recipesList = responseData['recipes'];

        if (recipesList.isEmpty) {
          print('No recipes found in category $categoryId');
          return [];
        }

        print('Found ${recipesList.length} recipes in category $categoryId');

        return recipesList
            .map((recipeJson) => Recipe.fromJson(Map<String, dynamic>.from(recipeJson)))
            .toList();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get category recipes');
      }
    } catch (e) {
      print('Error in getCategoryRecipes: $e');
      rethrow;
    }
  }

  // Get all categories with recipe counts
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.recipes}/categories'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('getAllCategories response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> categoriesList = responseData['categories'];

        if (categoriesList.isEmpty) {
          print('No categories found');
          return [];
        }

        print('Found ${categoriesList.length} categories');

        return categoriesList.map((categoryJson) => Map<String, dynamic>.from(categoryJson)).toList();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get categories');
      }
    } catch (e) {
      print('Error in getAllCategories: $e');
      rethrow;
    }
  }

  // Periodically clean cache to avoid memory leaks
  void startCacheCleanupTimer() {
    // Clean cache every 30 minutes
    Timer.periodic(const Duration(minutes: 30), (timer) {
      cleanCache();
    });
  }

  // Dispose method to clean up resources
  void dispose() {
    // Clear any ongoing resources
    client.close();

    // Clear cache
    _recipeStatusCache.clear();
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