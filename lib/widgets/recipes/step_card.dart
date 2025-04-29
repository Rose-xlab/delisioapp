// widgets/recipes/step_card.dart
import 'package:flutter/material.dart';
import '../../models/recipe_step.dart';

class StepCard extends StatefulWidget {
  final RecipeStep step;
  final int stepNumber;
  final List<RecipeStep> allSteps; // Keep this parameter for the Cook Mode functionality

  const StepCard({
    Key? key,
    required this.step,
    required this.stepNumber,
    required this.allSteps,
  }) : super(key: key);

  @override
  State<StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<StepCard> {
  bool _isImageError = false;
  bool _isImageLoading = true;

  @override
  void initState() {
    super.initState();
    _isImageLoading = widget.step.imageUrl != null && widget.step.imageUrl!.isNotEmpty;
  }

  @override
  void didUpdateWidget(StepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step.imageUrl != oldWidget.step.imageUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isImageError = false;
            _isImageLoading = widget.step.imageUrl != null && widget.step.imageUrl!.isNotEmpty;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.step.imageUrl != null &&
        widget.step.imageUrl!.isNotEmpty &&
        !_isImageError;

    // Debug log for image URL
    print('Building StepCard ${widget.stepNumber} with image URL: ${widget.step.imageUrl}');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step image (if available)
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                widget.step.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    // Image loaded successfully
                    if (_isImageLoading) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _isImageLoading = false;
                          });
                        }
                      });
                    }
                    print('Image loaded successfully for step ${widget.stepNumber}');
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
                  print('Image error for step ${widget.stepNumber}: $error');
                  print('Image URL that failed: ${widget.step.imageUrl}');

                  // Mark image as having error
                  if (!_isImageError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isImageError = true;
                          _isImageLoading = false;
                        });
                      }
                    });
                  }

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
            )
          else if (!hasImage && !_isImageLoading)
          // Show a placeholder if no image
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(
                  Icons.restaurant,
                  size: 60,
                  color: Colors.grey[400],
                ),
              ),
            ),

          // Spacer between image and content
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
                            widget.stepNumber.toString(),
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
                          'Step ${widget.stepNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Cook Mode Button removed - we're now using a floating button
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
                    widget.step.text,
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