// config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:3000';
  static const String apiVersion = '/api';

  // Auth endpoints
  static const String signup = '$apiVersion/auth/signup';
  static const String signin = '$apiVersion/auth/signin';
  static const String signout = '$apiVersion/auth/signout';
  static const String me = '$apiVersion/auth/me';
  static const String preferences = '$apiVersion/auth/preferences';

  // Recipe endpoints
  static const String recipes = '$apiVersion/recipes';
  static const String userRecipes = '$apiVersion/users/recipes';
  static const String cancelRecipe = '$apiVersion/recipes/cancel';
  // New endpoints for recipe operations
  static const String recipesFavorites = '$apiVersion/recipes/favorites';

  // Helper method to construct recipe-specific endpoints
  static String recipeById(String id) => '$recipes/$id';
  static String favoriteRecipe(String id) => '$recipes/$id/favorite';

  // Chat endpoints
  static const String chat = '$apiVersion/chat';
}