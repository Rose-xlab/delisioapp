// lib/models/user_preferences.dart
import 'package:flutter/foundation.dart';

class UserPreferences {
  final List<String> dietaryRestrictions;
  final List<String> favoriteCuisines;
  final List<String> allergies;
  final String cookingSkill;
  final List<String> likedFoodCategoryIds; // <<< NEW FIELD

  UserPreferences({
    this.dietaryRestrictions = const [],
    this.favoriteCuisines = const [],
    this.allergies = const [],
    this.cookingSkill = 'beginner', // Default to lowercase
    this.likedFoodCategoryIds = const [], // <<< NEW FIELD DEFAULT
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      dietaryRestrictions: List<String>.from(json['dietaryRestrictions'] ?? []),
      favoriteCuisines: List<String>.from(json['favoriteCuisines'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      cookingSkill: json['cookingSkill'] ?? 'beginner',
      likedFoodCategoryIds: List<String>.from(json['likedFoodCategoryIds'] ?? []), // <<< NEW FIELD FROM JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dietaryRestrictions': dietaryRestrictions,
      'favoriteCuisines': favoriteCuisines,
      'allergies': allergies,
      'cookingSkill': cookingSkill,
      'likedFoodCategoryIds': likedFoodCategoryIds, // <<< NEW FIELD TO JSON
    };
  }

  // Optional: For comparing instances, useful for provider updates
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferences &&
        listEquals(other.dietaryRestrictions, dietaryRestrictions) &&
        listEquals(other.favoriteCuisines, favoriteCuisines) &&
        listEquals(other.allergies, allergies) &&
        other.cookingSkill == cookingSkill &&
        listEquals(other.likedFoodCategoryIds, likedFoodCategoryIds); // <<< NEW FIELD IN COMPARISON
  }

  @override
  int get hashCode {
    return dietaryRestrictions.hashCode ^
    favoriteCuisines.hashCode ^
    allergies.hashCode ^
    cookingSkill.hashCode ^
    likedFoodCategoryIds.hashCode; // <<< NEW FIELD IN HASHCODE
  }

  UserPreferences copyWith({
    List<String>? dietaryRestrictions,
    List<String>? favoriteCuisines,
    List<String>? allergies,
    String? cookingSkill,
    List<String>? likedFoodCategoryIds,
  }) {
    return UserPreferences(
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      favoriteCuisines: favoriteCuisines ?? this.favoriteCuisines,
      allergies: allergies ?? this.allergies,
      cookingSkill: cookingSkill ?? this.cookingSkill,
      likedFoodCategoryIds: likedFoodCategoryIds ?? this.likedFoodCategoryIds, // <<< NEW FIELD IN COPYWITH
    );
  }
}