// models/user.dart
import 'user_preferences.dart';

class User {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  UserPreferences? preferences;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.preferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'preferences': preferences?.toJson(),
    };
  }
}