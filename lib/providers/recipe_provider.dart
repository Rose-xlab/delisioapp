// lib/providers/recipe_provider.dart
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';
import '../models/nutrition_info.dart';
import '../services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  Recipe? _currentRecipe;
  List<Recipe> _userRecipes = [];
  List<Recipe> _favoriteRecipes = [];
  bool _isLoading = false;
  String? _error;

  // Added to support cancellation
  bool _isCancelling = false;
  bool get isCancelling => _isCancelling;
  // Flag to track if generation was cancelled
  bool _wasCancelled = false;
  bool get wasCancelled => _wasCancelled;

  final RecipeService _recipeService = RecipeService();

  Recipe? get currentRecipe => _currentRecipe;
  List<Recipe> get userRecipes => _userRecipes;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Method to directly set the current recipe
  void setCurrentRecipe(Recipe recipe) {
    _currentRecipe = recipe;
    notifyListeners();
  }

  // Added method to cancel recipe generation
  Future<void> cancelRecipeGeneration() async {
    if (!_isLoading) return; // Only cancel if loading

    _isCancelling = true;
    notifyListeners();

    print('RecipeProvider: Cancelling recipe generation...');

    try {
      // Call the service to send cancellation request to backend
      final success = await _recipeService.cancelRecipeGeneration();

      if (success) {
        print('RecipeProvider: Recipe generation cancelled successfully on the server');
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
      _isLoading = false;
      _isCancelling = false;
      notifyListeners();
    }
  }

  // Reset cancellation state
  void _resetCancellationState() {
    _isCancelling = false;
    _wasCancelled = false;
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

      final recipe = await _recipeService.generateRecipe(query, save: save, token: token);

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
          print('RecipeProvider: Recipe removed from favorites');
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

  // Clear current recipe
  void clearCurrentRecipe() {
    _currentRecipe = null;
    notifyListeners();
  }
}