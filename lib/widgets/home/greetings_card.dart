//greetings_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_gate_sheet.dart';


class GreetingCard extends StatelessWidget {
  const GreetingCard({super.key});

  @override
Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context); // listen so it updates after sign-in
    final bool isAuth = authProvider.isAuthenticated;
    final userName = authProvider.user?.name ?? (isAuth ? 'Valued User' : 'there');
  return SizedBox(
    width: double.infinity, // Ensure the card fills available width
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDEFEF), // Light pink background
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Monogram (first letter of name, fallback 'M')
          Container(
            width: 48.0,
            height: 48.0,
            decoration: BoxDecoration(
              color: const Color(0xFFF23B5A), // Pink background for monogram
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          // Text content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello, $userName',
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242), // Dark grey text
                ),
              ),
              const Text(
                'Time to spark your culinary creativity!',
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Spacer(), // Pushes the trailing widget to the end
          // Logged-out users get a clear Sign in affordance; logged-in users see the bell.
          if (isAuth)
            const Icon(
              Icons.notifications,
              color: Color(0xFFF23B5A), // Pink color for the bell
            )
          else
            TextButton.icon(
              onPressed: () => showLoginGate(context, message: 'Sign in to Kitchen Assistant'),
              icon: const Icon(Icons.login_rounded, size: 18, color: Color(0xFFF23B5A)),
              label: const Text(
                'Sign in',
                style: TextStyle(color: Color(0xFFF23B5A), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    ),
  );
}
}