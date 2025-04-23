// lib/widgets/recipes/recipe_generation_progress.dart
import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../models/recipe_step.dart';
import 'ingredient_list.dart';
import 'step_card.dart';

class RecipeGenerationProgress extends StatelessWidget {
  final Recipe partialRecipe;
  final double progress;
  final VoidCallback onCancel;
  final bool isCancelling;

  const RecipeGenerationProgress({
    Key? key,
    required this.partialRecipe,
    required this.progress,
    required this.onCancel,
    this.isCancelling = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Removed the redundant null check for partialRecipe as it's required

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress header
          Container(
            padding: const EdgeInsets.all(16),
            // Kept withOpacity as it's standard practice
            color: theme.primaryColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ***** CHANGE APPLIED HERE *****
                    Expanded( // Wrapped the Text widget below in Expanded
                      child: Text(
                        'Generating Recipe...',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // ***** END OF CHANGE *****
                    if (!isCancelling)
                      TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    else
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% complete',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Recipe title (if available)
          if (partialRecipe.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                partialRecipe.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Servings info (if available)
          if (partialRecipe.servings > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.people_outline, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Serves ${partialRecipe.servings}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

          // Time info (if available)
          if (partialRecipe.prepTimeMinutes != null ||
              partialRecipe.cookTimeMinutes != null ||
              partialRecipe.totalTimeMinutes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 12,
                children: [
                  if (partialRecipe.prepTimeMinutes != null)
                    _buildTimeInfo(
                      context,
                      Icons.timer_outlined,
                      '${partialRecipe.prepTimeMinutes} min prep',
                    ),
                  if (partialRecipe.cookTimeMinutes != null)
                    _buildTimeInfo(
                      context,
                      Icons.whatshot_outlined,
                      '${partialRecipe.cookTimeMinutes} min cook',
                    ),
                  if (partialRecipe.totalTimeMinutes != null)
                    _buildTimeInfo(
                      context,
                      Icons.schedule,
                      // Fixed: Added missing closing quote
                      '${partialRecipe.totalTimeMinutes} min total',
                    ),
                ],
              ),
            ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // Ingredients (if available)
          if (partialRecipe.ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ingredients', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  IngredientList(ingredients: partialRecipe.ingredients),
                ],
              ),
            ),

          // Only show divider if both ingredients and steps are present
          if (partialRecipe.ingredients.isNotEmpty && partialRecipe.steps.isNotEmpty)
            const Divider(height: 1, indent: 16, endIndent: 16),


          // Steps (if available)
          if (partialRecipe.steps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: partialRecipe.steps.length,
                    itemBuilder: (context, index) {
                      final step = partialRecipe.steps[index];
                      // Show a loading indicator for steps without images yet
                      // Assuming image generation happens progressively
                      final bool showLoadingImage = step.imageUrl == null || step.imageUrl!.isEmpty;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: showLoadingImage
                            ? _buildPartialStepCard(step, index + 1, context)
                            : StepCard(step: step, stepNumber: index + 1),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Bottom space for better scrolling
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildPartialStepCard(RecipeStep step, int stepNumber, BuildContext context) {
    final theme = Theme.of(context); // Get theme here for primary color
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero, // Ensure card aligns with padding of parent
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder for image being generated
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Generating image...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // Step content padding adjusted
          Padding(
            padding: const EdgeInsets.all(16), // Consistent padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number indicator with improved styling
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Step number indicator
                    Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 12), // Add spacing
                      decoration: BoxDecoration(
                        // Use theme primary color
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            // Kept withOpacity as it's standard practice
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
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    // Step title or just 'Step X'
                    Expanded(
                      child: Text(
                        'Step $stepNumber',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          // Ensure text color contrasts with background
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12), // Spacing before instructions

                // Step instructions with improved styling
                Text(
                  step.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5, // Line height for readability
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