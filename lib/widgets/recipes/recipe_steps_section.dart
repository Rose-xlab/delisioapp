// widgets/recipes/recipe_steps_section.dart
import 'package:flutter/material.dart';
import '../../models/recipe_step.dart';
import 'step_card.dart';
import 'recipe_cook_mode_button.dart';

class RecipeStepsSection extends StatelessWidget {
  final List<RecipeStep> steps;
  final String title;

  const RecipeStepsSection({
    Key? key,
    required this.steps,
    this.title = 'Preparation Steps',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with cook mode button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              RecipeCookModeButton(steps: steps),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Steps list
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: steps.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return StepCard(
              step: steps[index],
              stepNumber: index + 1,
              allSteps: steps,
            );
          },
        ),
      ],
    );
  }
}

// Usage example in a recipe detail screen:
/*
class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          // Minimalist cook mode button in app bar
          RecipeCookModeButton(
            steps: recipe.steps,
            minimalist: true,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Recipe image, description, etc.

            // Steps section with its own cook mode button
            RecipeStepsSection(
              steps: recipe.steps,
              title: 'Cooking Instructions',
            ),
          ],
        ),
      ),
    );
  }
}
*/