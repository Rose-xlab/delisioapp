// lib/models/chat_message.dart
enum MessageType { user, ai }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  // Removed: canGenerateRecipe
  // Removed: suggestedRecipe
  // Added: suggestions list
  final List<String>? suggestions; // List of suggestion strings, null if none

  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.suggestions, // Add suggestions to constructor
  });

  // Optional: Update fromJson/toJson if you use them elsewhere,
  // though ChatProvider currently handles DB mapping internally.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<String>? parsedSuggestions;
    if (json['suggestions'] != null && json['suggestions'] is List) {
      // Ensure all elements are strings
      parsedSuggestions = List<String>.from(
          (json['suggestions'] as List).map((item) => item.toString())
      );
    }

    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? '',
      type: json['type'] == 'user' ? MessageType.user : MessageType.ai,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      suggestions: parsedSuggestions, // Assign parsed list
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type == MessageType.user ? 'user' : 'ai',
      'timestamp': timestamp.toIso8601String(),
      'suggestions': suggestions, // Include suggestions list
    };
  }
}