// lib/models/user.dart
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'user_preferences.dart';

class User {
  final String id;
  final String email; // Made non-nullable assuming email is always present for a User object
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
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'User',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>)
          : null,
    );
  }

  factory User.fromSupabaseUser(supabase.User supabaseUser) {
    final metadata = supabaseUser.userMetadata;
    String extractedName = metadata?['name'] as String? ??
        metadata?['full_name'] as String? ??
        'New User'; // Default if no name in metadata

    UserPreferences? prefs;
    if (metadata != null && metadata['preferences'] is Map<String, dynamic>) {
      try {
        prefs = UserPreferences.fromJson(metadata['preferences'] as Map<String, dynamic>);
      } catch (e) {
        print("Error parsing preferences from Supabase user metadata: $e");
      }
    }

    return User(
      id: supabaseUser.id,
      email: supabaseUser.email ?? '',
      name: extractedName.isNotEmpty ? extractedName : (supabaseUser.email?.split('@').first ?? 'User'), // Fallback name from email
      createdAt: DateTime.tryParse(supabaseUser.createdAt ?? '') ?? DateTime.now(),
      preferences: prefs,
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

  // <<< COPYWITH METHOD ADDED HERE >>>
  User copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
    UserPreferences? preferences,
    // Add other fields if your User model has more that should be copyable
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
    );
  }
}