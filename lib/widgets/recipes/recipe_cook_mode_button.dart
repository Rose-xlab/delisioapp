// widgets/recipes/recipe_cook_mode_button.dart
import 'package:flutter/material.dart';
import '../../models/recipe_step.dart';
import 'cook_mode_view.dart';

class RecipeCookModeButton extends StatelessWidget {
  final List<RecipeStep> steps;
  final bool minimalist;

  const RecipeCookModeButton({
    Key? key,
    required this.steps,
    this.minimalist = false,
  }) : super(key: key);

  void _launchCookMode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => CookModeView(
          steps: steps,
          onExitCookMode: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return different button styles based on the minimalist flag
    if (minimalist) {
      return IconButton(
        icon: const Icon(Icons.restaurant),
        tooltip: 'Cook Mode',
        onPressed: () => _launchCookMode(context),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => _launchCookMode(context),
        icon: const Icon(Icons.restaurant),
        label: const Text('Cook Mode'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }
  }
}