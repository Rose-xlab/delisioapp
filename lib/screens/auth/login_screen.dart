// lib/screens/auth/login_screen.dart
import 'dart:async'; // For StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Provides AuthState and OAuthProvider
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle

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
            physics: ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              //make background white 
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: 24, bottom: 32),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                      ),
                      child: Column(
                        children: [
                          Image.asset('assets/logo.png', width: 100, height: 100),
                          SizedBox(height:2),
                          Text('KITCHEN ASSISTANT', style: TextStyle(fontSize:14, fontWeight: FontWeight.w400,color: Colors.white), textAlign: TextAlign.center),
                          SizedBox(height: 8),
                          Text(
                            'LOGIN',
                            style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32),
                        ],
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.26,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                          children: [
                            SizedBox(height:50),
                            AuthForm(
                              formKey: _formKey,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              isLogin: true,
                              onSubmit: _login,
                              isLoading: _isLoggingIn,
                              errorMessage: _errorMessage ?? authProvider.error,
                            ),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text("Don't have an account?"),
                                TextButton(
                                  onPressed: _isLoggingIn ? null : () {
                                    Navigator.of(context).pushNamed('/signup');
                                  },
                                  child: Text('Sign Up'),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // SocialAuthButton(
                                //   onTap:_handleGoogleSignIn,
                                //   image: "assets/google_logo.png",
                                //   text: "Sign in with Google",
                                // ),
                                // if (Platform.isIOS) ...[
                                //   SizedBox(width: 10),
                                //   SocialAuthButton(
                                //     onTap: _isLoggingIn ? null : () {
                                //       // Apple Sign-In logic
                                //     },
                                //     image: "assets/apple_logo.png",
                                //   ),
                                // ],
                              ],
                            )

                          ],
                        ),
                        )

                        ),
                    ),

                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}