import 'package:flutter/material.dart';
import '../../models/recipe_step.dart';
import 'cook_mode_view.dart';

class FloatingCookModeButton extends StatelessWidget {
  final List<RecipeStep> steps;
  final bool isAtScrollBottom;

  const FloatingCookModeButton({
    Key? key,
    required this.steps,
    this.isAtScrollBottom = false,
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
    final theme = Theme.of(context);

    if (isAtScrollBottom) {
      // Custom vertical button using Material, InkWell, and Container
      // The actual size (width and height on screen) of this button
      // will be determined by the parent (AnimatedPositioned in RecipeDetailScreen).
      return Material(
        color: theme.primaryColor,
        elevation: 4,
        borderRadius: BorderRadius.circular(12.0), // Or adjust for a more pill-like shape
        child: InkWell(
          onTap: () => _launchCookMode(context),
          borderRadius: BorderRadius.circular(12.0),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Tooltip(
            message: 'Cook Mode',
            child: Container(
              // This container will fill the space given by AnimatedPositioned.
              // Its padding is for the content inside.
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
              alignment: Alignment.center, // Center the RotatedBox within this Container
              child: RotatedBox(
                quarterTurns: 1, // Text reads top-to-bottom if on right edge
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.restaurant, size: 18, color: Colors.white),
                    SizedBox(height: 3),
                    Text(
                      "Cook", // Keep text short for vertical fit
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Original horizontal extended FAB
      return FloatingActionButton.extended(
        onPressed: () => _launchCookMode(context),
        backgroundColor: theme.primaryColor,
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
      );
    }
  }
}
