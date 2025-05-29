// lib/constants/categories.dart
import 'package:flutter/material.dart';

class RecipeCategoryData {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const RecipeCategoryData({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class RecipeCategories {
  static const breakfast = RecipeCategoryData(
    id: 'breakfast',
    name: 'Breakfast',
    description: 'Morning meals to start your day',
    icon: Icons.breakfast_dining,
    color: Color(0xFFFF8A65), // Warm coral orange
  );

  static const lunch = RecipeCategoryData(
    id: 'lunch',
    name: 'Lunch',
    description: 'Midday meals that are quick and satisfying',
    icon: Icons.lunch_dining,
    color: Color(0xFF66BB6A), // Fresh green
  );

  static const dinner = RecipeCategoryData(
    id: 'dinner',
    name: 'Dinner',
    description: 'Evening meals for the whole family',
    icon: Icons.dinner_dining,
    color: Color(0xFF5C6BC0), // Sophisticated indigo
  );

  static const dessert = RecipeCategoryData(
    id: 'dessert',
    name: 'Dessert',
    description: 'Sweet treats for after meals',
    icon: Icons.cake_outlined,
    color: Color(0xFFEC407A), // Sweet pink
  );

  static const appetizer = RecipeCategoryData(
    id: 'appetizer',
    name: 'Appetizer',
    description: 'Small bites to start a meal',
    icon: Icons.tapas,
    color: Color(0xFFFF7043), // Vibrant orange-red
  );

  static const sideDish = RecipeCategoryData(
    id: 'side-dish',
    name: 'Side Dish',
    description: 'Accompaniments to main courses',
    icon: Icons.rice_bowl,
    color: Color(0xFF9CCC65), // Light lime green
  );

  static const salad = RecipeCategoryData(
    id: 'salad',
    name: 'Salad',
    description: 'Fresh and healthy salad dishes',
    icon: Icons.eco,
    color: Color(0xFF4CAF50), // Natural green
  );

  static const soup = RecipeCategoryData(
    id: 'soup',
    name: 'Soup',
    description: 'Warm and comforting soups and stews',
    icon: Icons.soup_kitchen,
    color: Color(0xFF8D6E63), // Warm brown
  );

  static const vegetarian = RecipeCategoryData(
    id: 'vegetarian',
    name: 'Vegetarian',
    description: 'Meat-free recipes for vegetarians',
    icon: Icons.local_florist,
    color: Color(0xFF7CB342), // Vibrant green
  );

  static const vegan = RecipeCategoryData(
    id: 'vegan',
    name: 'Vegan',
    description: 'Plant-based recipes without animal products',
    icon: Icons.grass,
    color: Color(0xFF388E3C), // Deep forest green
  );

  static const glutenFree = RecipeCategoryData(
    id: 'gluten-free',
    name: 'Gluten-Free',
    description: 'Recipes without gluten for those with sensitivities',
    icon: Icons.no_food,
    color: Color(0xFFFFA726), // Golden amber
  );

  static const seafood = RecipeCategoryData(
    id: 'seafood',
    name: 'Seafood',
    description: 'Fish and shellfish dishes from the sea',
    icon: Icons.set_meal,
    color: Color(0xFF29B6F6), // Ocean blue
  );

  static const meat = RecipeCategoryData(
    id: 'meat',
    name: 'Meat',
    description: 'Hearty meat-based dishes for carnivores',
    icon: Icons.outdoor_grill,
    color: Color(0xFFE53935), // Rich red
  );

  static const pasta = RecipeCategoryData(
    id: 'pasta',
    name: 'Pasta',
    description: 'Italian-inspired pasta dishes',
    icon: Icons.ramen_dining,
    color: Color(0xFFFFCA28), // Golden yellow
  );

  static const baking = RecipeCategoryData(
    id: 'baking',
    name: 'Baking',
    description: 'Sweet and savory baked goods',
    icon: Icons.bakery_dining,
    color: Color(0xFFD7CCC8), // Warm beige
  );

  static const slowCooker = RecipeCategoryData(
    id: 'slow-cooker',
    name: 'Slow Cooker',
    description: 'Set-it-and-forget-it slow cooker recipes',
    icon: Icons.kitchen,
    color: Color(0xFF7E57C2), // Deep purple
  );

  static const quickEasy = RecipeCategoryData(
    id: 'quick-easy',
    name: 'Quick & Easy',
    description: 'Fast recipes for busy days',
    icon: Icons.flash_on,
    color: Color(0xFFFF9800), // Energetic orange
  );

  static const healthy = RecipeCategoryData(
    id: 'healthy',
    name: 'Healthy',
    description: 'Nutritious recipes for a balanced diet',
    icon: Icons.favorite_outline,
    color: Color(0xFF43A047), // Healthy green
  );

  static const beverage = RecipeCategoryData(
    id: 'beverage',
    name: 'Beverage',
    description: 'Drinks from smoothies to cocktails',
    icon: Icons.local_cafe,
    color: Color(0xFF26C6DA), // Refreshing cyan
  );

  static const international = RecipeCategoryData(
    id: 'international',
    name: 'International',
    description: 'Cuisine from around the world',
    icon: Icons.language,
    color: Color(0xFF8E24AA), // Worldly purple
  );

  static const other = RecipeCategoryData(
    id: 'other',
    name: 'Other',
    description: 'Recipes that don\'t fit other categories',
    icon: Icons.restaurant_menu,
    color: Color(0xFF78909C), // Neutral blue-grey
  );

  // Static list of all categories for easy access
  static List<RecipeCategoryData> allCategories = [
    breakfast,
    lunch,
    dinner,
    dessert,
    appetizer,
    sideDish,
    salad,
    soup,
    vegetarian,
    vegan,
    glutenFree,
    seafood,
    meat,
    pasta,
    baking,
    slowCooker,
    quickEasy,
    healthy,
    beverage,
    international,
    other,
  ];

  // Get category by ID
  static RecipeCategoryData getCategoryById(String id) {
    return allCategories.firstWhere(
          (category) => category.id == id,
      orElse: () => other,
    );
  }

  // Get categories for display in the home screen (a subset for space reasons)
  static List<RecipeCategoryData> getHomeCategories() {
    return [
      breakfast,
      lunch,
      dinner,
      dessert,
      quickEasy,
      healthy,
      vegetarian,
      baking,
    ];
  }

  // Get featured categories (perhaps based on trending, season, etc.)
  static List<RecipeCategoryData> getFeaturedCategories() {
    return [
      quickEasy,
      vegetarian,
      dessert,
      healthy,
    ];
  }
}