// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase; // Import Supabase client
import 'package:uuid/uuid.dart';
import '../config/api_config.dart'; // Still needed for non-auth endpoints
// import '../config/supabase_config.dart'; // Likely no longer needed here
import '../models/user.dart'; // Your custom User model
import '../models/user_preferences.dart'; // Your UserPreferences model

class AuthService {
  // Supabase client instance
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // HTTP Client and Base URL for non-Supabase-Auth endpoints
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client(); // Keep for custom endpoints

  // --- Sign Up using Supabase Auth ---
  Future<void> signUp(String email, String password, String name) async {
    if (kDebugMode) print("AuthService: Attempting Supabase signUp with email: $email...");
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, // Ensure 'name' matches your Supabase trigger/metadata key
      );

      final user = response.user;

      if (user != null) {
        if (kDebugMode) print("AuthService: Supabase auth.signUp successful for user ${user.id}. Proceeding to profile creation/update.");

        final String userAppIdValue = const Uuid().v4(); // Generate a v4 UUID string
        final profileData = {
          "id": user.id, // This should match auth.users.id
          "user_app_id": userAppIdValue,
          // 'created_at' and 'updated_at' should now be handled by database defaults (e.g., now())
        };

        if (kDebugMode) {
          debugPrint("AuthService: Attempting to UPSERT into profiles table: $profileData");
        }

        try {
          // CRITICAL CHANGE: Use .upsert() here
          final profileResponse = await _supabase
              .from("profiles")
              .upsert(
            profileData,
            onConflict: 'id', // Specify 'id' as the column that might cause a conflict (your primary key)
          )
              .select()
              .single(); // .single() is still useful to ensure one row is affected/returned and to get errors.

          if (kDebugMode) {
            debugPrint("AuthService: Profile created or updated successfully for user ${user.id} with user_app_id $userAppIdValue. Response data: ${profileResponse.toString()}");
          }
        } catch (profileError) {
          if (kDebugMode) {
            debugPrint("AuthService: EXCEPTION during profile upsert: ${profileError.toString()}");
            if (profileError is supabase.PostgrestException) {
              debugPrint("AuthService: PostgrestException Message: ${profileError.message}");
              debugPrint("AuthService: PostgrestException Details: ${profileError.details}");
              debugPrint("AuthService: PostgrestException Code: ${profileError.code}");
              debugPrint("AuthService: PostgrestException Hint: ${profileError.hint}");
            }
          }
          throw Exception("Failed to create/update user profile after Supabase auth sign up: ${profileError.toString()}");
        }

        if (kDebugMode) {
          debugPrint("AuthService: Full Supabase signUp (auth and profile creation/update) successful. User: ${user.id}, Session: ${response.session != null}");
        }

      } else {
        if (kDebugMode) {
          debugPrint("AuthService: Supabase auth.signUp call completed, but response.user is null. Session present: ${response.session != null}. This might indicate email confirmation is pending without an immediate user object, or an unexpected issue.");
        }
        if (response.session == null && response.user == null) {
          throw Exception("Supabase sign up did not return a user or session. Check email confirmation settings or Supabase logs.");
        }
      }
    } on supabase.AuthException catch (e) {
      if (kDebugMode) debugPrint("AuthService: Supabase signUp AuthException: ${e.message}");
      throw Exception("Supabase authentication error: ${e.message}");
    } catch (e) {
      if (kDebugMode) debugPrint("AuthService: Supabase signUp generic error: $e");
      if (e.toString().startsWith("Exception: Failed to create/update user profile")) { // Adjusted to match new exception message
        rethrow;
      }
      throw Exception('An unexpected error occurred during sign up.');
    }
  }

  // --- Sign In using Supabase Auth ---
  Future<void> signIn(String email, String password) async {
    if (kDebugMode) print("AuthService: Attempting Supabase signInWithPassword...");
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (kDebugMode) {
        print("AuthService: Supabase signIn successful. User: ${response.user?.id}, Session: ${response.session != null}");
      }
    } on supabase.AuthException catch (e) {
      if (kDebugMode) print("AuthService: Supabase signIn AuthException: ${e.message}");
      throw Exception(e.message);
    } catch (e) {
      if (kDebugMode) print("AuthService: Supabase signIn generic error: $e");
      throw Exception('An unexpected error occurred during sign in.');
    }
  }

  // --- Sign Out using Supabase Auth ---
  Future<void> signOut() async {
    if (kDebugMode) print("AuthService: Attempting Supabase signOut...");
    try {
      await _supabase.auth.signOut();
      if (kDebugMode) print("AuthService: Supabase signOut successful.");
    } on supabase.AuthException catch (e) {
      if (kDebugMode) print("AuthService: Supabase signOut AuthException: ${e.message}");
      throw Exception(e.message);
    } catch (e) {
      if (kDebugMode) print("AuthService: Supabase signOut generic error: $e");
      throw Exception('An unexpected error occurred during sign out.');
    }
  }

  // --- Get Current User Profile (from custom backend) ---
  Future<User> getCurrentUser() async {
    if (kDebugMode) print("AuthService: Getting current user profile from custom backend...");
    final token = _supabase.auth.currentSession?.accessToken;

    if (token == null) {
      if (kDebugMode) print("AuthService: No auth token found for getCurrentUser.");
      throw Exception('Not authenticated');
    }

    try {
      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.me}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['user'] != null) {
          if (kDebugMode) print("AuthService: Successfully fetched user profile from backend.");
          return User.fromJson(responseData['user']);
        } else {
          throw Exception('User data not found in backend response.');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get user profile from backend (${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) print("AuthService: Error calling custom backend for user profile: $e");
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // --- Update User Preferences (via custom backend) ---
  Future<UserPreferences> updatePreferences(UserPreferences preferences) async {
    if (kDebugMode) print("AuthService: Updating preferences via custom backend...");
    final token = _supabase.auth.currentSession?.accessToken;

    if (token == null) {
      if (kDebugMode) print("AuthService: No auth token found for updatePreferences.");
      throw Exception('Not authenticated');
    }

    try {
      final response = await client.put(
        Uri.parse('$baseUrl${ApiConfig.preferences}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(preferences.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['preferences'] != null) {
          if (kDebugMode) print("AuthService: Successfully updated preferences via backend.");
          return UserPreferences.fromJson(responseData['preferences']);
        } else {
          throw Exception('Preferences data not found in backend response.');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update preferences (${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) print("AuthService: Error calling custom backend for preferences: $e");
      throw Exception('Failed to update preferences: ${e.toString()}');
    }
  }
}