// lib/widgets/auth/auth_form.dart
import 'package:flutter/material.dart';
import '../../utils/validators.dart';

class AuthForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController? nameController;
  final TextEditingController? confirmPasswordController;
  final bool isLogin;
  final Function onSubmit;
  final bool isLoading;
  final String? errorMessage;

  const AuthForm({
    Key? key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    this.nameController,
    this.confirmPasswordController,
    required this.isLogin,
    required this.onSubmit,
    this.isLoading = false,
    this.errorMessage,
  }) : super(key: key);

  @override
  _AuthFormState createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          // Name field (only for signup)
          if (!widget.isLogin) ...[
            TextFormField(
              controller: widget.nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: TextInputAction.next,
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
          ],

          // Email field
          TextFormField(
            controller: widget.emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 16),

          // Password field
          TextFormField(
            controller: widget.passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: widget.isLogin ? TextInputAction.done : TextInputAction.next,
            validator: Validators.validatePassword,
          ),

          // Confirm Password field (only for signup)
          if (!widget.isLogin) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != widget.passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],

          const SizedBox(height: 24),

          // Error message
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom:8.0),
              child: Text(
                widget.errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),

             
             // Forgot password (only for login)

            if (widget.isLogin) ...[
            const SizedBox(height:6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Implement forgot password
                },
                child: const Text('Forgot Password?'),
              ),
            ),
          ],

          // Submit button
          ElevatedButton(
            onPressed: widget.isLoading
                ? null
                : () {
              widget.onSubmit();
            },
            child: widget.isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white),
            )
                : Text(widget.isLogin ? 'Login' : 'Sign Up'),
          ),

         
          
        ],
      ),
    );
  }
}