// models/nutrition_info.dart
import 'package:flutter/foundation.dart'; // For kDebugMode

class NutritionInfo {
  final int calories;       // Typically whole numbers, unit: kcal
  final double protein;     // Unit: g
  final double fat;         // Unit: g
  final double carbs;       // Unit: g
  final double? fiber;       // Optional, Unit: g
  final double? sugar;       // Optional, Unit: g
  final double? saturatedFat; // Optional, Unit: g
  final double? sodium;      // Optional, Unit: mg

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.fiber,
    this.sugar,
    this.saturatedFat,
    this.sodium,
  });

  // Helper function for safe JSON parsing to double
  static double _parseDouble(dynamic jsonValue, {double defaultValue = 0.0}) {
    if (jsonValue == null) return defaultValue;
    if (jsonValue is double) return jsonValue;
    if (jsonValue is int) return jsonValue.toDouble();
    if (jsonValue is String) {
      return double.tryParse(jsonValue.replaceAll(RegExp(r'[^0-9.]'),'')) ?? defaultValue;
      // Basic attempt to strip non-numeric chars like 'g', 'mg' - adjust if needed
    }
    return defaultValue;
  }

  // Helper function for safe JSON parsing to int
  static int _parseInt(dynamic jsonValue, {int defaultValue = 0}) {
    if (jsonValue == null) return defaultValue;
    if (jsonValue is int) return jsonValue;
    if (jsonValue is double) return jsonValue.round(); // Or floor()/ceil()
    if (jsonValue is String) {
      return int.tryParse(jsonValue.replaceAll(RegExp(r'[^0-9]'),'')) ?? defaultValue;
      // Basic attempt to strip non-numeric chars - adjust if needed
    }
    return defaultValue;
  }


  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) { // Print json in debug mode to help diagnose issues
      // print('Parsing NutritionInfo from JSON: $json');
    }
    return NutritionInfo(
      // Use helper functions for safer parsing
      calories: _parseInt(json['calories']),
      protein: _parseDouble(json['protein']),
      fat: _parseDouble(json['fat']),
      carbs: _parseDouble(json['carbs']),
      fiber: json['fiber'] != null ? _parseDouble(json['fiber']) : null,
      sugar: json['sugar'] != null ? _parseDouble(json['sugar']) : null,
      saturatedFat: json['saturated_fat'] ?? json['saturatedFat'] != null
          ? _parseDouble(json['saturated_fat'] ?? json['saturatedFat'])
          : null, // Allow snake_case or camelCase
      sodium: json['sodium'] != null ? _parseDouble(json['sodium']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      // Only include optional fields in JSON if they are not null
      if (fiber != null) 'fiber': fiber,
      if (sugar != null) 'sugar': sugar,
      if (saturatedFat != null) 'saturated_fat': saturatedFat,
      if (sodium != null) 'sodium': sodium,
    };
  }

  // Example method demonstrating potential use of numeric types
  double calculateTotalMacronutrientGrams() {
    return protein + fat + carbs + (fiber ?? 0.0);
  }
}