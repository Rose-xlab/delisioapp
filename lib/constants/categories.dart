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
    icon: Icons.free_breakfast,
    color: Colors.amber,
  );

  static const lunch = RecipeCategoryData(
    id: 'lunch',
    name: 'Lunch',
    description: 'Midday meals that are quick and satisfying',
    icon: Icons.lunch_dining,
    color: Colors.lightGreen,
  );

  static const dinner = RecipeCategoryData(
    id: 'dinner',
    name: 'Dinner',
    description: 'Evening meals for the whole family',
    icon: Icons.dinner_dining,
    color: Colors.indigo,
  );

  static const dessert = RecipeCategoryData(
    id: 'dessert',
    name: 'Dessert',
    description: 'Sweet treats for after meals',
    icon: Icons.cake,
    color: Colors.pink,
  );

  static const appetizer = RecipeCategoryData(
    id: 'appetizer',
    name: 'Appetizer',
    description: 'Small bites to start a meal',
    icon: Icons.tapas,
    color: Colors.deepOrange,
  );

  static const sideDish = RecipeCategoryData(
    id: 'side-dish',
    name: 'Side Dish',
    description: 'Accompaniments to main courses',
    icon: Icons.restaurant,
    color: Colors.lime,
  );

  static const salad = RecipeCategoryData(
    id: 'salad',
    name: 'Salad',
    description: 'Fresh and healthy salad dishes',
    icon: Icons.spa,
    color: Colors.green,
  );

  static const soup = RecipeCategoryData(
    id: 'soup',
    name: 'Soup',
    description: 'Warm and comforting soups and stews',
    icon: Icons.soup_kitchen,
    color: Colors.brown,
  );

  static const vegetarian = RecipeCategoryData(
    id: 'vegetarian',
    name: 'Vegetarian',
    description: 'Meat-free recipes for vegetarians',
    icon: Icons.eco,
    color: Colors.lightGreen,
  );

  static const vegan = RecipeCategoryData(
    id: 'vegan',
    name: 'Vegan',
    description: 'Plant-based recipes without animal products',
    icon: Icons.grass,
    color: Colors.teal,
  );

  static const glutenFree = RecipeCategoryData(
    id: 'gluten-free',
    name: 'Gluten-Free',
    description: 'Recipes without gluten for those with sensitivities',
    icon: Icons.do_not_touch,
    color: Colors.amber,
  );

  static const seafood = RecipeCategoryData(
    id: 'seafood',
    name: 'Seafood',
    description: 'Fish and shellfish dishes from the sea',
    icon: Icons.water,
    color: Colors.blue,
  );

  static const meat = RecipeCategoryData(
    id: 'meat',
    name: 'Meat',
    description: 'Hearty meat-based dishes for carnivores',
    icon: Icons.restaurant_menu,
    color: Colors.red,
  );

  static const pasta = RecipeCategoryData(
    id: 'pasta',
    name: 'Pasta',
    description: 'Italian-inspired pasta dishes',
    icon: Icons.ramen_dining,
    color: Colors.yellow,
  );

  static const baking = RecipeCategoryData(
    id: 'baking',
    name: 'Baking',
    description: 'Sweet and savory baked goods',
    icon: Icons.bakery_dining,
    color: Colors.brown,
  );

  static const slowCooker = RecipeCategoryData(
    id: 'slow-cooker',
    name: 'Slow Cooker',
    description: 'Set-it-and-forget-it slow cooker recipes',
    icon: Icons.slow_motion_video,
    color: Colors.deepPurple,
  );

  static const quickEasy = RecipeCategoryData(
    id: 'quick-easy',
    name: 'Quick & Easy',
    description: 'Fast recipes for busy days',
    icon: Icons.timer,
    color: Colors.orange,
  );

  static const healthy = RecipeCategoryData(
    id: 'healthy',
    name: 'Healthy',
    description: 'Nutritious recipes for a balanced diet',
    icon: Icons.favorite,
    color: Colors.green,
  );

  static const beverage = RecipeCategoryData(
    id: 'beverage',
    name: 'Beverage',
    description: 'Drinks from smoothies to cocktails',
    icon: Icons.local_bar,
    color: Colors.lightBlue,
  );

  static const international = RecipeCategoryData(
    id: 'international',
    name: 'International',
    description: 'Cuisine from around the world',
    icon: Icons.public,
    color: Colors.deepPurple,
  );

  static const other = RecipeCategoryData(
    id: 'other',
    name: 'Other',
    description: 'Recipes that don\'t fit other categories',
    icon: Icons.more_horiz,
    color: Colors.grey,
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