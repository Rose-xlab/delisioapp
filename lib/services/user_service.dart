// services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_preferences.dart';

class UserService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  // Get user preferences
  Future<UserPreferences?> getUserPreferences(String token) async {
    final response = await client.get(
      Uri.parse('$baseUrl${ApiConfig.me}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['user']['preferences'] != null) {
        return UserPreferences.fromJson(responseData['user']['preferences']);
      }
      return null;
    } else {
      return null;
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