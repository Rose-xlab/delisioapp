// models/nutrition_info.dart
class NutritionInfo {
  final int calories;
  final String protein;
  final String fat;
  final String carbs;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? '0g',
      fat: json['fat'] ?? '0g',
      carbs: json['carbs'] ?? '0g',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
  }
}