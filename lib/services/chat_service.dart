import 'dart:convert';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat_message.dart'; // Now needed for the message history

class ChatService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  Future<bool> isChatQueueActive({String? token}) async {
    try {
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        if (kDebugMode) print("ChatService: Sending token for /queue-status check.");
      } else {
        if (kDebugMode) print("ChatService: No token provided for /queue-status check.");
      }

      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.chat}/queue-status'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        if (kDebugMode) print('ChatService: Received 401 Unauthorized for /queue-status. Assuming no queue access or invalid token.');
        return false;
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['isQueueActive'] == true;
      } else if (response.statusCode == 429) {
        if (kDebugMode) print('ChatService: Received 429 Too Many Requests for /queue-status.');
        return false;
      }

      if (kDebugMode) print('ChatService: Non-200/401/429 status (${response.statusCode}) checking queue status. Body: ${response.body}');
      return false;
    } catch (e) {
      if (kDebugMode) print('Error checking chat queue status: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> sendMessage(
      String conversationId,
      String message,
      List<ChatMessage> previousMessages,
      {String? token}
      ) async {
    try {
      if (kDebugMode) {
        print('ChatService: Sending message to API with conversation history');
        print('ChatService: ConversationID: $conversationId');
        print('ChatService: Current message: $message');
        print('ChatService: Including ${previousMessages.length} previous messages for context');
      }

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

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        if (kDebugMode) print("ChatService: Sending token with POST ${ApiConfig.chat} request.");
      } else {
        if (kDebugMode) print("ChatService: No token provided for POST ${ApiConfig.chat} request.");
      }

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.chat}'),
        headers: headers,
        body: json.encode(payload),
      );

      if (kDebugMode) print('ChatService: Response status code: ${response.statusCode}');
      final responseBody = response.body;
      Map<String, dynamic> responseData;

      try {
        responseData = json.decode(responseBody) as Map<String, dynamic>;
      } catch (e) {
        if (kDebugMode) print('ChatService: Failed to decode JSON response body: $responseBody for status: ${response.statusCode}');
        if (response.statusCode == 429) {
          return <String, dynamic>{ // Explicitly type the map
            'reply': 'Too many requests. Please try again in a moment.',
            'error_type': 'RATE_LIMITED_INVALID_BODY', // More specific error
            'retry_after': 30,
            'status_code': response.statusCode,
            'suggestions': null,
          };
        }
        throw Exception('Server returned a non-JSON response (Status: ${response.statusCode}). Body: $responseBody');
      }

      if (response.statusCode == 200) {
        final String? reply = responseData['reply'] as String?;
        final dynamic suggestionsData = responseData['suggestions'];
        List<String>? suggestionsList;
        if (suggestionsData != null && suggestionsData is List) {
          suggestionsList = suggestionsData.whereType<String>().toList();
          if (suggestionsList.isEmpty) suggestionsList = null;
        }

        if (kDebugMode) {
          print('ChatService: Received reply: ${reply ?? "N/A"}');
          print('ChatService: Received suggestions: ${suggestionsList?.toString() ?? "None"}');
        }

        return <String, dynamic>{ // Explicitly type the map
          'reply': reply ?? '',
          'suggestions': suggestionsList,
          'status_code': 200,
        };
      } else if (response.statusCode == 429) {
        if (kDebugMode) print('ChatService: Received 429 Too Many Requests. Parsed Body: $responseData');
        int retryAfterSeconds = responseData['retry_after'] as int? ??
            (responseData['error'] is Map ? responseData['error']['retryAfter'] as int? : null) ??
            30;
        String userMessage = (responseData['reply'] as String?) ??
            (responseData['error'] is Map ? responseData['error']['message'] as String? : null) ??
            (responseData['message'] as String?) ??
            'Too many requests. Please try again later.';
        String errorType = (responseData['error_type'] as String?) ??
            (responseData['error'] is Map ? (responseData['error']['type'] as String? ?? 'RATE_LIMITED') : 'RATE_LIMITED');
        if (userMessage.toLowerCase().contains("ai repl") || userMessage.toLowerCase().contains("limit")) {
          errorType = 'AI_REPLY_LIMIT_REACHED';
        }

        return <String, dynamic>{ // Explicitly type the map
          'reply': userMessage,
          'error_type': errorType,
          'retry_after': retryAfterSeconds,
          'status_code': response.statusCode,
          'suggestions': (responseData['suggestions'] as List?)?.whereType<String>().toList() ?? null,
        };
      } else { // Handle other non-200 error codes
        if (kDebugMode) print('ChatService: Error response body for status ${response.statusCode}: $responseBody');
        String userFacingErrorMessage = responseData['reply'] as String? ??
            "An error occurred with the chat service. Please try again.";
        String technicalError = (responseData['error_type'] as String?) ??
            (responseData['error'] is Map ? responseData['error']['message'] as String? : null) ??
            (responseData['message'] as String?) ??
            'Failed to process message (Status code: ${response.statusCode})';
        return <String, dynamic>{ // Explicitly type the map
          'reply': userFacingErrorMessage,
          'error_type': technicalError,
          'status_code': response.statusCode,
          'suggestions': (responseData['suggestions'] as List?)?.whereType<String>().toList() ?? null,
        };
      }
    } catch (e) { // This catch block is for network errors or other unexpected issues before/during the request, or if JSON parsing failed hard from the try block above.
      if (kDebugMode) print('ChatService: Exception occurred during sendMessage processing: $e');
      String errorMessage = e.toString().replaceFirst("Exception: ", "");

      // MODIFIED: Ensure this catch block also returns Map<String, dynamic>
      return <String, dynamic>{
        'reply': 'Failed to communicate with chat service. Please check your connection and try again.',
        'error_type': 'COMMUNICATION_ERROR',
        'status_code': 503, // Service Unavailable or a client-side error status
        'suggestions': null,
        // No retry_after for pure communication errors generally
      };
    }
  }
}