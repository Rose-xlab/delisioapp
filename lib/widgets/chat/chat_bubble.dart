// lib/widgets/chat/chat_bubble.dart
import 'package:flutter/material.dart';
import '../../models/chat_message.dart'; // Ensure this has the new fields/types

// Removed: ChatActionType enum - no longer needed

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String suggestion, bool generateRecipe)? onSuggestionSelected;
  final Function(String recipeId)? onViewRecipePressed; // NEW: Callback for viewing recipe

  // Removed: actionType, onSeeRecipe, recipeName - Replaced by message.type checks

  const ChatBubble({
    Key? key,
    required this.message,
    this.onSuggestionSelected,
    this.onViewRecipePressed, // NEW
  }) : super(key: key);

  // --- Helpers for checking message content ---
  bool _aiMessageLooksLikeSuggestion(String text) {
    final lowerText = text.toLowerCase();
    final keywords = [
      'recipe?', 'would you like', 'recipe for', 'make a', 'how about',
      'you could make', 'try making', 'simple outline for',
      'here are a few ideas:', 'here\'s a basic approach:',
    ];
    return keywords.any((keyword) => lowerText.contains(keyword));
  }

  bool _isRecipeDescription(String text) {
    final lowerText = text.toLowerCase();
    // Check for keywords AND list formatting
    return (lowerText.contains("ingredient") || lowerText.contains("you'll need") || lowerText.contains("instruction")) &&
        (text.contains("- ") || text.contains("• ") || RegExp(r'\b\d+\.\s').hasMatch(text)); // Check for numbered list too
  }

  String? _extractRecipeNameFromText(String text) {
    // Try more specific patterns first
    final patterns = [
      RegExp(r"making a ([A-Z][a-zA-Z\s'-]+(?: Pizza| Soup| Stir-Fry| Pasta| Bake| Cookies| Cake| Pie| Drink| Smoothie| Salad| Casserole| Bread| Dip))", caseSensitive: false),
      RegExp(r"proceed with this ([A-Z][a-zA-Z\s'-]+(?: Pizza| Soup| Stir-Fry| Pasta| Bake| Cookies| Cake| Pie| Drink| Smoothie| Salad| Casserole| Bread| Dip)) recipe", caseSensitive: false),
      RegExp(r"recipe for ([A-Z][a-zA-Z\s'-]+)(?:\?|\.|!)", caseSensitive: false),
      RegExp(r"how about (?:a |an )?([A-Z][a-zA-Z\s'-]+)(?:\?|\.|!)", caseSensitive: false),
      // More general pattern as fallback
      RegExp(r"([A-Z][a-z]+(?:\s+[A-Z]?[a-zA-Z'-]+)*)"),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1 && match.group(1) != null) {
        // Clean up potential trailing punctuation or the word "recipe"
        String potentialName = match.group(1)!.trim()
            .replaceAll(RegExp(r'[\.\?]$'), '')
            .replaceAll(RegExp(r'\s+recipe$', caseSensitive: false), '')
            .trim();
        // Basic validation: avoid overly short or long names
        if (potentialName.length > 3 && potentialName.length < 80) {
          return potentialName;
        }
      }
    }
    return null;
  }

  String _getRecipeNameFromDescription(String content) {
    // Try to extract from first line if it looks like "Name: ..." or just "Name"
    final lines = content.split('\n');
    if (lines.isNotEmpty) {
      final firstLine = lines.first.trim();
      if (firstLine.contains(":")) {
        final potentialName = firstLine.split(":")[0].trim();
        if (potentialName.isNotEmpty && potentialName.length < 80) return potentialName;
      }
      // Check if first line looks like a title (capitalized words, reasonable length)
      if (RegExp(r"^[A-Z][a-zA-Z\s'-]+$").hasMatch(firstLine) && firstLine.length > 3 && firstLine.length < 80) {
        return firstLine;
      }
    }
    // Fallback using the recipe title stored in the message if available (should be for recipeResult)
    return message.recipeTitle ?? "This Recipe";
  }
  // --- End Helpers ---


  // Helper function to render formatted content with styled lists
  Widget _buildFormattedContent(String content, MessageType type, BuildContext context) {
    final isUser = type == MessageType.user;
    final Color textColor = isUser ? Colors.white : Colors.black87;
    final List<String> lines = content.split('\n');

    // Special case for simple messages or placeholder
    if (lines.length <= 1 || type == MessageType.recipePlaceholder) {
      return Text(
        content,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          height: 1.4,
          fontStyle: type == MessageType.recipePlaceholder ? FontStyle.italic : FontStyle.normal,
        ),
      );
    }

    bool containsList = lines.any((line) =>
    line.trim().startsWith('-') ||
        line.trim().startsWith('•') ||
        RegExp(r'^\d+\.\s').hasMatch(line.trim())); // Look for number followed by dot and space

    // RichText approach for more complex formatting if needed later
    // For now, continue with Column + Container for list styling

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Render header/intro text before the list
        if (lines.first.isNotEmpty && !lines.first.trim().startsWith('-') &&
            !lines.first.trim().startsWith('•') && !RegExp(r'^\d+\.\s').hasMatch(lines.first.trim()))
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              lines.first,
              style: TextStyle( color: textColor, fontSize: 16, height: 1.4),
            ),
          ),

        // Build the list items with enhanced styling inside a container
        if (containsList)
          Container(
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).primaryColor.withOpacity(0.3)
                  : Colors.grey[50], // Lighter background for list
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
              children: lines.skip(lines.first.contains(':') && !containsList ? 1 : 0).map((line) { // Skip first line if it's a title before list starts
                if (line.trim().isEmpty) return const SizedBox(height: 4); // Small space for empty lines

                bool isBulletItem = line.trim().startsWith('- ') || line.trim().startsWith('• ');
                RegExp numberedListRegex = RegExp(r'^(\d+)\.\s+(.*)'); // Matches "1. Text"
                final numberedMatch = numberedListRegex.firstMatch(line.trim());
                bool isNumberedItem = numberedMatch != null;

                if (isBulletItem || isNumberedItem) {
                  String prefix = '';
                  String itemContent = line.trim();

                  if (isBulletItem) {
                    prefix = '• ';
                    itemContent = line.trim().substring(2).trim(); // Get content after "- " or "• "
                  } else if (isNumberedItem) {
                    prefix = '${numberedMatch!.group(1)!}. ';
                    itemContent = numberedMatch.group(2)!.trim(); // Get content after "1. "
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // List marker (bullet or number)
                        SizedBox(
                          width: 24, // Fixed width for alignment
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
                            itemContent,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Regular non-list text line within the list block (e.g., notes)
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Text(
                      line, // Keep original indentation if any
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  );
                }
              }).toList(),
            ),
          ),

        // Render any text that comes *after* the list block
        if (lines.length > 1 &&
            lines.last.isNotEmpty &&
            !lines.last.trim().startsWith('-') &&
            !lines.last.trim().startsWith('•') &&
            !RegExp(r'^\d+\.\s').hasMatch(lines.last.trim()) &&
            containsList) // Only add trailing text if a list was present
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              lines.last,
              style: TextStyle(color: textColor, fontSize: 16, height: 1.4),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.type == MessageType.user;
    final bool hasSuggestions = message.suggestions != null && message.suggestions!.isNotEmpty;
    final bool isRecipeResult = message.type == MessageType.recipeResult;
    final bool isRecipePlaceholder = message.type == MessageType.recipePlaceholder;
    final bool isAi = message.type == MessageType.ai;
    // Check if this AI message looks like a recipe description that could be generated
    final bool isPotentialRecipeDescription = isAi && _isRecipeDescription(message.content);

    // Determine avatar and alignment based on message type
    final bool showAiAvatar = !isUser; // Show avatar for AI, placeholder, and result
    final MainAxisAlignment alignment = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;
    // Determine background color based on type
    Color backgroundColor;
    Color iconColor;
    Color iconBgColor;

    if (isUser) {
      backgroundColor = Theme.of(context).primaryColor;
      iconColor = Colors.black54; // Not used directly here, but for consistency
      iconBgColor = Colors.grey[300]!; // Not used directly here
    } else if (isRecipeResult || isRecipePlaceholder) {
      backgroundColor = Colors.green[50]!; // Distinct color for recipe messages
      iconColor = Colors.green[800]!;
      iconBgColor = Colors.green[100]!;
    } else { // AI message
      backgroundColor = Colors.grey[200]!;
      iconColor = Theme.of(context).primaryColorDark;
      iconBgColor = Theme.of(context).primaryColorLight;
    }
    // Determine text color
    final Color textColor = isUser ? Colors.white : Colors.black87;


    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (AI, Placeholder, Result)
          if (showAiAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundColor: iconBgColor,
                child: Icon(
                  isRecipeResult ? Icons.restaurant_menu : (isRecipePlaceholder ? Icons.hourglass_top : Icons.psychology_alt),
                  color: iconColor,
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
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [ // Subtle shadow for depth
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
                  _buildFormattedContent(message.content, message.type, context),

                  // --- NEW: Recipe Result Button ---
                  if (isRecipeResult && message.recipeId != null && onViewRecipePressed != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('View Recipe'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14),
                          backgroundColor: Colors.green, // Button color matching bubble
                          foregroundColor: Colors.white,
                          elevation: 1, // Add slight elevation
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => onViewRecipePressed!(message.recipeId!),
                      ),
                    ),

                  // --- Existing Generate Button (for AI descriptions) ---
                  // Show this button only if it's an AI message that looks like a recipe description
                  if (isPotentialRecipeDescription && onSuggestionSelected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restaurant_menu, size: 18),
                        label: const Text('Generate Full Recipe'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14),
                          backgroundColor: Theme.of(context).colorScheme.secondary, // Use theme secondary color
                          foregroundColor: Theme.of(context).colorScheme.onSecondary, // Use theme onSecondary color
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          // Extract a name from the description to use as the query
                          String recipeName = _getRecipeNameFromDescription(message.content);
                          print('Generate Full Recipe pressed for (from description): $recipeName');
                          onSuggestionSelected!(recipeName, true); // True flag indicates generate
                        },
                      ),
                    ),

                  // --- Existing Suggestions (for standard AI messages) ---
                  // Show suggestions only for standard AI messages, not placeholders or results
                  if (isAi && hasSuggestions && onSuggestionSelected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Wrap(
                        spacing: 8.0, // Horizontal space between chips
                        runSpacing: 6.0, // Vertical space between rows of chips
                        children: message.suggestions!.map((suggestion) {
                          return ActionChip(
                            label: Text(suggestion),
                            onPressed: () {
                              print('Suggestion chip tapped: $suggestion');
                              // Pass false for generate flag - user wants to discuss/describe first
                              onSuggestionSelected!(suggestion, false);
                            },
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(color: Theme.of(context).primaryColor, fontSize: 14),
                            shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            tooltip: suggestion.toLowerCase() == "something else?"
                                ? 'Ask for different options'
                                : 'Learn more about "$suggestion"', // Updated tooltip
                            elevation: 0.5, // Slight elevation for chips
                          );
                        }).toList(),
                      ),
                    ),

                  // --- Optional: Loading indicator inside placeholder bubble ---
                  if (isRecipePlaceholder)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green[800])),
                          const SizedBox(width: 8),
                          Text("Generating...", style: TextStyle(color: Colors.green[800], fontStyle: FontStyle.italic, fontSize: 13)),
                        ],
                      ),
                    ),
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
                child: const Icon( Icons.person, color: Colors.black54, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}