// lib/screens/auth/signup_screen.dart
import 'package:delisio/widgets/auth/social_auth_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _isLoading = false;
  String? _errorMessage;

  

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Provider.of<AuthProvider>(context, listen: false).signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
      // After signup, navigate to preferences screen
      Navigator.of(context).pushReplacementNamed('/preferences');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    //screen width
  final screenWidth = MediaQuery.sizeOf(context).width;

  
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24,horizontal: screenWidth > 600 ? 100 : 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign up to start your cooking journey',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AuthForm(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    nameController: _nameController,
                    confirmPasswordController: _confirmPasswordController,
                    isLogin: false,
                    onSubmit: _signup,
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Login'),
                      ),
                    ],
                  ),

                  /////////////////////////////////////
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(

                        flex: 1,
                        child: Divider(thickness: 1,color: Colors.grey[300]),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text("or continue with",style: TextStyle(color: Colors.grey[500]),),
                        ),
                      Expanded(
                        flex: 1,
                        child:Divider(thickness: 1,color: Colors.grey[300],)
                        )
                      
                    ],
                  ),

                  const SizedBox(height: 10,),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SocialAuthButton(
                        onTap: (){
                          debugPrint("Social one");
                        },
                        image: "assets/google_logo.png",
                      ),
                      const SizedBox(width: 10,),
                      SocialAuthButton(
                        onTap: (){
                          debugPrint("Social two");
                        },
                        image: "assets/facebook_logo.png",
                      ),

                      const SizedBox(width: 10,),
                      SocialAuthButton(
                        onTap: (){
                          debugPrint("Social three");
                        },
                        image: "assets/apple_logo.png",
                      ),
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