// lib/screens/auth/login_screen.dart
import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:kitchenassistant/widgets/auth/or_divider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Provides AuthState
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

  // True when this screen was opened from the contextual login gate (so on success we
  // return a result to the gate instead of replacing the navigation stack with /home).
  bool get _isGate {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['gate'] == true;
  }

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ok = await authProvider.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoggingIn = false);
    if (ok && authProvider.isAuthenticated) {
      if (_isGate) {
        Navigator.of(context).pop(true); // resume the gated action
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else if (authProvider.error != null) {
      setState(() => _errorMessage = authProvider.error);
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
        if (_isGate) {
          Navigator.of(context).pop(true); // resume the gated action
        } else {
          Navigator.of(context).pushReplacementNamed('/app');
        }
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
                    // Close → browse the app without signing in (protected actions still gate).
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Explore without an account',
                        onPressed: () {
                          if (_isGate) {
                            Navigator.of(context).pop(false);
                          } else {
                            Navigator.of(context).pushReplacementNamed('/home');
                          }
                        },
                      ),
                    ),
                    Image.asset('assets/logo.png', width: 100, height: 100),
                    SizedBox(height:2),
                    Text('KITCHEN ASSISTANT', style: TextStyle(fontSize:14, fontWeight: FontWeight.w400,color: Colors.white), textAlign: TextAlign.center),
                    SizedBox(height: 8),
                    Text(
                      'LOGIN',
                      style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height:20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SizedBox(height: 24),
                      // Lead with one-tap social sign-in (the frictionless path)
                      SocialAuthButton(
                        onTap: _handleGoogleSignIn,
                        image: "assets/google_logo.png",
                        text: "Continue with Google",
                      ),
                      SizedBox(height: 16),
                      OrDivider(),
                      SizedBox(height: 8),
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