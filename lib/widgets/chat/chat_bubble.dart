// lib/widgets/chat/chat_bubble.dart
import 'package:flutter/material.dart';
import '../../models/chat_message.dart'; // Ensure this uses the updated model with 'suggestions'

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String suggestion)? onSuggestionSelected; // Callback for when a suggestion OR the fallback button is tapped

  const ChatBubble({
    Key? key,
    required this.message,
    this.onSuggestionSelected,
  }) : super(key: key);

  // Helper to check if AI text suggests a recipe contextually
  bool _aiMessageLooksLikeSuggestion(String text) {
    final lowerText = text.toLowerCase();
    // Add more keywords/patterns if needed
    final keywords = [
      'recipe?', // Explicitly asks if user wants recipe
      'would you like', // Offers something
      'recipe for',
      'make a',
      'how about',
      'you could make',
      'try making',
      'simple outline for',
      'here are a few ideas:',
      'here\'s a basic approach:',
    ];
    return keywords.any((keyword) => lowerText.contains(keyword));
  }

  // Helper to attempt extracting a recipe name from AI text (simple version)
  String? _extractRecipeNameFromText(String text) {
    // Look for capitalized words following suggestive phrases
    // This is basic and might need refinement
    final patterns = [
      // "outline for making a [Classic Margherita Pizza]"
      RegExp(r"making a ([A-Z][a-zA-Z\s]+(?: Pizza| Soup| Stir-Fry| Pasta| Bake| Cookies| Cake| Pie| Drink| Smoothie| Salad)?)", caseSensitive: false),
      // "proceed with this [Classic Margherita Pizza] recipe?"
      RegExp(r"proceed with this ([A-Z][a-zA-Z\s]+(?: Pizza| Soup| Stir-Fry| Pasta| Bake| Cookies| Cake| Pie| Drink| Smoothie| Salad)?) recipe", caseSensitive: false),
      // "How about a [Recipe Name]?"
      RegExp(r"how about (?:a |an )?([A-Z][a-zA-Z\s]+)(?:\?|\.|!)", caseSensitive: false),
      // Fallback: Find any capitalized sequence of 2+ words
      RegExp(r"([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)"),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        // Return the first captured group, cleaned up
        return match.group(1)?.trim().replaceAll(RegExp(r'[\.\?]$'), '').trim(); // Remove trailing punctuation
      }
    }
    return null; // No match found
  }


  @override
  Widget build(BuildContext context) {
    final isUser = message.type == MessageType.user;
    final bool hasSuggestions = message.suggestions != null && message.suggestions!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          if (!isUser)
            Padding( /* ... AI Avatar ... */
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar( backgroundColor: Theme.of(context).primaryColorLight, child: Icon( Icons.psychology_alt, color: Theme.of(context).primaryColorDark, size: 20,),),
            ),

          // Message content container
          Flexible(
            child: Container(
              margin: EdgeInsets.only(left: isUser ? 40 : 0, right: isUser ? 0 : 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message Text
                  Text( message.content, style: TextStyle( color: isUser ? Colors.white : Colors.black87, fontSize: 16,),),

                  // --- UPDATED: Suggestions or Fallback Button ---

                  // 1. Display ActionChips if suggestions list exists and is not empty
                  if (!isUser && hasSuggestions && onSuggestionSelected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Wrap(
                        spacing: 8.0, runSpacing: 4.0,
                        children: message.suggestions!.map((suggestion) {
                          return ActionChip(
                            label: Text(suggestion),
                            onPressed: () {
                              print('Suggestion chip tapped: $suggestion');
                              onSuggestionSelected!(suggestion);
                            },
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(color: Theme.of(context).primaryColor, fontSize: 14),
                            shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            tooltip: 'Generate recipe for $suggestion',
                          );
                        }).toList(),
                      ),
                    )
                  // 2. ELSE IF: It's an AI message, callback exists, BUT no suggestions list was provided...
                  //    Check if the text *looks* like it might be a recipe suggestion/offer
                  else if (!isUser && !hasSuggestions && onSuggestionSelected != null && _aiMessageLooksLikeSuggestion(message.content))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton.icon( // Show a single fallback button
                        icon: const Icon(Icons.restaurant_menu, size: 18),
                        label: const Text('Generate Recipe?'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14),
                          // Different style maybe?
                          // backgroundColor: Theme.of(context).colorScheme.secondary,
                          // foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        ),
                        onPressed: () {
                          // Attempt to extract a name from the text, or use a default
                          String fallbackQuery = _extractRecipeNameFromText(message.content) ?? "Suggested Recipe";
                          print('Fallback Generate Recipe button tapped, determined query: "$fallbackQuery"');
                          onSuggestionSelected!(fallbackQuery); // Call callback with extracted/default query
                        },
                      ),
                    )
                  // 3. ELSE: No button/chips needed
                  else
                    const SizedBox.shrink(), // Render nothing

                  // --- End of Suggestions/Fallback ---
                ],
              ),
            ),
          ),

          // User avatar
          if (isUser)
            Padding( /* ... User Avatar ... */
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar( backgroundColor: Colors.grey[300], child: const Icon(Icons.person, color: Colors.black54, size: 20,),),
            ),
        ],
      ),
    );
  }
}
