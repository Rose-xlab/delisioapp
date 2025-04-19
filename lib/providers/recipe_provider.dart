// lib/providers/recipe_provider.dart
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';
import '../models/nutrition_info.dart';
import '../services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  Recipe? _currentRecipe;
  List<Recipe> _userRecipes = [];
  bool _isLoading = false;
  String? _error;

  final RecipeService _recipeService = RecipeService();

  Recipe? get currentRecipe => _currentRecipe;
  List<Recipe> get userRecipes => _userRecipes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Method to directly set the current recipe
  void setCurrentRecipe(Recipe recipe) {
    _currentRecipe = recipe;
    notifyListeners();
  }

  // Generate a new recipe
  Future<void> generateRecipe(String query, {bool save = false, String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('RecipeProvider: Starting recipe generation for query: $query');
      final recipe = await _recipeService.generateRecipe(query, save: save, token: token);
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
      _error = e.toString();
      print('RecipeProvider: Error generating recipe: $_error');
    } finally {
      _isLoading = false;
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

  // Clear current recipe
  void clearCurrentRecipe() {
    _currentRecipe = null;
    notifyListeners();
  }
}