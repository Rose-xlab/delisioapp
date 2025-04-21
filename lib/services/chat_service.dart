// lib/services/chat_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat_message.dart'; // Now needed for the message history

class ChatService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  // Check if chat system is using queues
  // MODIFIED: Added optional token parameter
  Future<bool> isChatQueueActive({String? token}) async { // <-- Added {String? token}
    try {
      // Prepare headers
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      // Add token if available
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token'; // <-- Add the token here
        if (kDebugMode) print("ChatService: Sending token for /queue-status check.");
      } else {
        if (kDebugMode) print("ChatService: No token provided for /queue-status check.");
        // The backend will return 401 if it requires auth and no token is sent.
      }

      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.chat}/queue-status'),
        headers: headers, // <-- Use the prepared headers map
      );

      // Handle potential 401 (e.g., if token expired or invalid)
      if (response.statusCode == 401) {
        if (kDebugMode) print('ChatService: Received 401 Unauthorized for /queue-status. Assuming no queue access or invalid token.');
        return false; // Treat 401 as queue not active or accessible
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['isQueueActive'] == true;
      }

      if (kDebugMode) print('ChatService: Non-200/401 status (${response.statusCode}) checking queue status.');
      return false; // Default to no queue if endpoint returns other non-200 status
    } catch (e) {
      if (kDebugMode) print('Error checking chat queue status: $e');
      return false; // Default to no queue if error
    }
  }

  // Updated to include conversation ID and message history
  // MODIFIED: Added optional token parameter for potential future use or consistency
  Future<Map<String, dynamic>> sendMessage(
      String conversationId,
      String message,
      List<ChatMessage> previousMessages,
      {String? token} // <-- OPTIONAL: Added token here for consistency/future backend needs
      ) async {
    try {
      if (kDebugMode) {
        print('ChatService: Sending message to API with conversation history');
        print('ChatService: ConversationID: $conversationId');
        print('ChatService: Current message: $message');
        print('ChatService: Including ${previousMessages.length} previous messages for context');
      }

      // Format previous messages for the API
      final List<Map<String, String>> messageHistory = previousMessages.map((msg) => {
        'role': msg.type == MessageType.user ? 'user' : 'assistant',
        'content': msg.content
      }).toList();

      final payload = {
        'conversation_id': conversationId,
        'message': message,
        'message_history': messageHistory,
      };

      if (kDebugMode) {
        print('ChatService: Request payload: ${json.encode(payload)}');
      }

      // Prepare headers
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      // Add token if available (useful even for optionalAuth routes on backend)
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token'; // <-- Add the token here
        if (kDebugMode) print("ChatService: Sending token with POST /api/chat request.");
      } else {
        if (kDebugMode) print("ChatService: No token provided for POST /api/chat request.");
      }

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.chat}'),
        headers: headers, // <-- Use prepared headers
        body: json.encode(payload),
      );

      if (kDebugMode) print('ChatService: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>; // Decode as Map

        // --- FIXED PARSING LOGIC (Original, retained) ---
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

        // Return the structure expected by ChatProvider
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
          // Adjust error parsing based on actual backend error structure if needed
          if (errorData['error'] != null) {
            errorMessage = errorData['error'] is Map ? errorData['error']['message'] ?? errorData['error'].toString() : errorData['error'].toString();
          } else if (errorData['message'] != null) {
            errorMessage = errorData['message'].toString();
          }
        } catch (_) {
          // Ignore decoding error, use default message
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) print('ChatService: Exception occurred during sendMessage: $e');
      // Avoid duplicating the error message if it's already an Exception
      if (e is Exception) {
        throw Exception('Failed to communicate with chat service: ${e.toString().replaceFirst("Exception: ", "")}');
      } else {
        throw Exception('Failed to communicate with chat service: ${e.toString()}');
      }
    }
  }
}