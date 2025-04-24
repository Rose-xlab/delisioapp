// lib/models/recipe_step.dart
import 'package:flutter/foundation.dart';

class RecipeStep {
  final String text;
  final String? imageUrl;
  final String? illustration;

  RecipeStep({
    required this.text,
    this.imageUrl,
    this.illustration,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    // Debug output - only in debug mode
    if (kDebugMode) {
      print('RecipeStep JSON keys: ${json.keys.toList()}');
    }

    // More thorough image URL extraction
    String? extractedImageUrl;

    // Check common variations of image URL keys
    if (json.containsKey('image_url') && json['image_url'] != null) {
      extractedImageUrl = json['image_url'].toString();
    } else if (json.containsKey('imageUrl') && json['imageUrl'] != null) {
      extractedImageUrl = json['imageUrl'].toString();
    } else if (json.containsKey('image') && json['image'] != null) {
      extractedImageUrl = json['image'].toString();
    }

    // IMPORTANT: Skip DALLE temporary URLs that will cause 403 errors
    if (extractedImageUrl != null &&
        extractedImageUrl.contains('oaidalleapiprodscus.blob.core.windows.net')) {
      if (kDebugMode) {
        print('Skipping temporary DALLE URL: $extractedImageUrl');
      }
      extractedImageUrl = null;
    }

    // Debug logging for troubleshooting
    if (kDebugMode) {
      if (extractedImageUrl != null) {
        print('Using image URL in step: $extractedImageUrl');
      } else {
        print('No image URL found. Available keys: ${json.keys.toList()}');
      }
    }

    return RecipeStep(
      text: json['text'] ?? '',
      imageUrl: extractedImageUrl,
      illustration: json['illustration']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'image_url': imageUrl, // Use snake_case for backend compatibility
      'illustration': illustration,
    };
  }

  @override
  String toString() {
    return 'RecipeStep(text: $text, imageUrl: $imageUrl, illustration: $illustration)';
  }
}