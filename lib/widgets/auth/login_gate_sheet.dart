// lib/widgets/auth/login_gate_sheet.dart
//
// A contextual, one-tap sign-in bottom sheet used to gate protected actions
// (opening a recipe, chatting, viewing profile, generating) for logged-out users.
// It's non-destructive (slides up over the current screen) and leads with Google.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Returns true if the user is (or becomes) authenticated.
/// If logged out, shows the contextual sign-in sheet and resolves to whether
/// the user signed in. Callers should typically: `if (await showLoginGate(context, message: ...)) { ...do the action... }`.
Future<bool> showLoginGate(BuildContext context, {String? message}) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  if (authProvider.isAuthenticated) return true;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LoginGateSheet(message: message),
  );

  return (result ?? false) && authProvider.isAuthenticated;
}

class LoginGateSheet extends StatefulWidget {
  final String? message;
  const LoginGateSheet({super.key, this.message});

  @override
  State<LoginGateSheet> createState() => _LoginGateSheetState();
}

class _LoginGateSheetState extends State<LoginGateSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ok = await authProvider.signInWithGoogle();
    if (!mounted) return;
    if (ok && authProvider.isAuthenticated) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = authProvider.error ?? 'Sign-in was cancelled.';
      });
    }
  }

  Future<void> _email() async {
    // Open the full login screen in "gate" mode so that on success it returns here
    // and we can resume the caller's original action (instead of losing context).
    await Navigator.of(context).pushNamed('/login', arguments: const {'gate': true});
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      Navigator.of(context).pop(true);
    }
    // else: user backed out without signing in — keep the sheet so they can retry or cancel.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_open_rounded, color: primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            widget.message ?? 'Sign in to continue',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Create a free account to unlock chat, recipes and your saved kitchen.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),

          // Google one-tap (primary action)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _google,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/google_logo.png', width: 24, height: 24,
                            errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 22)),
                        const SizedBox(width: 12),
                        const Text('Continue with Google',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Email fallback (secondary)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : _email,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: primary,
                side: BorderSide(color: primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue with email', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13), textAlign: TextAlign.center),
          ],

          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text('Not now', style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }
}
