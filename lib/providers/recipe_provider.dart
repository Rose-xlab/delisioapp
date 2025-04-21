// lib/providers/recipe_provider.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  Recipe? _currentRecipe;
  Recipe? _partialRecipe;  // New field to store partial recipe
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
      // --- Added Logging ---
      print("RecipeProvider: Checking queue status...");
      _isQueueActive = await _recipeService.isUsingQueue();
      print("RecipeProvider: Queue status check result: isQueueActive = $_isQueueActive");
      // --- End Logging ---
      notifyListeners(); // Notify if needed, maybe only on change?
    } catch (e) {
      print("RecipeProvider: Error checking queue status: $e");
      _isQueueActive = false; // Default to not using queue if check fails
      notifyListeners();
    }
  }

  // Start polling for recipe generation status
  void _startPollingForStatus(String requestId) {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      print("RecipeProvider: Cancelled existing polling timer.");
    }
    print("RecipeProvider: Starting polling for requestId: $requestId");

    // --- INCREASED POLLING INTERVAL FURTHER ---
    const duration = Duration(milliseconds: 5000); // Poll every 5 seconds
    // --- END CHANGE ---

    _pollingTimer = Timer.periodic(duration, (timer) async {
      // Check conditions to stop polling
      if (!_isLoading || _wasCancelled) {
        print("RecipeProvider: Stopping polling timer (isLoading: $_isLoading, wasCancelled: $_wasCancelled)");
        timer.cancel();
        _pollingTimer = null;
        return;
      }

      try {
        // print("RecipeProvider: Polling status for $requestId..."); // Optional: verbose log
        final statusResult = await _recipeService.checkRecipeStatus(requestId);

        // Update progress if still processing
        if (statusResult['status'] != null) {
          final newProgress = (statusResult['progress'] as num? ?? 0).toDouble();
          print("RecipeProvider: Polling update - Status: ${statusResult['status']}, Progress: $newProgress%");
          _generationProgress = newProgress / 100.0;

          // Update partial recipe if available
          if (statusResult['partialRecipe'] != null) {
            print("RecipeProvider: Polling update - Received partial recipe data.");
            _partialRecipe = Recipe.fromJson(statusResult['partialRecipe']);
          } else {
            // Keep existing partial recipe if new data isn't sent with status update
            // _partialRecipe = null; // Or clear it if needed
          }

          notifyListeners();
        } else {
          // Assume complete recipe is ready if 'status' field is missing
          print("RecipeProvider: Polling complete - Received final recipe.");
          timer.cancel();
          _pollingTimer = null;
          _isLoading = false;
          _generationProgress = 1.0;
          final recipe = Recipe.fromJson(statusResult);
          _currentRecipe = recipe;
          _partialRecipe = null; // Clear partial recipe on completion

          notifyListeners();
        }
      } catch (e) {
        print("RecipeProvider: Error during polling: $e");
        // Specific handling for Rate Limit (429) - maybe retry with backoff later?
        // For now, we still stop polling and show an error.
        if (e.toString().contains('Too many requests') || e.toString().contains('429')) {
          print("RecipeProvider: Polling hit rate limit (429). Stopping poll.");
          _error = 'Checking status too quickly. Please wait.'; // User-friendly message
        }
        else if (e.toString().contains('cancelled') || e.toString().contains('499')) {
          print("RecipeProvider: Polling detected cancellation.");
          _wasCancelled = true; // Mark as cancelled based on polling error
          _error = 'Recipe generation cancelled';
        } else if (e.toString().contains('404')) {
          print("RecipeProvider: Polling received 404 (Job not found). Stopping poll.");
          _error = 'Recipe generation status not found. Please try again.'; // Set specific error
        }
        else {
          // Stop polling on other errors too
          _error = 'Error checking recipe status: ${e.toString().replaceFirst("Exception: ", "")}';
        }
        // Stop polling on error
        timer.cancel();
        _pollingTimer = null;
        _isLoading = false; // Stop loading indicator on error
        notifyListeners();
      }
    });
  }

  // Improved method to cancel recipe generation with proper requestId handling
  Future<void> cancelRecipeGeneration() async {
    if (!_isLoading && _currentRequestId == null) {
      print("RecipeProvider: Cannot cancel - not loading and no active requestId.");
      return; // Only cancel if loading or if there's a request ID lingering
    }

    _isCancelling = true;
    notifyListeners();

    print('RecipeProvider: Attempting cancellation...');
    final requestIdToCancel = _currentRequestId; // Capture current ID

    try {
      if (requestIdToCancel == null) {
        print('RecipeProvider: No requestId available for cancellation');
        _wasCancelled = true; // Mark as cancelled locally
        _error = 'Recipe generation cancelled (no active request ID)';
      } else {
        print('RecipeProvider: Sending cancellation request for requestId: $requestIdToCancel');
        final success = await _recipeService.cancelRecipeGeneration(requestIdToCancel);
        if (success) {
          print('RecipeProvider: Cancellation request successful for $requestIdToCancel');
          _wasCancelled = true;
          _error = 'Recipe generation cancelled';
        } else {
          print('RecipeProvider: Cancellation request unsuccessful for $requestIdToCancel, marking cancelled locally.');
          _wasCancelled = true; // Mark as cancelled anyway for UI consistency
          _error = 'Recipe generation cancelled (server may differ)';
        }
      }
    } catch (e) {
      print('RecipeProvider: Error during cancellation API call: $e');
      _wasCancelled = true; // Mark as cancelled on error
      _error = 'Error during cancellation request';
    } finally {
      // Always stop polling and reset state after cancellation attempt
      if (_pollingTimer != null) {
        _pollingTimer!.cancel();
        _pollingTimer = null;
        print("RecipeProvider: Polling timer stopped due to cancellation.");
      }
      _currentRequestId = null; // Clear the ID
      _isLoading = false; // Stop loading indicator
      _isCancelling = false; // Reset cancelling flag
      _generationProgress = 0.0; // Reset progress
      _partialRecipe = null; // Clear partial data
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

    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }
  }

  // Generate a new recipe
  Future<void> generateRecipe(String query, {bool save = false, String? token}) async {
    _isLoading = true;
    _error = null;
    _resetCancellationState(); // Reset cancellation/polling state before starting
    _partialRecipe = null;
    notifyListeners();

    try {
      print('RecipeProvider: Starting generateRecipe for query: $query');

      // --- Added Logging ---
      // Ensure queue status is checked before deciding the path
      await checkQueueStatus();
      print("RecipeProvider: Checked queue status. isQueueActive = $_isQueueActive");
      // --- End Logging ---

      if (_isQueueActive) {
        // --- Added Logging ---
        print("RecipeProvider: Using QUEUED generation path.");
        // --- End Logging ---
        final requestResult = await _recipeService.startRecipeGeneration(query, save: save, token: token);
        _currentRequestId = requestResult['requestId']; // Store the ID for polling/cancellation
        print('RecipeProvider: Received requestId for polling: $_currentRequestId');

        if (_currentRequestId != null) {
          _startPollingForStatus(_currentRequestId!); // Start polling
        } else {
          throw Exception('No request ID received from startRecipeGeneration');
        }
        // Note: _isLoading remains true while polling
      } else {
        // --- Added Logging ---
        print("RecipeProvider: Using NON-QUEUED (direct) generation path.");
        // --- End Logging ---
        final recipe = await _recipeService.generateRecipe(query, save: save, token: token);
        _currentRequestId = recipe.requestId; // Store ID from direct response if available
        print('RecipeProvider: Received direct recipe with requestId: $_currentRequestId');

        // Check if cancelled *during* the direct API call
        if (_wasCancelled) {
          print('RecipeProvider: Generation was cancelled during/after direct API call');
          _error = 'Recipe generation cancelled';
          _isLoading = false;
        } else {
          _currentRecipe = recipe;
          _generationProgress = 1.0; // Direct generation is 100% complete
          if (save && token != null && recipe.id != null) {
            // Add/update user recipes list
            final existingIndex = _userRecipes.indexWhere((r) => r.id == recipe.id);
            if (existingIndex >= 0) _userRecipes[existingIndex] = recipe;
            else _userRecipes.add(recipe);
          }
          print('RecipeProvider: Direct recipe generation successful. Title: ${recipe.title}');
          _isLoading = false; // Set loading false only on completion/error
        }
      }
    } catch (e) {
      // --- Added Logging ---
      print("RecipeProvider: Caught error in generateRecipe: ${e.toString()}");
      // --- End Logging ---
      if (e.toString().contains('cancelled')) {
        _wasCancelled = true;
        _error = 'Recipe generation cancelled';
      } else {
        _error = e.toString().replaceFirst("Exception: ", ""); // Clean up error message
      }
      _isLoading = false; // Stop loading on error
      // Ensure polling stops if an error occurred during the initial request
      if (_pollingTimer != null) {
        _pollingTimer!.cancel();
        _pollingTimer = null;
        print("RecipeProvider: Polling timer stopped due to error in initial request.");
      }
    } finally {
      // Ensure loading state is false if polling isn't active
      if (_pollingTimer == null) {
        _isLoading = false;
      }
      _isCancelling = false; // Reset cancelling state
      notifyListeners();
    }
  }

  // --- Remaining methods ---
  // (getUserRecipes, getRecipeById, deleteRecipe, toggleFavorite,
  //  getFavoriteRecipes, shareRecipe, getTrendingRecipes, getAllCategories,
  //  getDiscoverRecipes, loadMoreDiscoverRecipes, resetAndReloadDiscoverRecipes,
  //  getCategoryRecipes, clearCurrentRecipe)
  // ... [Rest of the methods as provided previously] ...
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
    bool isCurrentlyFavorite = _favoriteRecipes.any((r) => r.id == recipeId) || (_currentRecipe?.id == recipeId && _currentRecipe!.isFavorite);
    try {
      if (isCurrentlyFavorite) {
        success = await _recipeService.removeFromFavorites(recipeId, token);
        if (success) {
          _favoriteRecipes.removeWhere((recipe) => recipe.id == recipeId);
          if (_currentRecipe?.id == recipeId) _currentRecipe = _currentRecipe!.copyWith(isFavorite: false);
          print('RecipeProvider: Recipe removed from favorites');
        }
      } else {
        success = await _recipeService.addToFavorites(recipeId, token);
        if (success) {
          if (_currentRecipe?.id == recipeId) {
            _currentRecipe = _currentRecipe!.copyWith(isFavorite: true);
            if (!_favoriteRecipes.any((r) => r.id == recipeId)) _favoriteRecipes.add(_currentRecipe!);
          } else {
            print('RecipeProvider: Recipe added to favorites (list might need refresh)');
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
      List<String>? tags; String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) { /* ... parse tags ... */ }
      final recipes = await _recipeService.getDiscoverRecipes(
        category: category, tags: tags, sort: sort, limit: 20, offset: 0,
        token: token, query: processedQuery,
      );
      _discoverRecipes = recipes;
      _hasMoreRecipes = recipes.length == 20;
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
      List<String>? tags; String? processedQuery = query;
      if (processedQuery != null && processedQuery.contains('#')) { /* ... parse tags ... */ }
      final recipes = await _recipeService.getDiscoverRecipes(
        category: category, tags: tags, sort: sort, limit: 20,
        offset: _currentPage * 20, token: token, query: processedQuery,
      );
      if (recipes.isEmpty) { _hasMoreRecipes = false; }
      else { _discoverRecipes.addAll(recipes); _hasMoreRecipes = recipes.length == 20; }
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
    return getDiscoverRecipes( category: category, query: query, sort: sort, token: token, );
  }
  Future<List<Recipe>> getCategoryRecipes(
      String categoryId, { String sort = 'recent', int limit = 20, int offset = 0, String? token, }
      ) async {
    try {
      print('RecipeProvider: Fetching category recipes: $categoryId');
      final recipes = await _recipeService.getCategoryRecipes( categoryId, sort: sort, limit: limit, offset: offset, token: token, );
      print('RecipeProvider: Got ${recipes.length} category recipes');
      return recipes;
    } catch (e) {
      print('RecipeProvider: Error fetching category recipes: $_error');
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

