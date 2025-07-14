// lib/screens/onboarding/onboarding_welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:kitchenassistant/theme/app_colors_extension.dart';
import '../../widgets/primary_button.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!;

    return Scaffold(
      body: Center( // Ensures the content is centered horizontally
        child: SingleChildScrollView( // Makes the content scrollable if it overflows
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Responsive spacing
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),

                // App logo or icon (optional, for branding)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0), // Optional: adds a border radius
                  child: Image.asset(
                    'assets/logo.png',
                    height: MediaQuery.of(context).size.width > 600 ? 80 : 56,
                    width: MediaQuery.of(context).size.width > 600 ? 80 : 56,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),

                 Text(
                  'Welcome to',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:appColors.gray200,
                    letterSpacing: 0.5,
                    height:1
                  ),
                  textAlign: TextAlign.center,
                ),


                // Main title (large, bold, centered, with improved line height)
                Text(
                  'Kitchen Assistant',
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: appColors.gray500, // Using a neutral color for better readability
                    height: 1.15,

                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),

                // Subtitle (smaller, friendlier, with a touch of color)
                Text(
                  'Your Personal AI Chef',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:appColors.gray200,
                    letterSpacing: 0.5,
                    height: 1
                  ),
                  textAlign: TextAlign.center,
                ),

                // Spacing before image
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                // Hero image (responsive)
                Image.asset(
                  'assets/welcome.png',
                  height: MediaQuery.of(context).size.width > 600 ? 350 : 220,
                  width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
                  fit: BoxFit.contain,
                ),

                // Spacing before description
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                // Description (centered, readable, with max width)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Text(
                    'Discover recipes you love and generate new culinary ideas with your powerful AI chef.',
                    style: textTheme.titleMedium?.copyWith(
                      height: 1.5,
                      color: appColors.gray200, // Using a neutral color for better readability
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Spacing before button
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),

                PrimaryButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/onboarding_preferences');
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                  child: const Text('Get Started'),
                ),
                // Responsive bottom spacing
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }
}