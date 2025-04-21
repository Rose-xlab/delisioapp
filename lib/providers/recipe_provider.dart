// lib/providers/recipe_provider.dart
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';
import '../models/nutrition_info.dart';
import '../models/recipe_category.dart';
import '../services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  Recipe? _currentRecipe;
  List<Recipe> _userRecipes = [];
  List<Recipe> _favoriteRecipes = [];
  List<Recipe> _trendingRecipes = [];
  List<Recipe> _discoverRecipes = [];
  List<RecipeCategory> _categories = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreRecipes = true;
  int _currentPage = 0;
  String? _error;

  // Added for queue-based generation status
  bool _isQueueActive = false;
  double _generationProgress = 0.0;

  // Added to support cancellation
  bool _isCancelling = false;
  bool get isCancelling => _isCancelling;
  // Flag to track if generation was cancelled
  bool _wasCancelled = false;
  bool get wasCancelled => _wasCancelled;
  // Store the request ID for cancellation
  String? _currentRequestId;

  final RecipeService _recipeService = RecipeService();

  Recipe? get currentRecipe => _currentRecipe;
  List<Recipe> get userRecipes => _userRecipes;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;
  List<Recipe> get trendingRecipes => _trendingRecipes;
  List<Recipe> get discoverRecipes => _discoverRecipes;
  List<RecipeCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreRecipes => _hasMoreRecipes;
  String? get error => _error;

  // Queue-related getters
  bool get isQueueActive => _isQueueActive;
  double get generationProgress => _generationProgress;

  // Method to directly set the current recipe
  void setCurrentRecipe(Recipe recipe) {
    _currentRecipe = recipe;
    notifyListeners();
  }

  // Check if the backend is using a queue
  Future<void> checkQueueStatus() async {
    try {
      _isQueueActive = await _recipeService.isUsingQueue();
      notifyListeners();
    } catch (e) {
      // Default to not using queue if check fails
      _isQueueActive = false;
      notifyListeners();
    }
  }

  // Method to poll for recipe generation status
  Future<void> _pollForGenerationStatus() async {
    if (!_isQueueActive || _currentRequestId == null) return;

    try {
      // This would be replaced with a proper API call to check status
      // For now, we just simulate progress updates
      double progress = 0.0;
      while (progress < 1.0 && !_wasCancelled && _isLoading) {
        await Future.delayed(const Duration(milliseconds: 500));
        progress += 0.02; // Increment by 2%
        if (progress > 1.0) progress = 1.0;

        _generationProgress = progress;
        notifyListeners();
      }
    } catch (e) {
      print('Error polling for generation status: $e');
    }
  }

  // Improved method to cancel recipe generation with proper requestId handling
  Future<void> cancelRecipeGeneration() async {
    if (!_isLoading) return; // Only cancel if loading

    _isCancelling = true;
    notifyListeners();

    print('RecipeProvider: Cancelling recipe generation...');
    print('RecipeProvider: Current requestId: $_currentRequestId');

    try {
      // Make sure we have a requestId to cancel
      if (_currentRequestId == null) {
        print('RecipeProvider: No requestId available for cancellation');
        _wasCancelled = true;
        _error = 'Recipe generation cancelled, but no request ID was available';
        _isLoading = false;
        _isCancelling = false;
        notifyListeners();
        return;
      }

      // Call the service to send cancellation request to backend
      final success = await _recipeService.cancelRecipeGeneration(_currentRequestId!);

      if (success) {
        print('RecipeProvider: Recipe generation cancelled successfully on the server for requestId: $_currentRequestId');
        _wasCancelled = true;
        _error = 'Recipe generation cancelled';
      } else {
        print('RecipeProvider: Cancellation request unsuccessful, but marking as cancelled anyway');
        // Even if server-side cancellation fails, we'll mark it as cancelled for the UI
        _wasCancelled = true;
        _error = 'Recipe generation cancelled (server may still be processing)';
      }
    } catch (e) {
      print('RecipeProvider: Error during cancellation: $e');
      // Mark as cancelled anyway for the UI
      _wasCancelled = true;
      _error = 'Recipe generation cancelled with errors';
    } finally {
      // Clear current request ID after cancellation
      _currentRequestId = null;
      _isLoading = false;
      _isCancelling = false;
      notifyListeners();
    }
  }

  // Reset cancellation state
  void _resetCancellationState() {
    _isCancelling = false;
    _wasCancelled = false;
    _currentRequestId = null;
    _generationProgress = 0.0;
  }

  // Generate a new recipe
  Future<void> generateRecipe(String query, {bool save = false, String? token}) async {
    _isLoading = true;
    _error = null;
    _resetCancellationState(); // Reset cancellation state
    notifyListeners();

    try {
      print('RecipeProvider: Starting recipe generation for query: $query');

      // Check for cancellation before proceeding - probably never triggered
      // but kept for logical completeness
      if (_wasCancelled) {
        print('RecipeProvider: Generation was cancelled before API call');
        _error = 'Recipe generation cancelled';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Check if we should use queue-based generation
      if (_isQueueActive) {
        // If using queue, start polling for status
        _pollForGenerationStatus();
      }

      final recipe = await _recipeService.generateRecipe(query, save: save, token: token);

      // Save the requestId for potential cancellation
      _currentRequestId = recipe.requestId;
      print('RecipeProvider: Received recipe with requestId: $_currentRequestId');

      // Check for cancellation after API call - this can happen if
      // user initiated cancellation during API call
      if (_wasCancelled) {
        print('RecipeProvider: Generation was cancelled during/after API call');
        _error = 'Recipe generation cancelled';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentRecipe = recipe;
      _generationProgress = 1.0; // Set to 100% complete

      // Add to user recipes if saved
      if (save && token != null && recipe.id != null) {
        // Check if the recipe is already in userRecipes to avoid duplicates
        final existingIndex = _userRecipes.indexWhere((r) => r.id == recipe.id);
        if (existingIndex >= 0) {
          _userRecipes[existingIndex] = recipe;
        } else {
          _userRecipes.add(recipe);
        }
      }

      print('RecipeProvider: Recipe generation successful. Title: ${recipe.title}');
      print('RecipeProvider: Recipe has ${recipe.steps.length} steps');

      // Log step image URLs for debugging
      for (var i = 0; i < recipe.steps.length; i++) {
        print('RecipeProvider: Step ${i+1} image URL: ${recipe.steps[i].imageUrl}');
      }
    } catch (e) {
      // Check if this is a cancellation error from the service
      if (e.toString().contains('cancelled')) {
        _wasCancelled = true;
        _error = 'Recipe generation cancelled';
        print('RecipeProvider: Generation was cancelled by the server');
      } else {
        _error = e.toString();
        print('RecipeProvider: Error generating recipe: $_error');
      }
    } finally {
      _isLoading = false;
      _isCancelling = false; // Always reset cancelling state
      notifyListeners();
    }
  }

  // The remaining methods stay the same as in the original file

  // Get all recipes for current user
  Future<void> getUserRecipes(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('RecipeProvider: Fetching user recipes');
      final recipes = await _recipeService.getUserRecipes(token);
      _userRecipes = recipes;
      print('RecipeProvider: Got ${recipes.length} user recipes');
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error fetching user recipes: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get a specific recipe by ID
  Future<void> getRecipeById(String id, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('RecipeProvider: Fetching recipe by ID: $id');
      final recipe = await _recipeService.getRecipeById(id, token);
      _currentRecipe = recipe;
      print('RecipeProvider: Successfully retrieved recipe: ${recipe.title}');
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error fetching recipe by ID: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete a recipe
  Future<bool> deleteRecipe(String recipeId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('RecipeProvider: Deleting recipe ID: $recipeId');
      final success = await _recipeService.deleteRecipe(recipeId, token);

      if (success) {
        // Remove from local lists
        _userRecipes.removeWhere((recipe) => recipe.id == recipeId);
        _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);

        // Clear current recipe if it's the one being deleted
        if (_currentRecipe?.id == recipeId) {
          _currentRecipe = null;
        }

        print('RecipeProvider: Recipe deleted successfully');
      }

      return success;
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error deleting recipe: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Toggle favorite status (add/remove)
  Future<bool> toggleFavorite(String recipeId, String token) async {
    if (_currentRecipe == null || _currentRecipe!.id != recipeId) {
      print('RecipeProvider: Cannot toggle favorite, current recipe is null or ID mismatch');
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bool currentStatus = _currentRecipe!.isFavorite;
      final bool success;

      if (currentStatus) {
        // Currently favorite, remove it
        success = await _recipeService.removeFromFavorites(recipeId, token);
        if (success) {
          // Update current recipe
          _currentRecipe = _currentRecipe!.copyWith(isFavorite: false);
          // Remove from favorites list if present
          _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
          print('RecipeProvider: Reciperemoved from favorites');
        }
      } else {
        // Not favorite, add it
        success = await _recipeService.addToFavorites(recipeId, token);
        if (success) {
          // Update current recipe
          _currentRecipe = _currentRecipe!.copyWith(isFavorite: true);
          // Add to favorites list if not already there
          if (!_favoriteRecipes.any((recipe) => recipe.id == recipeId) && _currentRecipe != null) {
            _favoriteRecipes.add(_currentRecipe!);
          }
          print('RecipeProvider: Recipe added to favorites');
        }
      }

      // Update the recipe in user recipes list if it exists there
      final userRecipeIndex = _userRecipes.indexWhere((recipe) => recipe.id == recipeId);
      if (userRecipeIndex >= 0 && _currentRecipe != null) {
        _userRecipes[userRecipeIndex] = _currentRecipe!;
      }

      return success;
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error toggling favorite: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get user's favorite recipes
  Future<void> getFavoriteRecipes(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('RecipeProvider: Fetching favorite recipes');
      final recipes = await _recipeService.getFavoriteRecipes(token);
      _favoriteRecipes = recipes;
      print('RecipeProvider: Got ${recipes.length} favorite recipes');
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error fetching favorite recipes: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Share the current recipe
  Future<void> shareRecipe() async {
    if (_currentRecipe == null) {
      print('RecipeProvider: Cannot share, current recipe is null');
      return;
    }

    try {
      await _recipeService.shareRecipe(_currentRecipe!);
      print('RecipeProvider: Recipe shared successfully');
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error sharing recipe: $_error');
      // Don't update loading state for share operation
    }
  }

  // NEW: Get trending recipes
  Future<void> getTrendingRecipes({String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('RecipeProvider: Fetching trending recipes');
      final recipes = await _recipeService.getPopularRecipes(token: token);
      _trendingRecipes = recipes;
      print('RecipeProvider: Got ${recipes.length} trending recipes');
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error fetching trending recipes: $_error');
      _trendingRecipes = []; // Reset list on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // NEW: Get all recipe categories
  Future<void> getAllCategories() async {
    try {
      print('RecipeProvider: Fetching all recipe categories');
      final categoriesData = await _recipeService.getAllCategories();
      _categories = categoriesData.map((categoryData) {
        return RecipeCategory(
          id: categoryData['id'] as String,
          name: categoryData['name'] as String,
          description: categoryData['description'] as String? ?? 'Delicious recipes',
          icon: RecipeCategory.getCategoryIcon(categoryData['id'] as String),
          color: RecipeCategory.getCategoryColor(categoryData['id'] as String),
          count: categoryData['count'] as int? ?? 0,
        );
      }).toList();
      print('RecipeProvider: Got ${_categories.length} categories');
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error fetching categories: $_error');
      _categories = []; // Reset list on error
    }
    notifyListeners();
  }

  // NEW: Get recipes for discovery
  Future<void> getDiscoverRecipes({
    String? category,
    String? query, // Keep query here for tag parsing
    String sort = 'recent',
    String? token,
  }) async {
    _isLoading = true;
    _error = null;
    _currentPage = 0; // Reset pagination
    _hasMoreRecipes = true;
    notifyListeners();

    try {
      print('RecipeProvider: Fetching discover recipes');
      print('RecipeProvider: Category: $category, Query: $query, Sort: $sort');

      List<String>? tags;
      String? processedQuery = query; // Use a local variable for query processing

      // Parse query into tags if it contains specific tags
      if (processedQuery != null && processedQuery.contains('#')) {
        tags = processedQuery.split(' ')
            .where((word) => word.startsWith('#') && word.length > 1)
            .map((tag) => tag.substring(1).toLowerCase())
            .toList();

        // Remove tags from query string for potential future use (though not passed to service)
        processedQuery = processedQuery.split(' ')
            .where((word) => !word.startsWith('#'))
            .join(' ').trim();

        if (processedQuery.isEmpty) processedQuery = null;
      }

      // FIXED: Now properly passing the query parameter
      final recipes = await _recipeService.getDiscoverRecipes(
        category: category,
        tags: tags, // Pass the parsed tags
        sort: sort,
        limit: 20,
        offset: 0,
        token: token,
        query: processedQuery, // Now correctly passing the query parameter
      );

      _discoverRecipes = recipes;
      _hasMoreRecipes = recipes.length == 20; // If we got a full page, there might be more
      print('RecipeProvider: Got ${recipes.length} discover recipes');
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error fetching discover recipes: $_error');
      _discoverRecipes = []; // Reset list on error
      _hasMoreRecipes = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // NEW: Load more discover recipes (pagination)
  Future<void> loadMoreDiscoverRecipes({
    String? category,
    String? query, // Keep query here for tag parsing
    String sort = 'recent',
    String? token,
  }) async {
    if (_isLoadingMore || !_hasMoreRecipes) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      print('RecipeProvider: Loading more discover recipes (page: $_currentPage)');

      List<String>? tags;
      String? processedQuery = query; // Use a local variable for query processing

      // Parse query into tags if it contains specific tags
      if (processedQuery != null && processedQuery.contains('#')) {
        tags = processedQuery.split(' ')
            .where((word) => word.startsWith('#') && word.length > 1)
            .map((tag) => tag.substring(1).toLowerCase())
            .toList();

        // Remove tags from query string for potential future use (though not passed to service)
        processedQuery = processedQuery.split(' ')
            .where((word) => !word.startsWith('#'))
            .join(' ').trim();

        if (processedQuery.isEmpty) processedQuery = null;
      }

      // FIXED: Now properly passing the query parameter
      final recipes = await _recipeService.getDiscoverRecipes(
        category: category,
        tags: tags, // Pass the parsed tags
        sort: sort,
        limit: 20,
        offset: _currentPage * 20,
        token: token,
        query: processedQuery, // Now correctly passing the query parameter
      );

      if (recipes.isEmpty) {
        _hasMoreRecipes = false;
      } else {
        _discoverRecipes = [..._discoverRecipes, ...recipes];
        _hasMoreRecipes = recipes.length == 20; // If we got less than requested, we're at the end
      }

      print('RecipeProvider: Loaded ${recipes.length} more discover recipes');
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error loading more discover recipes: $_error');
      // Don't reset the list on error during pagination
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // NEW: Reset and reload discover recipes (for pull-to-refresh)
  Future<void> resetAndReloadDiscoverRecipes({
    String? category,
    String? query,
    String sort = 'recent',
    String? token,
  }) async {
    _currentPage = 0;
    _hasMoreRecipes = true;
    // Call the corrected getDiscoverRecipes method
    return getDiscoverRecipes(
      category: category,
      query: query, // Pass the original query for tag parsing
      sort: sort,
      token: token,
    );
  }

  // NEW: Get recipes by category
  Future<List<Recipe>> getCategoryRecipes(
      String categoryId, {
        String sort = 'recent',
        int limit = 20,
        int offset = 0,
        String? token,
      }) async {
    try {
      print('RecipeProvider: Fetching category recipes: $categoryId');
      final recipes = await _recipeService.getCategoryRecipes(
        categoryId,
        sort: sort,
        limit: limit,
        offset: offset,
        token: token,
      );
      print('RecipeProvider: Got ${recipes.length} category recipes');
      return recipes;
    } catch (e) {
      _error = e.toString();
      print('RecipeProvider: Error fetching category recipes: $_error');
      return [];
    }
  }

  // Clear current recipe
  void clearCurrentRecipe() {
    _currentRecipe = null;
    notifyListeners();
  }
}