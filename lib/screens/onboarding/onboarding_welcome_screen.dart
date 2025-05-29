// lib/screens/onboarding/onboarding_welcome_screen.dart
import 'package:flutter/material.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Center( // Ensures the content is centered horizontally
        child: SingleChildScrollView( // Makes the content scrollable if it overflows
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Main title part 1 (Larger)
                Text(
                  'Welcome to Kitchen Assistant:',
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Main title part 2 (Smaller, below the first part)
                Text(
                  'Your Personal AI Chef!',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary.withOpacity(0.85),
                  ),
                  textAlign: TextAlign.center,
                ),

                // Spacing between title and image - Further Reduced
                const SizedBox(height: 2.0), // Was 16.0

                Image.asset(
                  'assets/welcome.png', // Make sure this path is correct
                  height: 450,
                  width: 600,
                  fit: BoxFit.contain, // Recommended
                ),

                // Spacing between image and description text - Further Reduced
                const SizedBox(height: 2.0), // Was 16.0

                Text(
                  'Discover recipes you love and generate new culinary ideas with powerful AI chef.',
                  style: textTheme.titleMedium?.copyWith(
                    height: 1.5,
                    color: textTheme.bodyLarge?.color?.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),

                // Spacing between description text and button (remains the same)
                const SizedBox(height: 48.0),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: const Text('Get Started'),
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/onboarding_preferences');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}