// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // Import for removing splash

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _navigateBasedOnOnboardingState();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _navigateBasedOnOnboardingState() async {
    await Future.delayed(const Duration(seconds: 2)); // Shorter delay, splash is visible longer
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;

    // Remove the splash screen just before navigation
    FlutterNativeSplash.remove();

    if (hasCompletedOnboarding) {
      Navigator.of(context).pushReplacementNamed('/app'); // Assuming '/app' is your main app route in DelisioApp
    } else {
      Navigator.of(context).pushReplacementNamed('/onboarding_welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    // The native splash is shown by FlutterNativeSplash.preserve in main.dart
    // This widget can be minimal or show a secondary branding if needed after preserve.
    // For simplicity, let's keep it as a basic themed container.
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9E7), // Your logo's cream/beige
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png', // Ensure you have this asset
              width: MediaQuery.of(context).size.width * 0.6,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A3C5C)), // Dark blue from logo
            ),
          ],
        ),
      ),
    );
  }
}