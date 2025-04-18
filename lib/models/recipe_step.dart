// models/recipe_step.dart
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
    return RecipeStep(
      text: json['text'],
      imageUrl: json['image_url'],
      illustration: json['illustration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'image_url': imageUrl,
      'illustration': illustration,
    };
  }
}