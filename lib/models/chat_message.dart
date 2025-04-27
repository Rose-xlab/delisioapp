// lib/models/chat_message.dart
import 'package:flutter/foundation.dart'; // For kDebugMode print

// --- MODIFIED: Added new message types ---
enum MessageType { user, ai, recipePlaceholder, recipeResult }
// --- END MODIFIED ---

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final List<String>? suggestions; // List of suggestion strings, null if none

  // --- ADDED: Recipe specific fields ---
  final String? recipeId;     // ID of the generated recipe (for recipeResult type)
  final String? recipeTitle;  // Title of the generated recipe (for recipeResult type)
  final String? generationQuery; // Query used for generation (for recipePlaceholder)
  // --- END ADDED ---


  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.suggestions,
    // --- ADDED to constructor ---
    this.recipeId,
    this.recipeTitle,
    this.generationQuery,
    // --- END ADDED ---
  });

  // --- MODIFIED: Updated factory to handle new types and metadata ---
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<String>? parsedSuggestions;
    final metadata = json['metadata'] as Map<String, dynamic>?; // Get metadata

    // --- Updated Suggestion Parsing from Metadata ---
    if (metadata?['suggestions'] != null && metadata!['suggestions'] is List) {
      // Ensure all elements are strings, filtering out any non-strings silently
      parsedSuggestions = (metadata['suggestions'] as List)
          .map((item) => item?.toString()) // Handle potential nulls within the list
          .where((item) => item != null)   // Filter out nulls
          .cast<String>()                 // Cast to String
          .toList();
      if (parsedSuggestions.isEmpty) parsedSuggestions = null; // Treat empty list as null
    }
    // --- End Updated Suggestion Parsing ---


    // Determine message type from 'role' and metadata
    MessageType determinedType;
    final role = json['role'] as String?;
    if (metadata?['isRecipePlaceholder'] == true) {
      determinedType = MessageType.recipePlaceholder;
    } else if (metadata?['recipeId'] != null) {
      determinedType = MessageType.recipeResult;
    } else if (role == 'user') {
      determinedType = MessageType.user;
    } else { // Default to 'assistant' / AI
      determinedType = MessageType.ai;
    }

    // Debug print for loaded message type and metadata
    if (kDebugMode) {
      print("ChatMessage.fromJson: Loaded ID ${json['id']}, Role: $role, Metadata: $metadata -> Determined Type: $determinedType");
    }


    return ChatMessage(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(), // Ensure ID is string
      content: json['content'] as String? ?? '', // Ensure content is string
      type: determinedType, // Use determined type
      timestamp: json['created_at'] != null // Use created_at from DB
          ? DateTime.parse(json['created_at'] as String).toLocal() // Convert to local time
          : DateTime.now(), // Fallback if created_at is missing
      suggestions: parsedSuggestions,
      // --- ADDED: Extract recipe info from metadata ---
      recipeId: metadata?['recipeId'] as String?,
      recipeTitle: metadata?['recipeTitle'] as String?,
      generationQuery: metadata?['generationQuery'] as String?,
      // --- END ADDED ---
    );
  }
  // --- END MODIFIED ---


  // --- ADDED: toJsonForDb method ---
  Map<String, dynamic> toJsonForDb() { // Renamed to avoid confusion with potential API toJson
    // Determine role based on type
    String role;
    switch (type) {
      case MessageType.user:
        role = 'user';
        break;
      case MessageType.recipePlaceholder:
      case MessageType.recipeResult:
      case MessageType.ai: // Treat recipe results/placeholders as 'assistant' role in DB
      default:
        role = 'assistant';
    }

    // Build metadata map
    final Map<String, dynamic> metadata = {};
    if (suggestions != null && suggestions!.isNotEmpty) {
      metadata['suggestions'] = suggestions;
    }
    if (type == MessageType.recipePlaceholder) {
      metadata['isRecipePlaceholder'] = true;
      if (generationQuery != null) metadata['generationQuery'] = generationQuery;
    }
    if (type == MessageType.recipeResult) {
      if (recipeId != null) metadata['recipeId'] = recipeId;
      if (recipeTitle != null) metadata['recipeTitle'] = recipeTitle;
    }

    return {
      // We usually don't include 'id' when inserting, Supabase generates it.
      // If updating, we'd need the 'id' in the where clause.
      'content': content,
      'role': role,
      // 'created_at' is usually set by the DB on insert.
      // 'updated_at' is usually handled by DB triggers.
      'metadata': metadata.isNotEmpty ? metadata : null, // Only include metadata if not empty
      // Add 'conversation_id' and 'user_id' externally when calling insert/update.
    };
  }
  // --- END ADDED ---


  // Optional: toJson for general use (might differ from DB structure)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.name, // Use enum name string
      'timestamp': timestamp.toIso8601String(),
      'suggestions': suggestions,
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'generationQuery': generationQuery,
    };
  }
}