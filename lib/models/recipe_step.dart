// lib/models/recipe_step.dart
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
    // Check for image_url in different formats and locations
    String? extractedImageUrl;
    if (json['image_url'] != null) {
      extractedImageUrl = json['image_url'].toString();
    } else if (json['imageUrl'] != null) {
      extractedImageUrl = json['imageUrl'].toString();
    }

    return RecipeStep(
      text: json['text'] ?? '',
      // Check both 'image_url' (from backend) and 'imageUrl' (for consistency)
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
}