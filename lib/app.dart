// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Screen Imports ---
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/user_preferences_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/recipes/nutrition_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'providers/chat_provider.dart'; // Added for chat handling

// --- Other Imports ---
import 'theme/app_theme.dart';

class CookingAssistantApp extends StatelessWidget {
  const CookingAssistantApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cooking Assistant',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/', // Start with splash screen

      // Use routes for simple, non-argument routes
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/preferences': (context) => const UserPreferencesScreen(),
        '/main': (context) => const MainNavigationScreen(),
        '/recipe': (context) => const RecipeDetailScreen(),
        '/nutrition': (context) => const NutritionScreen(),
      },

      // Use onGenerateRoute for routes that need arguments (like /chat)
      onGenerateRoute: (settings) {
        print("onGenerateRoute: Handling route '${settings.name}'");
        WidgetBuilder builder;

        switch (settings.name) {
          case '/chat':
            final conversationId = settings.arguments as String?;
            if (conversationId != null) {
              // If we have a valid conversation ID, go to that chat
              builder = (_) => ChatScreen(conversationId: conversationId);
            } else {
              // If no ID provided, create a new chat
              builder = (_) => FutureBuilder<String?>(
                future: Provider.of<ChatProvider>(context, listen: false).createNewConversation(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Creating new chat...'),
                          ],
                        ),
                      ),
                    );
                  } else if (snapshot.hasError || snapshot.data == null) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Error')),
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text('Failed to create new chat'),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error?.toString() ?? 'Unknown error',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    // Success - we have a new conversation ID
                    return ChatScreen(conversationId: snapshot.data!);
                  }
                },
              );
            }
            break;

        // Add cases for other routes requiring arguments if any
          default:
          // If route not handled by 'routes' or here, go to unknown route handler
            return null;
        }

        // Use MaterialPageRoute for standard transitions
        return MaterialPageRoute(builder: builder, settings: settings);
      },

      // Handles any route not defined in 'routes' or 'onGenerateRoute'
      onUnknownRoute: (settings) {
        print("Warning: Navigated to unknown route: ${settings.name}");
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Error - Page Not Found')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
      },
    );
  }
}

// Simple Error Screen placeholder
class ErrorScreen extends StatelessWidget {
  final String message;
  const ErrorScreen({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(child: Text('An error occurred: $message')),
    );
  }
}