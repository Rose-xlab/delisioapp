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
    if (kDebugMode) print("AuthService: Attempting Supabase signUp...");
    try {

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        // Pass user metadata (like name) in the 'data' field
        data: {'name': name}, // Ensure 'name' matches your Supabase trigger/metadata key
      );

      
     


      //generate and add a unique user_app_id for revenuecat subscriptions

      final user = response.user;

      if( user  != null){

          const appId = Uuid();
         
          final profile = await _supabase.from("profiles").insert({
            "id":user.id,
            "user_app_id":appId,
          });

          debugPrint(profile);

      }

      

      

      if (kDebugMode) {
        debugPrint("AuthService: Supabase signUp successful. User: ${response.user?.id}, Session: ${response.session != null}");
        // Note: If email confirmation is enabled, response.session might be null initially.
        // The onAuthStateChange listener in AuthProvider will handle the final SIGNED_IN state.
      }

    } on supabase.AuthException catch (e) {
      // Catch specific Supabase auth errors
      if (kDebugMode) debugPrint("AuthService: Supabase signUp AuthException: ${e.message}");
      throw Exception(e.message); // Re-throw a generic exception for AuthProvider
    } catch (e) {
      // Catch any other errors
      if (kDebugMode) debugPrint("AuthService: Supabase signUp generic error: $e");
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
        // The onAuthStateChange listener in AuthProvider will handle updating the state.
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
  Future<void> signOut() async { // Token no longer needed as argument
    if (kDebugMode) print("AuthService: Attempting Supabase signOut...");
    try {
      await _supabase.auth.signOut();
      if (kDebugMode) print("AuthService: Supabase signOut successful.");
      // The onAuthStateChange listener in AuthProvider will handle clearing the state.
    } on supabase.AuthException catch (e) {
      // Sign out rarely fails unless network issue, but handle defensively
      if (kDebugMode) print("AuthService: Supabase signOut AuthException: ${e.message}");
      throw Exception(e.message);
    } catch (e) {
      if (kDebugMode) print("AuthService: Supabase signOut generic error: $e");
      throw Exception('An unexpected error occurred during sign out.');
    }
  }

  // --- Get Current User Profile (from custom backend) ---
  // Assumes your backend /api/auth/me returns detailed profile info,
  // potentially including data not in Supabase Auth metadata (like preferences)
  Future<User> getCurrentUser() async {
    if (kDebugMode) print("AuthService: Getting current user profile from custom backend...");
    // Get token from Supabase session
    final token = _supabase.auth.currentSession?.accessToken;

    if (token == null) {
      if (kDebugMode) print("AuthService: No auth token found for getCurrentUser.");
      throw Exception('Not authenticated'); // Or handle appropriately
    }

    try {
      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.me}'), // Uses custom API path
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Use Supabase token
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Assuming backend returns {'user': { ... user data ... }}
        if (responseData['user'] != null) {
          if (kDebugMode) print("AuthService: Successfully fetched user profile from backend.");
          // Uses User.fromJson (your custom model factory)
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
    // Get token from Supabase session
    final token = _supabase.auth.currentSession?.accessToken;

    if (token == null) {
      if (kDebugMode) print("AuthService: No auth token found for updatePreferences.");
      throw Exception('Not authenticated');
    }

    try {
      final response = await client.put(
        Uri.parse('$baseUrl${ApiConfig.preferences}'), // Uses custom API path
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Use Supabase token
        },
        body: json.encode(preferences.toJson()), // Send preferences data
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Assuming backend returns {'preferences': { ... prefs data ... }}
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