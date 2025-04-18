// lib/models/user.dart
import 'package:supabase_flutter/supabase_flutter.dart' as supabase; // Import Supabase User type
import 'user_preferences.dart'; // Ensure this path is correct

class User {
  final String id;
  final String email;
  final String name; // Assuming 'name' comes from user_metadata
  final DateTime createdAt;
  UserPreferences? preferences; // Assuming this comes from a separate table/query

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.preferences,
  });

  // Existing factory from your custom JSON structure (e.g., from your own backend API)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '', // Added null checks
      email: json['email'] ?? '',
      name: json['name'] ?? 'User',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : null,
    );
  }

  // --- ADD THIS FACTORY CONSTRUCTOR ---
  factory User.fromSupabaseUser(supabase.User supabaseUser) {
    // Access metadata - check for nulls carefully!
    final metadata = supabaseUser.userMetadata;
    // Adjust 'name' key if you store it differently in Supabase user_metadata
    String extractedName = metadata?['name'] as String? ?? 'User'; // Default name

    // IMPORTANT: UserPreferences likely need to be fetched separately
    // after the user is created/loaded, unless stored directly in user_metadata.
    // We'll initialize it as null here.
    UserPreferences? prefs;
    // Example if preferences WERE in metadata (adjust if needed):
    // if (metadata != null && metadata.containsKey('preferences') && metadata['preferences'] != null) {
    //   try {
    //      prefs = UserPreferences.fromJson(metadata['preferences'] as Map<String, dynamic>);
    //   } catch (e) {
    //      print("Error parsing preferences from user metadata: $e");
    //   }
    // }


    return User(
      id: supabaseUser.id,
      email: supabaseUser.email ?? '', // Handle potentially null email
      name: extractedName,
      // Use Supabase user's createdAt, converting from String
      createdAt: DateTime.tryParse(supabaseUser.createdAt ?? '') ?? DateTime.now(),
      preferences: prefs, // Assign null initially, load separately if needed
    );
  }
  // --- END OF ADDITION ---


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