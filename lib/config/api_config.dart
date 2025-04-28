// config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.1.144:3002';
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
  static const String recipesFavorites = '$apiVersion/recipes/favorites';

  // NEW: Global recipe database endpoints
  static const String recipeDiscover = '$apiVersion/recipes/discover';
  static const String recipePopular = '$apiVersion/recipes/popular';
  static const String recipeCategories = '$apiVersion/recipes/categories';

  // Subscription endpoints
  static const String subscriptionStatus = '$apiVersion/subscriptions/status';
  static const String subscriptionCheckout = '$apiVersion/subscriptions/checkout';
  static const String subscriptionPortal = '$apiVersion/subscriptions/portal';
  static const String subscriptionCancel = '$apiVersion/subscriptions/cancel';

  // Helper method to construct recipe-specific endpoints
  static String recipeById(String id) => '$recipes/$id';
  static String favoriteRecipe(String id) => '$recipes/$id/favorite';
  static String recipeCategory(String categoryId) => '$recipes/category/$categoryId';

  // Chat endpoints
  static const String chat = '$apiVersion/chat';
}