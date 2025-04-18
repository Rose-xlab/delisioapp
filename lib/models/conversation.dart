// lib/models/conversation.dart
import 'package:intl/intl.dart'; // Add intl to pubspec.yaml if not already present

class Conversation {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  String? title; // Can be updated later
  String? lastMessagePreview; // Optional preview

  Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.lastMessagePreview,
  });

  // Factory to create from Supabase Row data (Map<String, dynamic>)
  factory Conversation.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? dateStr) {
      return dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    }

    // Basic title generation from timestamp if title is null/empty
    String generateTitle(String? title, DateTime createdAt) {
      if (title != null && title.isNotEmpty) {
        return title;
      }
      // Format: "Chat - Apr 18, 8:40 PM"
      return 'Chat - ${DateFormat.MMMd().add_jm().format(createdAt.toLocal())}';
    }

    final createdAt = parseDate(json['created_at']);

    return Conversation(
      id: json['id'] as String,
      createdAt: createdAt,
      updatedAt: parseDate(json['updated_at']),
      // Generate a default title if none is stored
      title: generateTitle(json['title'] as String?, createdAt),
      // lastMessagePreview would ideally come from a join or separate query
    );
  }

// Optional: Add toJson if needed later
}