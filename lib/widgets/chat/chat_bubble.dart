//chat_bubble.dart
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

  // Helper function to render formatted content with styled lists - UPDATED
  Widget _buildFormattedContent(String content, MessageType type, BuildContext context) {
    final isUser = type == MessageType.user;
    final Color textColor = isUser ? Colors.white : Colors.black87;
    final List<String> lines = content.split('\n');

    // Handle empty content
    if (lines.isEmpty || content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    // Special case for simple single-line messages or placeholders
    if (lines.length == 1 || type == MessageType.recipePlaceholder) {
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

    List<Widget> childrenWidgets = [];
    int linesToSkipForMainProcessing = 0;

    // 1. Check if the first line should be treated as a distinct header paragraph
    bool firstLineIsPotentiallyHeader = lines.first.isNotEmpty &&
        !lines.first.trim().startsWith('-') &&
        !lines.first.trim().startsWith('•') &&
        !RegExp(r'^\d+\.\s').hasMatch(lines.first.trim());

    if (firstLineIsPotentiallyHeader) {
      childrenWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0), // Matches original header bottom padding
          child: Text(
            lines.first,
            style: TextStyle(color: textColor, fontSize: 16, height: 1.4), // Matches original header style
          ),
        ),
      );
      linesToSkipForMainProcessing = 1;
    }

    // 2. Prepare the lines for the main content processing (after the optional header)
    List<String> linesForMainContent = lines.sublist(linesToSkipForMainProcessing);

    // Skip any leading empty lines in what's considered main content
    // This handles structures like "Header\n\nContent"
    int leadingEmptyLinesInMain = 0;
    for (String line in linesForMainContent) {
      if (line.trim().isEmpty) {
        leadingEmptyLinesInMain++;
      } else {
        break;
      }
    }
    // If a header was rendered and there were empty lines (like \n\n) immediately after it,
    // the natural spacing from the header's bottom padding and the next element's top margin/padding
    // will create the gap. No explicit SizedBox needed here unless more spacing is desired.
    linesForMainContent = linesForMainContent.sublist(leadingEmptyLinesInMain);


    // 3. Process the (remaining) main content lines
    if (linesForMainContent.isNotEmpty) {
      bool containsListInMainContent = linesForMainContent.any((line) =>
      line.trim().startsWith('-') ||
          line.trim().startsWith('•') ||
          RegExp(r'^\d+\.\s').hasMatch(line.trim()));

      if (containsListInMainContent) {
        childrenWidgets.add(
          Container(
            decoration: BoxDecoration( // Styling copied from original
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
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), // Copied from original
            margin: const EdgeInsets.only(top: 4.0, bottom: 8.0), // Copied from original
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: linesForMainContent.map((line) {
                // Handle empty lines within this block, similar to original
                if (line.trim().isEmpty) {
                  return const SizedBox(height: 4.0); // Consistent with original empty line handling
                }

                bool isBulletItem = line.trim().startsWith('- ') || line.trim().startsWith('• ');
                RegExp numberedListRegex = RegExp(r'^(\d+)\.\s+(.*)');
                final numberedMatch = numberedListRegex.firstMatch(line.trim());
                bool isNumberedItem = numberedMatch != null;

                if (isBulletItem || isNumberedItem) {
                  String prefix = '';
                  String itemContent = line.trim();

                  if (isBulletItem) {
                    prefix = '• ';
                    itemContent = line.trim().substring(2).trim();
                  } else if (isNumberedItem) {
                    prefix = '${numberedMatch!.group(1)!}. ';
                    itemContent = numberedMatch.group(2)!.trim();
                  }

                  return Padding( // Structure and styling copied from original
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox( // Copied from original
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
                        Expanded( // Copied from original
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
                  // Regular non-list text line (e.g., "Main Ingredients:", or notes within the list block)
                  return Padding( // Copied from original
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Text(
                      line,
                      style: TextStyle( // Style copied from original for this case
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
        );
      } else {
        // No list in main content, render linesForMainContent as plain paragraphs
        for (final line in linesForMainContent) {
          if (line.trim().isNotEmpty) {
            childrenWidgets.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0), // Spacing for paragraphs
                  child: Text(
                    line,
                    style: TextStyle(color: textColor, fontSize: 16, height: 1.4), // Style consistent with original header/non-list text
                  ),
                )
            );
          } else if (childrenWidgets.isNotEmpty && childrenWidgets.last is! SizedBox) {
            // Optionally add SizedBox for intentional empty lines between paragraphs
            // childrenWidgets.add(const SizedBox(height: 4.0));
          }
        }
      }
    }

    // Fallback if, after all processing, no widgets were generated but original content was not empty.
    // This can happen if content was just whitespace, or if logic paths didn't add anything.
    // The initial `content.trim().isEmpty` check should handle most purely empty cases.
    if (childrenWidgets.isEmpty && content.trim().isNotEmpty) {
      return Text(
        content.trim(), // Render trimmed original content as a last resort
        style: TextStyle(color: textColor, fontSize: 16, height: 1.4),
      );
    }
    // If truly nothing to show (e.g. original content was only whitespace lines that got trimmed out)
    if (childrenWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: childrenWidgets,
    );
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
    // final Color textColor = isUser ? Colors.white : Colors.black87; // Defined in _buildFormattedContent


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
                backgroundColor: colorScheme.primary,
                child: Icon(
                  isRecipeResult ? Icons.restaurant_menu : (isRecipePlaceholder ? Icons.hourglass_top : Icons.auto_awesome),
                  color:Colors.white,
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
                color: Colors.white,
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
                        label: const Text('Generate Full Recipe With Images'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14),
                          backgroundColor: Theme.of(context).colorScheme.primary, // Use theme secondary color
                          foregroundColor: Colors.white, // Use theme onSecondary color
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

          // Custom leading widget for the red vertical line
          avatar: Container(
            width: 4.0, // Width of the red line
            height: 24.0, // Height of the red line, adjust as needed
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 248, 132, 123), // Red color for the line
              borderRadius: BorderRadius.circular(2.0), // Slightly rounded ends for the line
            ),
          ),
          label: Text(
            suggestion,
            style: const TextStyle(
              color: Colors.grey, // Grey text color as in the image
              fontSize: 16, // Adjust font size as needed
              fontWeight: FontWeight.normal, // Regular font weight
            ),
          ),
          onPressed: () {
            print('Suggestion chip tapped: $suggestion');
            // Pass false for generate flag - user wants to discuss/describe first
            onSuggestionSelected!(suggestion, false);
          },
          backgroundColor: Colors.white, // White background
          // Use StadiumBorder for rounded rectangular shape and a light pink border
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Adjust corner radius as in the image
            side: BorderSide(color: Colors.pink.shade100, width: 1.0), // Light pink border
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          tooltip: suggestion.toLowerCase() == "something else?"
              ? 'Ask for different options'
              : 'Learn more about "$suggestion"',
          elevation: 0, // No elevation, as the image shows a flat chip
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