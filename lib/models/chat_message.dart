// models/chat_message.dart
enum MessageType { user, ai }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool canGenerateRecipe;
  final String? suggestedRecipe;

  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.canGenerateRecipe = false,
    this.suggestedRecipe,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'],
      type: json['type'] == 'user' ? MessageType.user : MessageType.ai,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      canGenerateRecipe: json['can_generate_recipe'] ?? false,
      suggestedRecipe: json['suggested_recipe'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type == MessageType.user ? 'user' : 'ai',
      'timestamp': timestamp.toIso8601String(),
      'can_generate_recipe': canGenerateRecipe,
      'suggested_recipe': suggestedRecipe,
    };
  }
}