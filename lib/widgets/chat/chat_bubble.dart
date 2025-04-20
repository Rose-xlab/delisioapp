// lib/widgets/chat/chat_bubble.dart
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';

// Define action types for the chat bubble
enum ChatActionType {
  generateRecipe,  // Show "Generate recipe" button
  seeRecipe,       // Show "See recipe" button - used for recipes that are already generated
  none             // Don't show any action button
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String suggestion, bool generateRecipe)? onSuggestionSelected; // Updated to include generateRecipe flag
  final Function()? onSeeRecipe;
  final ChatActionType actionType;
  final String? recipeName; // Add to store the recipe name associated with this message

  const ChatBubble({
    Key? key,
    required this.message,
    this.onSuggestionSelected,
    this.onSeeRecipe,
    this.actionType = ChatActionType.none,
    this.recipeName,
  }) : super(key: key);

  // Helper to check if AI text suggests a recipe contextually
  bool _aiMessageLooksLikeSuggestion(String text) {
    final lowerText = text.toLowerCase();
    final keywords = [
      'recipe?',
      'would you like',
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

  // Helper to check if message is a recipe description
  bool _isRecipeDescription(String text) {
    final lowerText = text.toLowerCase();
    // This message mentions ingredients and has bullet points
    return (lowerText.contains("ingredient") || lowerText.contains("you'll need")) &&
        (text.contains("- ") || text.contains("• "));
  }

  // Helper to attempt extracting a recipe name from AI text
  String? _extractRecipeNameFromText(String text) {
    final patterns = [
      RegExp(r"making a ([A-Z][a-zA-Z\s]+(?: Pizza| Soup| Stir-Fry| Pasta| Bake| Cookies| Cake| Pie| Drink| Smoothie| Salad)?)", caseSensitive: false),
      RegExp(r"proceed with this ([A-Z][a-zA-Z\s]+(?: Pizza| Soup| Stir-Fry| Pasta| Bake| Cookies| Cake| Pie| Drink| Smoothie| Salad)?) recipe", caseSensitive: false),
      RegExp(r"how about (?:a |an )?([A-Z][a-zA-Z\s]+)(?:\?|\.|!)", caseSensitive: false),
      RegExp(r"([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)"),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.trim().replaceAll(RegExp(r'[\.\?]$'), '').trim();
      }
    }
    return null;
  }

  // Extract recipe name from description
  String _getRecipeNameFromDescription(String content) {
    // Try to extract from first line (usually "Recipe Name: Description")
    if (content.contains(":")) {
      return content.split(":")[0].trim();
    }

    // If no colon, try first line
    final firstLine = content.split("\n").first.trim();
    if (firstLine.length > 5 && firstLine.length < 60) {
      return firstLine;
    }

    // Fallback to stored recipeName or default
    return recipeName ?? "This Recipe";
  }

  // Enhanced helper function to render formatted content with styled lists
  Widget _buildFormattedContent(String content, bool isUser, BuildContext context) {
    final List<String> lines = content.split('\n');

    if (lines.length <= 1) {
      return Text(
        content,
        style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          fontSize: 16,
          height: 1.4, // Slightly increased line height for better readability
        ),
      );
    }

    // Determine if this message contains a list (ingredients or steps)
    bool containsList = lines.any((line) =>
    line.trim().startsWith('-') ||
        line.trim().startsWith('•') ||
        RegExp(r'^\d+\.').hasMatch(line.trim()));

    // If it contains a list, add a container with border and background
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First render any header text before the list begins
        if (lines.first.isNotEmpty && !lines.first.trim().startsWith('-') &&
            !lines.first.trim().startsWith('•') && !RegExp(r'^\d+\.').hasMatch(lines.first.trim()))
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              lines.first,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),

        // Then build the list items with enhanced styling
        if (containsList)
          Container(
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).primaryColor.withOpacity(0.3)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isUser
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey[300]!,
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            margin: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.skip(lines.first.contains(':') ? 1 : 0).map((line) {
                if (line.isEmpty) return const SizedBox(height: 4); // Small space for empty lines

                bool isBulletItem = line.trim().startsWith('-') || line.trim().startsWith('•');
                bool isNumberedItem = RegExp(r'^\d+\.').hasMatch(line.trim());

                if (isBulletItem || isNumberedItem) {
                  // Extract prefix and content for styled list items
                  String prefix = '';
                  String content = line;

                  if (isBulletItem) {
                    prefix = line.trim().startsWith('-') ? '• ' : '• '; // Convert all to bullet points
                    content = line.substring(line.indexOf(RegExp(r'[-•]')) + 1).trim();
                  } else if (isNumberedItem) {
                    final match = RegExp(r'^(\d+\.)').firstMatch(line.trim());
                    if (match != null) {
                      prefix = match.group(0)! + ' ';
                      content = line.substring(line.indexOf(RegExp(r'\d+\.')) + match.group(0)!.length).trim();
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // List marker (bullet or number)
                        SizedBox(
                          width: 24,
                          child: Text(
                            prefix,
                            style: TextStyle(
                              color: isUser ? Colors.white : Theme.of(context).primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // List item content
                        Expanded(
                          child: Text(
                            content,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Regular non-list text line
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  );
                }
              }).toList(),
            ),
          ),

        // Add any text that comes after the list
        if (lines.last.isNotEmpty &&
            !lines.last.trim().startsWith('-') &&
            !lines.last.trim().startsWith('•') &&
            !RegExp(r'^\d+\.').hasMatch(lines.last.trim()) &&
            lines.first != lines.last &&
            !containsList)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              lines.last,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == MessageType.user;
    final bool hasSuggestions = message.suggestions != null && message.suggestions!.isNotEmpty;
    // Check if this message might be a recipe description
    final bool isRecipeDescription = !isUser && _isRecipeDescription(message.content);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColorLight,
                child: Icon(
                  Icons.psychology_alt,
                  color: Theme.of(context).primaryColorDark,
                  size: 20,
                ),
              ),
            ),

          // Message content container
          Flexible(
            child: Container(
              margin: EdgeInsets.only(left: isUser ? 40 : 0, right: isUser ? 0 : 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                // Add subtle shadow for depth
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message Text - Using the enhanced formatted content widget
                  _buildFormattedContent(message.content, isUser, context),

                  // Generate Recipe Button for Recipe Descriptions
                  if (isRecipeDescription)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restaurant_menu, size: 18),
                        label: const Text('Generate Full Recipe'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14),
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: () {
                          String recipeName = _getRecipeNameFromDescription(message.content);
                          print('Generate Full Recipe pressed for: $recipeName');
                          onSuggestionSelected?.call(recipeName, true);
                        },
                      ),
                    ),

                  // Action Buttons (updated)
                  if (!isUser && actionType == ChatActionType.seeRecipe && onSeeRecipe != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restaurant_menu, size: 18),
                        label: const Text('See Recipe'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        onPressed: onSeeRecipe,
                      ),
                    )
                  else if (!isUser && hasSuggestions && onSuggestionSelected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 6.0,
                        children: message.suggestions!.map((suggestion) {
                          return ActionChip(
                            label: Text(suggestion),
                            onPressed: () {
                              print('Suggestion chip tapped: $suggestion');
                              // Pass false for generate flag - we want description first
                              onSuggestionSelected!(suggestion, false);
                            },
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(color: Theme.of(context).primaryColor, fontSize: 14),
                            shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            tooltip: suggestion.toLowerCase() == "something else?"
                                ? 'Show more suggestions'
                                : 'Learn more about $suggestion',  // Updated tooltip
                          );
                        }).toList(),
                      ),
                    )
                  else if (!isUser && actionType == ChatActionType.generateRecipe && onSuggestionSelected != null && _aiMessageLooksLikeSuggestion(message.content))
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.restaurant_menu, size: 18),
                          label: const Text('Generate Recipe'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          onPressed: () {
                            String fallbackQuery = _extractRecipeNameFromText(message.content) ?? "Suggested Recipe";
                            print('Generate Recipe button tapped, determined query: "$fallbackQuery"');
                            onSuggestionSelected!(fallbackQuery, true);
                          },
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                ],
              ),
            ),
          ),

          // User avatar
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                backgroundColor: Colors.grey[300],
                child: const Icon(
                  Icons.person,
                  color: Colors.black54,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}