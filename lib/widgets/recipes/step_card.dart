// widgets/recipes/step_card.dart
import 'package:flutter/material.dart';
import '../../models/recipe_step.dart';

class StepCard extends StatelessWidget {
  final RecipeStep step;
  final int stepNumber;

  const StepCard({
    Key? key,
    required this.step,
    required this.stepNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug log for image URL
    print('Building StepCard $stepNumber with image URL: ${step.imageUrl}');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step image (if available)
          if (step.imageUrl != null && step.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                step.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    print('Image loaded successfully for step $stepNumber');
                    return child;
                  }
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading image...',
                            style: TextStyle(color: Theme.of(context).primaryColor),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Image error for step $stepNumber: $error');
                  print('Image URL that failed: ${step.imageUrl}');
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Could not load image',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Spacer between image and content - ADDED for better separation
          const SizedBox(height: 16),

          // Step content - UPDATED padding for better spacing
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), // Increased horizontal padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number indicator with improved styling
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 16), // Added margin for separation
                  child: Row(
                    children: [
                      // Step number indicator
                      Container(
                        width: 36, // Slightly increased
                        height: 36, // Slightly increased
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          // Added shadow for depth
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            stepNumber.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16, // Increased font size
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Step title or just 'Step X'
                      Expanded(
                        child: Text(
                          'Step $stepNumber',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Step instructions with improved line height and spacing
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    // Light border for subtle definition
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    step.text,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6, // Increased line height for readability
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}