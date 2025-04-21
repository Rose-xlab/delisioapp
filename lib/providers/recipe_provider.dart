import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  Recipe? _currentRecipe;
  Recipe? _partialRecipe;  // For storing partial recipe
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
  Timer? _pollingTimer;  // Timer for polling recipe status
  int _pollingErrorCount = 0; // Track consecutive polling errors

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
  Recipe? get partialRecipe => _partialRecipe;  // Getter for partial recipe
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
      print("RecipeProvider: Checking queue status...");
      _isQueueActive = await _recipeService.isUsingQueue();
      print("RecipeProvider: Queue status check result: isQueueActive = $_isQueueActive");
      notifyListeners();
    } catch (e) {
      print("RecipeProvider: Error checking queue status: $e");
      _isQueueActive = false; // Default to not using queue if check fails
      notifyListeners();
    }
  }

  // Start polling for recipe generation status with improved error handling
  void _startPollingForStatus(String requestId) {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      print("RecipeProvider: Cancelled existing polling timer.");
    }

    print("RecipeProvider: Starting polling for requestId: $requestId");
    _pollingErrorCount = 0; // Reset error count

    // Poll every 5 seconds - not too aggressive to avoid rate limits
    const duration = Duration(milliseconds: 5000);

    _pollingTimer = Timer.periodic(duration, (timer) async {
      // Check conditions to stop polling
      if (!_isLoading || _wasCancelled) {
        print("RecipeProvider: Stopping polling timer (isLoading: $_isLoading, wasCancelled: $_wasCancelled)");
        timer.cancel();
        _pollingTimer = null;
        return;
      }

      try {
        // Add exponential backoff on rate limit errors
        if (_pollingErrorCount > 0) {
          // Wait longer between requests if we've hit rate limits before
          await Future.delayed(Duration(milliseconds: _pollingErrorCount * 2000));
        }

        print("RecipeProvider: Polling status for $requestId...");
        final statusResult = await _recipeService.checkRecipeStatus(requestId);

        // Reset error count on successful poll
        _pollingErrorCount = 0;

        // Update progress if still processing
        if (statusResult['status'] != null) {
          final newProgress = (statusResult['progress'] as num? ?? 0).toDouble();
          print("RecipeProvider: Status update - Status: ${statusResult['status']}, Progress: $newProgress%");
          _generationProgress = newProgress / 100.0;

          // Update partial recipe if available
          if (statusResult['partialRecipe'] != null) {
            print("RecipeProvider: Received partial recipe data");
            try {
              _partialRecipe = Recipe.fromJson(statusResult['partialRecipe']);
              print("RecipeProvider: Partial recipe parsed: ${_partialRecipe?.title}");
            } catch (parseError) {
              print("RecipeProvider: Error parsing partial recipe: $parseError");
              // Don't set error state for partial recipe parsing issues
            }
          }

          notifyListeners();
        } else {
          // Final recipe is ready
          print("RecipeProvider: Polling complete - Received final recipe");
          timer.cancel();
          _pollingTimer = null;
          _isLoading = false;
          _generationProgress = 1.0;

          try {
            final recipe = Recipe.fromJson(statusResult);
            _currentRecipe = recipe;
            _partialRecipe = null; // Clear partial recipe on completion
            print("RecipeProvider: Final recipe received with title: ${recipe.title}");
          } catch (parseError) {
            print("RecipeProvider: Error parsing final recipe: $parseError");
            _error = 'Error parsing recipe data';
          }

          notifyListeners();
        }
      } catch (e) {
        print("RecipeProvider: Error during polling: $e");

        _pollingErrorCount++; // Increment error count

        // Handle specific error types
        if (e.toString().contains('Too many requests') || e.toString().contains('429')) {
          print("RecipeProvider: Rate limit hit (429). Slowing down polling rate.");

          // Adjust polling interval by recreating timer with longer duration
          timer.cancel();
          final newDuration = Duration(milliseconds: 5000 * math.pow(2, _pollingErrorCount).toInt());
          print("RecipeProvider: Rate limit hit, increasing poll interval to ${newDuration.inMilliseconds}ms");
          _pollingTimer = Timer(newDuration, () => _doPollStatus(requestId, timer));
        } else if (e.toString().contains('cancelled') || e.toString().contains('499')) {
          print("RecipeProvider: Generation was cancelled during polling");
          _wasCancelled = true;
          _error = 'Recipe generation cancelled';
          timer.cancel();
          _pollingTimer = null;
          _isLoading = false;
          notifyListeners();
        } else if (e.toString().contains('404')) {
          print("RecipeProvider: Recipe job not found (404)");

          // Don't immediately stop on 404 - the job might just be finishing
          if (_pollingErrorCount > 2) {
            _error = 'Recipe generation status not found';
            timer.cancel();
            _pollingTimer = null;
            _isLoading = false;
            notifyListeners();
          }
        } else {
          // For other errors, try a few times before giving up
          if (_pollingErrorCount > 3) {
            print("RecipeProvider: Too many polling errors, stopping");
            _error = 'Error checking recipe status: ${e.toString().replaceFirst("Exception: ", "")}';
            timer.cancel();
            _pollingTimer = null;
            _isLoading = false;
            notifyListeners();
          }
        }
      }
    });
  }

  // Helper method to extract the polling logic for reuse
  Future<void> _doPollStatus(String requestId, Timer timer) async {
    // Check conditions to stop polling
    if (!_isLoading || _wasCancelled) {
      timer.cancel();
      _pollingTimer = null;
      return;
    }

    try {
      final statusResult = await _recipeService.checkRecipeStatus(requestId);

      _pollingErrorCount = 0; // Reset on success

      // Same status handling logic as in _startPollingForStatus
      if (statusResult['status'] != null) {
        final newProgress = (statusResult['progress'] as num? ?? 0).toDouble();
        _generationProgress = newProgress / 100.0;

        if (statusResult['partialRecipe'] != null) {
          try {
            _partialRecipe = Recipe.fromJson(statusResult['partialRecipe']);
          } catch (parseError) {
            print("Error parsing partial recipe: $parseError");
          }
        }

        notifyListeners();
      } else {
        // Recipe complete - identical to the original handler
        timer.cancel();
        _pollingTimer = null;
        _isLoading = false;
        _generationProgress = 1.0;

        try {
          final recipe = Recipe.fromJson(statusResult);
          _currentRecipe = recipe;
          _partialRecipe = null;
        } catch (parseError) {
          _error = 'Error parsing recipe data';
        }

        notifyListeners();
      }
    } catch (e) {
      // Simplified error handling for the recursive call
      _pollingErrorCount++;
      if (_pollingErrorCount > 5) { // Higher threshold for the slow polling
        _error = 'Error communicating with server';
        timer.cancel();
        _pollingTimer = null;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Improved method to cancel recipe generation
  Future<void> cancelRecipeGeneration() async {
    if (!_isLoading || _currentRequestId == null) {
      print("RecipeProvider: Cannot cancel - not loading or no requestId");
      return;
    }

    _isCancelling = true;
    notifyListeners();

    print('RecipeProvider: Attempting cancellation...');
    final requestIdToCancel = _currentRequestId;

    try {
      if (requestIdToCancel == null) {
        _wasCancelled = true;
        _error = 'Recipe generation cancelled (no request ID)';
      } else {
        final success = await _recipeService.cancelRecipeGeneration(requestIdToCancel);
        if (success) {
          print('RecipeProvider: Cancellation successful');
          _wasCancelled = true;
          _error = 'Recipe generation cancelled';
        } else {
          print('RecipeProvider: Cancellation API call failed, marking cancelled locally');
          _wasCancelled = true;
          _error = 'Recipe generation cancelled (server may still be processing)';
        }
      }
    } catch (e) {
      print('RecipeProvider: Error during cancellation: $e');
      _wasCancelled = true;
      _error = 'Error during cancellation request';
    } finally {
      // Always stop polling and reset state
      if (_pollingTimer != null) {
        _pollingTimer!.cancel();
        _pollingTimer = null;
      }
      _currentRequestId = null;
      _isLoading = false;
      _isCancelling = false;
      _generationProgress = 0.0;
      _partialRecipe = null;
      notifyListeners();
    }
  }

  // Reset cancellation state
  void _resetCancellationState() {
    _isCancelling = false;
    _wasCancelled = false;
    _currentRequestId = null;
    _generationProgress = 0.0;
    _partialRecipe = null;
    _pollingErrorCount = 0;

    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }
  }

  // Generate a new recipe - enhanced for better queue handling
  Future<void> generateRecipe(String query, {bool save = false, String? token}) async {
    _isLoading = true;
    _error = null;
    _resetCancellationState();
    _partialRecipe = null;
    notifyListeners();

    try {
      print('RecipeProvider: Starting generateRecipe for query: $query');

      // Always check queue status first to ensure we use the correct path
      await checkQueueStatus();
      print("RecipeProvider: Queue status confirmed. isQueueActive = $_isQueueActive");

      if (_isQueueActive) {
        print("RecipeProvider: Using QUEUED generation path");

        final requestResult = await _recipeService.startRecipeGeneration(query, save: save, token: token);
        _currentRequestId = requestResult['requestId'];
        print('RecipeProvider: Received requestId for polling: $_currentRequestId');

        if (_currentRequestId != null) {
          _startPollingForStatus(_currentRequestId!);
        } else {
          throw Exception('No request ID received for polling');
        }

        // _isLoading remains true while polling is active
      } else {
        print("RecipeProvider: Using DIRECT (non-queued) generation");

        final recipe = await _recipeService.generateRecipe(query, save: save, token: token);
        _currentRequestId = recipe.requestId;
        print('RecipeProvider: Received direct recipe with ID: ${recipe.id}');

        if (_wasCancelled) {
          print('RecipeProvider: Generation was cancelled during API call');
          _error = 'Recipe generation cancelled';
          _isLoading = false;
        } else {
          _currentRecipe = recipe;
          _generationProgress = 1.0;
          if (save && token != null && recipe.id != null) {
            // Add to user recipes if saved
            final existingIndex = _userRecipes.indexWhere((r) => r.id == recipe.id);
            if (existingIndex >= 0) {
              _userRecipes[existingIndex] = recipe;
            } else {
              _userRecipes.add(recipe);
            }
          }
          print('RecipeProvider: Direct recipe generation successful');
          _isLoading = false;
        }
      }
    } catch (e) {
      print("RecipeProvider: Error in generateRecipe: $e");

      if (e.toString().contains('cancelled')) {
        _wasCancelled = true;
        _error = 'Recipe generation cancelled';
      } else {
        _error = e.toString().replaceFirst("Exception: ", "");
      }

      _isLoading = false;

      if (_pollingTimer != null) {
        _pollingTimer!.cancel();
        _pollingTimer = null;
      }
    } finally {
      if (_pollingTimer == null) {
        _isLoading = false;
      }

      _isCancelling = false;
      notifyListeners();
    }
  }

  // The rest of the RecipeProvider remains unchanged
  // (UserRecipes, FavoriteRecipes, Trending, Discover, etc.)

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
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching user recipes: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching recipe by ID: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRecipe(String recipeId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    bool success = false;

    try {
      print('RecipeProvider: Deleting recipe ID: $recipeId');
      success = await _recipeService.deleteRecipe(recipeId, token);
      if (success) {
        _userRecipes.removeWhere((recipe) => recipe.id == recipeId);
        _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
        if (_currentRecipe?.id == recipeId) _currentRecipe = null;
        print('RecipeProvider: Recipe deleted successfully');
      }
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error deleting recipe: $_error');
      success = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> toggleFavorite(String recipeId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    bool success = false;
    bool isCurrentlyFavorite = _favoriteRecipes.any((r) => r.id == recipeId) ||
        (_currentRecipe?.id == recipeId && _currentRecipe!.isFavorite);

    try {
      if (isCurrentlyFavorite) {
        success = await _recipeService.removeFromFavorites(recipeId, token);
        if (success) {
          _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
          if (_currentRecipe?.id == recipeId) {
            _currentRecipe = _currentRecipe!.copyWith(isFavorite: false);
          }
          print('RecipeProvider: Recipe removed from favorites');
        }
      } else {
        success = await _recipeService.addToFavorites(recipeId, token);
        if (success) {
          if (_currentRecipe?.id == recipeId) {
            _currentRecipe = _currentRecipe!.copyWith(isFavorite: true);
            if (!_favoriteRecipes.any((r) => r.id == recipeId)) {
              _favoriteRecipes.add(_currentRecipe!);
            }
          } else {
            print('RecipeProvider: Recipe added to favorites');
          }
        }
      }

      final userRecipeIndex = _userRecipes.indexWhere((recipe) => recipe.id == recipeId);
      if (userRecipeIndex >= 0 && _currentRecipe?.id == recipeId) {
        _userRecipes[userRecipeIndex] = _currentRecipe!;
      }
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error toggling favorite: $_error');
      success = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

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
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching favorite recipes: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> shareRecipe() async {
    if (_currentRecipe == null) {
      print('RecipeProvider: Cannot share, current recipe is null');
      _error = "No recipe selected to share.";
      notifyListeners();
      return;
    }

    _error = null;
    notifyListeners();

    try {
      await _recipeService.shareRecipe(_currentRecipe!);
      print('RecipeProvider: Share action initiated successfully');
    } catch (e) {
      _error = "Could not share recipe: ${e.toString().replaceFirst("Exception: ", "")}";
      print('RecipeProvider: Error sharing recipe: $_error');
      notifyListeners();
    }
  }

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
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching trending recipes: $_error');
      _trendingRecipes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getAllCategories() async {
    _error = null;
    try {
      print('RecipeProvider: Fetching all recipe categories');
      final categoriesData = await _recipeService.getAllCategories();
      _categories = categoriesData.map((categoryData) {
        return RecipeCategory(
          id: categoryData['id'] as String? ?? 'unknown',
          name: categoryData['name'] as String? ?? 'Unnamed Category',
          description: categoryData['description'] as String? ?? '',
          icon: RecipeCategory.getCategoryIcon(categoryData['id'] as String? ?? ''),
          color: RecipeCategory.getCategoryColor(categoryData['id'] as String? ?? ''),
          count: categoryData['count'] as int? ?? 0,
        );
      }).toList();
      print('RecipeProvider: Got ${_categories.length} categories');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching categories: $_error');
      _categories = [];
    }
    notifyListeners();
  }

  Future<void> getDiscoverRecipes({
    String? category, String? query, String sort = 'recent', String? token,
  }) async {
    _isLoading = true;
    _error = null;
    _currentPage = 0;
    _hasMoreRecipes = true;
    _discoverRecipes = [];
    notifyListeners();

    try {
      print('RecipeProvider: Fetching discover recipes');
      print('RecipeProvider: Category: $category, Query: $query, Sort: $sort');

      List<String>? tags;
      String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) {
        // Extract tags from query
        final RegExp tagRegex = RegExp(r'#(\w+)');
        final matches = tagRegex.allMatches(processedQuery);
        if (matches.isNotEmpty) {
          tags = matches.map((m) => m.group(1)!).toList();
          // Remove tags from query
          processedQuery = processedQuery.replaceAll(tagRegex, '').trim();
          if (processedQuery.isEmpty) processedQuery = null;
        }
      }

      final recipes = await _recipeService.getDiscoverRecipes(
        category: category,
        tags: tags,
        sort: sort,
        limit: 20,
        offset: 0,
        token: token,
        query: processedQuery,
      );

      _discoverRecipes = recipes;
      _hasMoreRecipes = recipes.length == 20; // Assume more if we got a full page
      print('RecipeProvider: Got ${recipes.length} discover recipes');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error fetching discover recipes: $_error');
      _discoverRecipes = [];
      _hasMoreRecipes = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreDiscoverRecipes({
    String? category, String? query, String sort = 'recent', String? token,
  }) async {
    if (_isLoadingMore || !_hasMoreRecipes) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      print('RecipeProvider: Loading more discover recipes (page: $_currentPage)');

      List<String>? tags;
      String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) {
        // Extract tags from query (same logic as in getDiscoverRecipes)
        final RegExp tagRegex = RegExp(r'#(\w+)');
        final matches = tagRegex.allMatches(processedQuery);
        if (matches.isNotEmpty) {
          tags = matches.map((m) => m.group(1)!).toList();
          processedQuery = processedQuery.replaceAll(tagRegex, '').trim();
          if (processedQuery.isEmpty) processedQuery = null;
        }
      }

      final recipes = await _recipeService.getDiscoverRecipes(
        category: category,
        tags: tags,
        sort: sort,
        limit: 20,
        offset: _currentPage * 20,
        token: token,
        query: processedQuery,
      );

      if (recipes.isEmpty) {
        _hasMoreRecipes = false;
      } else {
        _discoverRecipes.addAll(recipes);
        _hasMoreRecipes = recipes.length == 20; // Assume more if we got a full page
      }

      print('RecipeProvider: Loaded ${recipes.length} more discover recipes');
    } catch (e) {
      _error = e.toString().replaceFirst("Exception: ", "");
      print('RecipeProvider: Error loading more discover recipes: $_error');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> resetAndReloadDiscoverRecipes({
    String? category, String? query, String sort = 'recent', String? token,
  }) async {
    return getDiscoverRecipes(
      category: category,
      query: query,
      sort: sort,
      token: token,
    );
  }

  Future<List<Recipe>> getCategoryRecipes(
      String categoryId, {
        String sort = 'recent',
        int limit = 20,
        int offset = 0,
        String? token,
      }
      ) async {
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
      print('RecipeProvider: Error fetching category recipes: $e');
      return [];
    }
  }

  void clearCurrentRecipe() {
    _currentRecipe = null;
    _partialRecipe = null;
    _resetCancellationState();
    notifyListeners();
  }
}