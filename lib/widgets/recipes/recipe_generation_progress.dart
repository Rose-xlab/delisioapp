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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress header
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.primaryColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Generating Recipe...',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                      // Use the normal StepCard - it will handle loading states
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: StepCard(step: step, stepNumber: index + 1),
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
}