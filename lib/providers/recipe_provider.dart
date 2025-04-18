// providers/recipe_provider.dart
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
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

  // Generate a new recipe
  Future<void> generateRecipe(String query, {bool save = false, String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final recipe = await _recipeService.generateRecipe(query, save: save, token: token);
      _currentRecipe = recipe;

      // Add to user recipes if saved
      if (save && token != null) {
        _userRecipes.add(recipe);
      }
    } catch (e) {
      _error = e.toString();
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
      final recipes = await _recipeService.getUserRecipes(token);
      _userRecipes = recipes;
    } catch (e) {
      _error = e.toString();
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
      final recipe = await _recipeService.getRecipeById(id, token);
      _currentRecipe = recipe;
    } catch (e) {
      _error = e.toString();
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