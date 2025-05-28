// lib/screens/auth/signup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Assuming relative paths from lib/screens/auth/
import '../../widgets/auth/social_auth_button.dart'; // Corrected to relative
import '../../providers/auth_provider.dart';
import '../../widgets/auth/auth_form.dart';


class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSigningUp = false; // Renamed for clarity
  String? _errorMessage;

  final supabase = Supabase.instance.client; // Keep if used directly for Google Sign-In

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningUp = true;
      _errorMessage = null;
    });
    try {
      const webClientId = '601707002682-2gna6etmp9k6jak25v5m7n3mrar683t4.apps.googleusercontent.com';
      final GoogleSignIn googleSignIn = GoogleSignIn(clientId: webClientId);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Sign in aborted by user');
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      // Supabase sign-in will trigger AuthProvider's listener
      final AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        // AuthProvider will handle navigation after its state updates
        // Potentially check if it's a new user and navigate to onboarding prefs.
        // For now, assume AuthProvider's onAuthStateChange handles it.
      } else if (response.session == null && response.user == null) {
        throw Exception(response.toString());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Google Sign-Up failed: ${e.toString().split(':').last.trim()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningUp = false;
        });
      }
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSigningUp = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      // After successful signUp call, AuthProvider's onAuthStateChange listener will update isAuthenticated.
      // We should wait for that confirmation or navigate based on that.
      // For new users, it's good to go to onboarding preferences.
      if (mounted && authProvider.isAuthenticated) { // Check if signUp made user authenticated
        Navigator.of(context).pushReplacementNamed('/onboarding_preferences');
      } else if (mounted && authProvider.error != null) {
        // If signUp internally sets an error in AuthProvider (e.g. email already exists and it handles it)
        setState(() { _errorMessage = authProvider.error; });
      } else if (mounted && !authProvider.isAuthenticated && authProvider.error == null) {
        // This case might happen if email confirmation is required. AuthProvider might set an error/message.
        // For now, we assume direct authentication or an error is set by AuthProvider.
        // If AuthProvider.signUp doesn't throw but requires email verification, it should set an appropriate
        // message in _error or have a different state for it.
        // The default here is to go to onboarding_preferences IF authenticated.
        if (authProvider.error != null) { // Check again if an error was set during the process
          setState(() { _errorMessage = authProvider.error; });
        } else {
          // If no error but not authenticated (e.g. email verification pending),
          // show a message or handle as per your app's flow.
          // For now, assume /onboarding_preferences is for fully auth'd new users.
          // If email verification is pending, AuthProvider's listener should handle that state.
        }
      }
    } catch (e) { // Catch errors rethrown by authProvider.signUp
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().split(':').last.trim();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final authProvider = Provider.of<AuthProvider>(context); // For error display

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: screenWidth > 600 ? 100 : 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Sign up to start your cooking journey', style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  AuthForm(
                    formKey: _formKey,
                    nameController: _nameController, // Pass name controller
                    emailController: _emailController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController, // Pass confirm password
                    isLogin: false,
                    onSubmit: _signup,
                    isLoading: _isSigningUp,
                    errorMessage: _errorMessage ?? authProvider.error, // Show local or provider error
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: _isSigningUp ? null : () {
                          Navigator.of(context).pop(); // Go back to LoginScreen
                        },
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                  Row( /* ... Divider ... */
                    children: [ Expanded(child: Divider(thickness: 1,color: Colors.grey[300]),), Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text("or create with",style: TextStyle(color: Colors.grey[500]),), ), Expanded(child:Divider(thickness: 1,color: Colors.grey[300],))],
                  ),
                  const SizedBox(height: 10,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SocialAuthButton(
                        onTap: _isSigningUp ? null : _handleGoogleSignIn,
                        image: "assets/google_logo.png",
                      ),
                      if (Platform.isIOS) ...[const SizedBox(width: 10,), SocialAuthButton(onTap: () {debugPrint("Apple Sign Up");}, image: "assets/apple_logo.png",),],
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