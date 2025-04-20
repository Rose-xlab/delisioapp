// lib/models/recipe_category.dart
import 'package:flutter/material.dart';

class RecipeCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int count;

  RecipeCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.count = 0,
  });

  // Factory to create from API JSON
  factory RecipeCategory.fromJson(Map<String, dynamic> json) {
    return RecipeCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? 'Delicious recipes',
      icon: getCategoryIcon(json['id'] as String),
      color: getCategoryColor(json['id'] as String),
      count: json['count'] as int? ?? 0,
    );
  }

  // Helper to get appropriate icon for a category
  static IconData getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'dessert':
        return Icons.cake;
      case 'appetizer':
        return Icons.tapas;
      case 'side-dish':
        return Icons.restaurant;
      case 'salad':
        return Icons.spa;
      case 'soup':
        return Icons.soup_kitchen;
      case 'vegetarian':
        return Icons.eco;
      case 'vegan':
        return Icons.grass;
      case 'gluten-free':
        return Icons.do_not_touch;
      case 'seafood':
        return Icons.water;
      case 'meat':
        return Icons.restaurant_menu;
      case 'pasta':
        return Icons.ramen_dining;
      case 'baking':
        return Icons.bakery_dining;
      case 'slow-cooker':
        return Icons.slow_motion_video;
      case 'quick-easy':
        return Icons.timer;
      case 'healthy':
        return Icons.health_and_safety;
      case 'beverage':
        return Icons.local_bar;
      case 'international':
        return Icons.public;
      default:
        return Icons.category;
    }
  }

  // Helper to get appropriate color for a category
  static Color getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'breakfast':
        return Colors.amber;
      case 'lunch':
        return Colors.lightGreen;
      case 'dinner':
        return Colors.indigo;
      case 'dessert':
        return Colors.pink;
      case 'appetizer':
        return Colors.deepOrange;
      case 'side-dish':
        return Colors.lime;
      case 'salad':
        return Colors.green;
      case 'soup':
        return Colors.brown;
      case 'vegetarian':
        return Colors.lightGreen;
      case 'vegan':
        return Colors.teal;
      case 'gluten-free':
        return Colors.amber.shade700;
      case 'seafood':
        return Colors.blue;
      case 'meat':
        return Colors.red;
      case 'pasta':
        return Colors.yellow.shade800;
      case 'baking':
        return Colors.brown.shade300;
      case 'slow-cooker':
        return Colors.deepPurple;
      case 'quick-easy':
        return Colors.orange;
      case 'healthy':
        return Colors.green;
      case 'beverage':
        return Colors.lightBlue;
      case 'international':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }
}