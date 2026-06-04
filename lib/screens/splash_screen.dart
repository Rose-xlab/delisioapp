// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    // Brief hand-off from the native splash — no long artificial wait.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Remove the native splash just before navigation
    FlutterNativeSplash.remove();

    // 1) Logged in (persisted/restored Supabase session) → straight to the app.
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      if (kDebugMode) debugPrint('SplashScreen: Session found for ${session.user.id} → /home.');
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    // 2) Logged out: show the Welcome intro ONLY on the first ever launch.
    //    Returning logged-out users skip it and land on Home in browse mode
    //    (the contextual login gate handles sign-in when they act).
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

    if (!hasSeenWelcome) {
      await prefs.setBool('hasSeenWelcome', true);
      if (!mounted) return;
      if (kDebugMode) debugPrint('SplashScreen: First launch → onboarding welcome.');
      Navigator.of(context).pushReplacementNamed('/onboarding_welcome');
    } else {
      if (kDebugMode) debugPrint('SplashScreen: Returning logged-out user → /home (browse).');
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    // The native splash is shown by FlutterNativeSplash.preserve in main.dart
    // This widget can be minimal or show a secondary branding if needed after preserve.
    // For simplicity, let's keep it as a basic themed container.
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9E7), // Your logo's cream/beige
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 80,
                    height: 80,
                    errorBuilder: (ctx, err, _) => Icon(
                      Icons.restaurant,
                      size: 60,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
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