// lib/services/chat_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
// Removed unused import: import '../models/chat_message.dart';

class ChatService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  // Send a message to the AI chat assistant
  Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      if (kDebugMode) print('ChatService: Sending message to API: $message');

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.chat}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': message}),
      );

      if (kDebugMode) print('ChatService: Response status code: ${response.statusCode}');
      // If you want to see the raw response body always:
      // if (kDebugMode) print('ChatService: Raw response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>; // Decode as Map

        // --- FIXED PARSING LOGIC ---
        final String? reply = responseData['reply'] as String?;
        final dynamic suggestionsData = responseData['suggestions']; // Get potential suggestions data

        List<String>? suggestionsList;
        if (suggestionsData != null && suggestionsData is List) {
          // Safely cast to List<String>
          suggestionsList = suggestionsData.whereType<String>().toList();
          if (suggestionsList.isEmpty) {
            suggestionsList = null; // Treat empty list as no suggestions
          }
        }

        if (kDebugMode) {
          print('ChatService: Received reply: ${reply ?? "N/A"}');
          print('ChatService: Received suggestions: ${suggestionsList?.toString() ?? "None"}');
        }

        // Return the NEW structure expected by ChatProvider
        return {
          'reply': reply ?? '', // Return empty string if reply is null
          'suggestions': suggestionsList, // This will be List<String>? (null if none)
        };
        // --- END OF FIXED PARSING LOGIC ---

      } else {
        if (kDebugMode) print('ChatService: Error response body: ${response.body}');
        // Try to parse error message, default if parsing fails
        String errorMessage = 'Failed to send message (Status code: ${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error']?['message'] != null) {
            errorMessage = errorData['error']['message'];
          }
        } catch (_) {
          // Ignore decoding error, use default message
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) print('ChatService: Exception occurred during sendMessage: $e');
      throw Exception('Failed to communicate with chat service: ${e.toString()}');
    }
  }
}