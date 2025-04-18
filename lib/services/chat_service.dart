// services/chat_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat_message.dart';

class ChatService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  // Send a message to the AI chat assistant
  Future<Map<String, dynamic>> sendMessage(String message) async {
    final response = await client.post(
      Uri.parse('$baseUrl${ApiConfig.chat}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'message': message,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return {
        'reply': responseData['reply'],
        'can_generate_recipe': responseData['can_generate_recipe'] ?? false,
        'suggested_recipe': responseData['suggested_recipe'],
      };
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error']['message'] ?? 'Failed to send message');
    }
  }
}