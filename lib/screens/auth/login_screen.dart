// lib/screens/auth/login_screen.dart
import 'dart:async'; // For StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Provides AuthState and OAuthProvider
import 'package:google_sign_in/google_sign_in.dart';

import '../../widgets/auth/social_auth_button.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth/auth_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoggingIn = false;
  String? _errorMessage;

  StreamSubscription<AuthState>? _authSubscription; // This line now has StreamSubscription defined

  @override
  void initState() {
    super.initState();
    // As discussed, relying on AuthProvider's central listener is often preferred.
    // If you keep this local listener, ensure its logic aligns with AuthProvider's actions.
    // For example, this listener might be redundant if AuthProvider already handles
    // Supabase auth state changes and updates its own state, which then drives UI/navigation.
    // If you uncomment it, ensure it correctly manages navigation or state without conflict.
    /*
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      debugPrint("Local LoginScreen onAuthStateChange: ${data.event}");
      if (mounted && data.event == AuthChangeEvent.signedIn && data.session != null) {
        // Potentially navigate here, but be cautious of race conditions with AuthProvider
        // Usually, AuthProvider should be the one triggering navigation after successful auth.
        // Navigator.of(context).pushReplacementNamed('/app');
      }
    });
    */
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authSubscription?.cancel(); // Important to cancel if it was active
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });
    try {
      const webClientId = '601707002682-2gna6etmp9k6jak25v5m7n3mrar683t4.apps.googleusercontent.com';
      final GoogleSignIn googleSignIn = GoogleSignIn(clientId: webClientId);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        if (mounted) setState(() => _errorMessage = 'Google Sign-In aborted by user.');
        return; // Exit if user cancelled
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID Token found from Google.');
      }

      // Sign in to Supabase. This will trigger AuthProvider's listener.
      final AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) {
        throw Exception('Supabase sign-in with Google failed. No user returned.');
      }
      // At this point, AuthProvider's onAuthStateChange listener should pick up the SIGNED_IN event
      // and handle the post-login logic, including navigation to '/app'.
      // We don't navigate directly here to let AuthProvider manage the authenticated state transition.

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Google Sign-In failed: ${e.toString().split(':').last.trim()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // After signIn completes, check AuthProvider's state for navigation
      if (mounted && authProvider.isAuthenticated) {
        // It's generally safer to let AuthProvider's listener handle navigation to ensure all
        // post-auth tasks (like _syncOnboardingDataAfterAuth) complete first.
        // However, if immediate navigation is desired and AuthProvider updates quickly:
        Navigator.of(context).pushReplacementNamed('/app');
      } else if (mounted && authProvider.error != null) {
        setState(() { _errorMessage = authProvider.error; });
      } else if (mounted && !authProvider.isAuthenticated) {
        // This case might occur if signIn didn't throw but also didn't authenticate (e.g. wrong password but no exception from service)
        // Or if email verification is pending and authProvider.signIn doesn't throw for that.
        setState(() { _errorMessage = authProvider.error ?? "Login failed. Please check your credentials."; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().split(':').last.trim();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Listen to AuthProvider to react to changes (e.g., show error messages)
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: screenWidth > 600 ? 100 : 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/logo.png', width: 100, height: 100),
                  const SizedBox(height: 24),
                  const Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    authProvider.isAuthenticated && authProvider.user?.email != null
                        ? 'Logged in as ${authProvider.user!.email}'
                        : 'Login to continue your cooking journey',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AuthForm(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    isLogin: true,
                    onSubmit: _login,
                    isLoading: _isLoggingIn,
                    errorMessage: _errorMessage ?? authProvider.error,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: _isLoggingIn ? null : () {
                          Navigator.of(context).pushNamed('/signup');
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                  Padding( // Using Padding for consistent spacing around "or continue with"
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        Expanded(child: Divider(thickness: 1, color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text("or continue with", style: TextStyle(color: Colors.grey[500])),
                        ),
                        Expanded(child: Divider(thickness: 1, color: Colors.grey[300])),
                      ],
                    ),
                  ),
                  // SizedBox height was 10, adjusted slightly if needed after divider padding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SocialAuthButton(
                        onTap: _isLoggingIn ? null : _handleGoogleSignIn,
                        image: "assets/google_logo.png",
                      ),
                      if (Platform.isIOS) ...[
                        const SizedBox(width: 10),
                        SocialAuthButton(
                          onTap: _isLoggingIn ? null : () {
                            debugPrint("Apple Sign In button pressed");
                            // Implement Apple Sign-In logic here
                            // Similar to _handleGoogleSignIn, it should result in
                            // Supabase auth.signInWithIdToken or similar, which
                            // will trigger AuthProvider's listener.
                          },
                          image: "assets/apple_logo.png",
                        ),
                      ],
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}