// lib/screens/auth/signup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kitchenassistant/widgets/auth/or_divider.dart';
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

  final supabase =
      Supabase.instance.client; // Keep if used directly for Google Sign-In

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
      const webClientId =
          '601707002682-2gna6etmp9k6jak25v5m7n3mrar683t4.apps.googleusercontent.com';
      final GoogleSignIn googleSignIn = GoogleSignIn(clientId: webClientId);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Sign in aborted by user');
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
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
          _errorMessage =
              "Google Sign-Up failed: ${e.toString().split(':').last.trim()}";
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
      if (mounted && authProvider.isAuthenticated) {
        // Redirect to main home screen (same as existing users)
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (mounted && !authProvider.isAuthenticated && authProvider.error == null) {
        // If not authenticated and no error, it likely means email confirmation is required.
        setState(() {
          _errorMessage = "Sign up successful! Please check your email for a confirmation link before logging in.";
        });
      } else if (mounted && authProvider.error != null) {
        // If signUp internally sets an error in AuthProvider
        setState(() {
          _errorMessage = authProvider.error;
        });
      }
    } catch (e) {
      // Catch errors rethrown by authProvider.signUp
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
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colorScheme.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                  ),
                  child: Column(
                    children: [
                      Image.asset('assets/logo.png', width: 100, height: 100),
                      SizedBox(height: 2),
                      Text('KITCHEN ASSISTANT',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white),
                          textAlign: TextAlign.center),
                      SizedBox(height: 8),
                      Text(
                        'REGISTER',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: SizedBox(
                          height: 30,
                        ),
                      )
                    ],
                  ),
                ),
                // Form Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SizedBox(height: 50),
                        AuthForm(
                          formKey: _formKey,
                          nameController: _nameController,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          confirmPasswordController: _confirmPasswordController,
                          isLogin: false,
                          onSubmit: _signup,
                          isLoading: _isSigningUp,
                          errorMessage: _errorMessage ?? authProvider.error,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account?'),
                            TextButton(
                              onPressed: _isSigningUp
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                    },
                              child: const Text('Login'),
                            ),
                          ],
                        ),
                        // ...SocialAuthButton row if needed...

                        OrDivider(),
                        

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                                child: SocialAuthButton(
                              onTap: _handleGoogleSignIn,
                              image: "assets/google_logo.png",
                              text: "Continue with Google",
                            )),
                           
                          ],

                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
