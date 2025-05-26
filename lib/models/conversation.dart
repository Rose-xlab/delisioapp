// lib/models/conversation.dart
import 'package:intl/intl.dart';

class Conversation {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt; // This is final
  String? title;             // This is mutable in your current model
  String? lastMessagePreview; // This is mutable in your current model

  Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.lastMessagePreview,
  });

  // Add this copyWith method:
  Conversation copyWith({
    // id and createdAt are typically not changed in a copy-for-update scenario
    DateTime? updatedAt,
    String? title,              // Allow updating mutable title via copyWith too
    bool clearTitle = false,    // Optional: helper to explicitly set title to null
    String? lastMessagePreview, // Allow updating mutable preview via copyWith
    bool clearLastMessagePreview = false, // Optional: helper
  }) {
    return Conversation(
      id: this.id,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt, // Use new if provided, else old
      title: clearTitle ? null : (title ?? this.title), // Handle updates or keep old
      lastMessagePreview: clearLastMessagePreview ? null : (lastMessagePreview ?? this.lastMessagePreview),
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? dateStr) {
      return dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    }

    String generateTitle(String? dbTitle, DateTime createdAtDate) {
      if (dbTitle != null && dbTitle.isNotEmpty) {
        return dbTitle;
      }
      return 'Chat - ${DateFormat.MMMd().add_jm().format(createdAtDate.toLocal())}';
    }

    final createdAtDate = parseDate(json['created_at']);

    return Conversation(
      id: json['id'] as String,
      createdAt: createdAtDate,
      updatedAt: parseDate(json['updated_at']),
      title: generateTitle(json['title'] as String?, createdAtDate),
      lastMessagePreview: json['last_message_preview'] as String?, // Ensure this key exists if you use it
    );
  }
}