// models/user_preferences.dart
class UserPreferences {
  final List<String> dietaryRestrictions;
  final List<String> favoriteCuisines;
  final List<String> allergies;
  final String cookingSkill;

  UserPreferences({
    this.dietaryRestrictions = const [],
    this.favoriteCuisines = const [],
    this.allergies = const [],
    this.cookingSkill = 'beginner',
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      dietaryRestrictions: List<String>.from(json['dietaryRestrictions'] ?? []),
      favoriteCuisines: List<String>.from(json['favoriteCuisines'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      cookingSkill: json['cookingSkill'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dietaryRestrictions': dietaryRestrictions,
      'favoriteCuisines': favoriteCuisines,
      'allergies': allergies,
      'cookingSkill': cookingSkill,
    };
  }
}