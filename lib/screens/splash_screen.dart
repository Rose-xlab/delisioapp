// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dart:async'; // For Future.delayed
// No longer importing these here if not used:
// import '../widgets/common/loading_indicator.dart';
// import '../widgets/common/error_display.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  // Ignore this specific private type warning for createState, it's standard practice
  // ignore: library_private_types_in_public_api
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint("SplashScreen: initState called");
    _navigateBasedOnAuthState(); // Renamed function for clarity
  }

  Future<void> _navigateBasedOnAuthState() async {
    debugPrint("SplashScreen: Starting navigation check...");

    // IMPORTANT: Wait a short moment to allow AuthProvider's listener
    // (which starts in its constructor) to potentially receive the
    // initial auth state from Supabase. 2 seconds might be more than needed,
    // but keeps the splash visible. A shorter delay or a Future.microtask
    // might work once AuthProvider initialization is confirmed stable.
    debugPrint("SplashScreen: Waiting for initial auth state resolution (2s delay)...");
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("SplashScreen: Wait finished.");

    // Check if the widget is still mounted before accessing context/navigating
    if (!mounted) {
      debugPrint("SplashScreen: Widget unmounted after delay, aborting navigation.");
      return;
    }


    //navigate to Main
    Navigator.of(context).pushReplacementNamed('/main');

    // Access AuthProvider *after* the delay
    // final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Now, simply check the state that AuthProvider determined from Supabase
    // debugPrint("SplashScreen: Checking AuthProvider state. IsAuthenticated: ${authProvider.isAuthenticated}");

    // if (authProvider.isAuthenticated) {
      
    //   debugPrint("SplashScreen: User is authenticated. Navigating to /main.");
    //   Navigator.of(context).pushReplacementNamed('/main');
    // } else {
    
    //   debugPrint("SplashScreen: User is NOT authenticated. Navigating to /login.");
    //   Navigator.of(context).pushReplacementNamed('/login');
    // }
    // No complex try-catch needed here anymore for this specific check,
    // as AuthProvider handles its own errors internally when setting state.
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("SplashScreen: Building UI");
    // Keep your existing splash screen UI
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png', // Make sure this path is correct
              width: 150,
              height: 150,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.food_bank_outlined, size: 100, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cooking Assistant',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text('Loading...'), // Updated text
          ],
        ),
      ),
    );
  }
}