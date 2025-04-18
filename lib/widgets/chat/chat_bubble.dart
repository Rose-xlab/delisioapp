// widgets/chat/chat_bubble.dart
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onGenerateRecipe;

  const ChatBubble({
    Key? key,
    required this.message,
    this.onGenerateRecipe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == MessageType.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar (only for AI messages)
          if (!isUser)
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(
                Icons.restaurant,
                color: Colors.white,
              ),
            ),

          // Message content
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: isUser ? 40 : 12,
                right: isUser ? 0 : 40,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),

                  // Generate recipe button (only for AI messages with recipe suggestions)
                  if (!isUser && onGenerateRecipe != null && message.canGenerateRecipe)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton(
                        onPressed: onGenerateRecipe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        child: const Text('Generate Recipe'),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // User avatar (only for user messages)
          if (isUser)
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: const Icon(
                Icons.person,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}