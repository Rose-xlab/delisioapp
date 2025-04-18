// services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/supabase_config.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';

class AuthService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  // Register a new user
  Future<User> signUp(String email, String password, String name) async {
    final response = await client.post(
      Uri.parse('$baseUrl${ApiConfig.signup}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'name': name,
      }),
    );

    if (response.statusCode == 201) {
      final responseData = json.decode(response.body);
      return User.fromJson(responseData['user']);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error']['message'] ?? 'Failed to sign up');
    }
  }

  // Sign in an existing user
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final response = await client.post(
      Uri.parse('$baseUrl${ApiConfig.signin}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return {
        'user': User.fromJson(responseData['user']),
        'session': responseData['session'],
      };
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error']['message'] ?? 'Failed to sign in');
    }
  }

  // Sign out current user
  Future<void> signOut(String token) async {
    await client.post(
      Uri.parse('$baseUrl${ApiConfig.signout}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  // Get current user profile
  Future<User> getCurrentUser(String token) async {
    final response = await client.get(
      Uri.parse('$baseUrl${ApiConfig.me}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return User.fromJson(responseData['user']);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error']['message'] ?? 'Failed to get user');
    }
  }

  // Update user preferences
  Future<UserPreferences> updatePreferences(String token, UserPreferences preferences) async {
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
      return UserPreferences.fromJson(responseData['preferences']);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error']['message'] ?? 'Failed to update preferences');
    }
  }
}