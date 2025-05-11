import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Set full screen mode immediately
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _navigateBasedOnAuthState();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _navigateBasedOnAuthState() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/main');
  }

  @override
  Widget build(BuildContext context) {
    // Get full screen dimensions
    final Size screenSize = MediaQuery.of(context).size;

    // Use exact colors from your logo
    const Color backgroundColor = Color(0xFFFEF9E7); // Cream/beige from logo
    const Color textColor = Color(0xFF0A3C5C); // Dark blue from logo

    return Scaffold(
      // Remove any default padding/margin
      body: Container(
        // Force container to fill entire screen
        width: screenSize.width,
        height: screenSize.height,
        color: backgroundColor,
        child: Stack(
          // Stack allows overlapping elements
          children: [
            // Background layer with logo
            Positioned.fill(
              child: FractionallySizedBox(
                // Make logo fill almost entire screen
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Center(
                  child: Image.asset(
                    'assets/logo.png',
                    // Use width of full screen to make logo as large as possible
                    width: screenSize.width,
                    height: screenSize.width, // Maintain square aspect for logo
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Loading indicator at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Loading spinner
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    strokeWidth: 4.0,
                  ),

                  const SizedBox(height: 16),

                  // Loading text
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}