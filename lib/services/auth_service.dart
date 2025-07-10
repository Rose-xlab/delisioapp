// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';

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

        final String userAppIdValue = const Uuid().v4();
        final profileData = {
          "id": user.id,
          "user_app_id": userAppIdValue,
        };

        if (kDebugMode) {
          debugPrint("AuthService: Attempting to UPSERT into profiles table: $profileData");
        }

        try {
          final profileResponse = await _supabase
              .from("profiles")
              .upsert(
            profileData,
            onConflict: 'id',
          )
              .select()
              .maybeSingle();

          if (kDebugMode) {
            debugPrint("AuthService: Profile created or updated successfully for user ${user.id}. Response data: ${profileResponse?.toString()}");
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

      } else { // This means response.user is null
        if (kDebugMode) {
          debugPrint("AuthService: Supabase auth.signUp call completed, but response.user is null. Session present: ${response.session != null}. This might indicate email confirmation is pending.");
        }
        // If email confirmation is required by your Supabase settings,
        // response.user and response.session might both be null until the email is confirmed.
        // This checks for that state or other unexpected issues where neither user nor session is established.
        if (response.session == null && response.user == null) {
          throw Exception("Supabase sign up did not return a user or session. This may be due to pending email confirmation or other issues. Please check your email or Supabase logs.");
        }
      }
    } on supabase.AuthException catch (e) {
      if (kDebugMode) debugPrint("AuthService: Supabase signUp AuthException: ${e.message}");
      throw Exception("Supabase authentication error: ${e.message}");
    } catch (e) {
      if (kDebugMode) debugPrint("AuthService: Supabase signUp generic error: $e");
      if (e.toString().contains("Failed to create/update user profile")) {
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
    if (kDebugMode) print("AuthService: Getting current user profile from custom backend via ${ApiConfig.me}...");
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
          if (kDebugMode) print("AuthService: User data key not found in backend response for getCurrentUser.");
          throw Exception('User data not found in backend response.');
        }
      } else {
        if (kDebugMode) print("AuthService: Failed to get user profile from backend. Status: ${response.statusCode}, Body: ${response.body}");
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? errorData['message'] ?? 'Failed to get user profile from backend (${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) print("AuthService: Error calling custom backend for user profile: $e");
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // --- Update User Preferences (via custom backend) ---
  Future<UserPreferences> updatePreferences(UserPreferences preferences) async {
    if (kDebugMode) print("AuthService: Updating preferences via custom backend using ${ApiConfig.preferences}...");
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
          if (kDebugMode) print("AuthService: Preferences data key not found in backend response for updatePreferences.");
          throw Exception('Preferences data not found in backend response.');
        }
      } else {
        if (kDebugMode) print("AuthService: Failed to update preferences. Status: ${response.statusCode}, Body: ${response.body}");
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? errorData['message'] ?? 'Failed to update preferences (${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) print("AuthService: Error calling custom backend for preferences: $e");
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to update preferences: ${e.toString()}');
    }
  }

  // --- Delete Account (via custom backend) ---
  Future<bool> deleteAccount() async {
    if (kDebugMode) print("AuthService: Attempting to delete account via custom backend using ${ApiConfig.deleteAccount}...");
    final token = _supabase.auth.currentSession?.accessToken;

    if (token == null) {
      if (kDebugMode) print("AuthService: No auth token found for deleteAccount.");
      throw Exception('Not authenticated. Cannot delete account.');
    }

    try {
      final response = await client.delete(
        Uri.parse('$baseUrl${ApiConfig.deleteAccount}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (kDebugMode) print("AuthService: Account successfully marked for deletion by backend.");
        return true;
      } else {
        String errorMessage = 'Failed to delete account';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error']?['message'] ?? errorData['message'] ?? 'Failed to delete account (${response.statusCode})';
        } catch (_) {
          errorMessage = 'Failed to delete account (${response.statusCode}). Invalid or empty error response from server.';
        }
        if (kDebugMode) print("AuthService: Account deletion failed from backend. Status: ${response.statusCode}, Message: $errorMessage, Body: ${response.body}");
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) print("AuthService: Error calling custom backend for account deletion: $e");
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred during account deletion: ${e.toString()}');
    }
  }
}