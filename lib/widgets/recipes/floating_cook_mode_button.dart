// lib/widgets/recipes/floating_cook_mode_button.dart
import 'package:flutter/material.dart';
import '../../models/recipe_step.dart';
import 'cook_mode_view.dart';

class FloatingCookModeButton extends StatelessWidget {
  final List<RecipeStep> steps;
  final bool visible;

  const FloatingCookModeButton({
    Key? key,
    required this.steps,
    this.visible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: visible ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          margin: const EdgeInsets.only(bottom: 20.0),
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (context) => CookModeView(
                    steps: steps,
                    onExitCookMode: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            extendedPadding: const EdgeInsets.symmetric(horizontal: 24.0),
            icon: const Icon(Icons.restaurant),
            label: const Text(
              'Cook Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}