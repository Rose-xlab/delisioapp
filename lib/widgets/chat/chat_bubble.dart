// lib/widgets/chat/chat_bubble.dart
import 'package:flutter/material.dart';
import '../../models/chat_message.dart'; // Uses updated model

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  // Removed: onGenerateRecipe
  // Added: onSuggestionSelected callback
  final Function(String suggestion)? onSuggestionSelected;

  const ChatBubble({
    Key? key,
    required this.message,
    this.onSuggestionSelected, // Add new callback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == MessageType.user;
    // Determine if suggestions should be shown
    final bool hasSuggestions = !isUser &&
        message.suggestions != null &&
        message.suggestions!.isNotEmpty &&
        onSuggestionSelected != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0), // Reduced vertical padding
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          if (!isUser)
            Padding( // Add some padding to avatar
              padding: const EdgeInsets.only(right: 8.0, top: 4.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 20),
                radius: 16, // Slightly smaller avatar
              ),
            ),

          // Message Bubble Content
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: isUser ? 50 : 0, // Adjust margins
                right: isUser ? 8 : 50, // Adjust margins
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // Adjust padding
              decoration: BoxDecoration(
                color: isUser ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(18), // Slightly more rounded
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message Text
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15, // Adjust font size
                    ),
                  ),

                  // --- FIX: Display Suggestion Buttons/Chips ---
                  if (hasSuggestions)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0), // Add space above suggestions
                      child: Wrap( // Use Wrap to handle multiple buttons nicely
                        spacing: 8.0, // Horizontal space between chips
                        runSpacing: 4.0, // Vertical space between lines of chips
                        children: message.suggestions!.map((suggestion) {
                          return ActionChip(
                            avatar: Icon(Icons.lightbulb_outline, size: 16, color: isUser ? Colors.white70 : Theme.of(context).primaryColor),
                            label: Text(suggestion),
                            labelStyle: TextStyle(
                                color: isUser ? Colors.white : Theme.of(context).primaryColorDark,
                                fontSize: 13
                            ),
                            onPressed: () {
                              print("Suggestion chip tapped: $suggestion");
                              onSuggestionSelected!(suggestion); // Use the new callback
                            },
                            backgroundColor: isUser ? Theme.of(context).primaryColorLight.withOpacity(0.5) : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                                side: BorderSide(
                                    color: isUser ? Colors.white54 : Theme.of(context).primaryColor.withOpacity(0.5),
                                    width: 1
                                )
                            ),
                          );
                          // --- Alternative: OutlinedButton ---
                          // return OutlinedButton(
                          //   onPressed: () => onSuggestionSelected!(suggestion),
                          //   child: Text(suggestion),
                          //   style: OutlinedButton.styleFrom(
                          //      foregroundColor: isUser ? Colors.white : Theme.of(context).primaryColor,
                          //      side: BorderSide(color: isUser ? Colors.white70 : Theme.of(context).primaryColor),
                          //      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          //      textStyle: TextStyle(fontSize: 13)
                          //   ),
                          // );
                          // --- End Alternative ---
                        }).toList(),
                      ),
                    ),
                  // --- End of FIX ---
                ],
              ),
            ),
          ),

          // User avatar
          if (isUser)
            Padding( // Add some padding to avatar
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: CircleAvatar(
                backgroundColor: Colors.blueGrey[100],
                child: const Icon(Icons.person_outline, color: Colors.blueGrey, size: 20),
                radius: 16, // Slightly smaller avatar
              ),
            ),
        ],
      ),
    );
  }
}