// lib/app.dart
import 'package:flutter/material.dart';
// provider import might not be needed directly here if not used, but harmless
// import 'package:provider/provider.dart';

// --- Screen Imports ---
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/user_preferences_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/recipes/nutrition_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_list_screen.dart'; // <-- IMPORT NEW CHAT LIST SCREEN

// --- Other Imports ---
import 'theme/app_theme.dart';

// --- Placeholder Widgets (Ensure you have real implementations) ---
// class SplashScreen ...
// class LoginScreen ...
// class SignupScreen ...
// class UserPreferencesScreen ...
// class MainNavigationScreen ...
// class RecipeDetailScreen ...
// class NutritionScreen ...
// class ChatScreen ... (Needs constructor: ChatScreen({required this.conversationId}))
// class ChatListScreen ...

// --- Main App Widget ---
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
        // --- ADD ROUTE FOR THE NEW CHAT LIST SCREEN ---
        '/chatList': (context) => const ChatListScreen(),
        // --- Removed '/chat' from here, handled by onGenerateRoute ---
      },

      // Use onGenerateRoute for routes that need arguments (like /chat)
      onGenerateRoute: (settings) {
        print("onGenerateRoute: Handling route '${settings.name}'");
        WidgetBuilder builder;
        switch (settings.name) {
          case '/chat':
            final conversationId = settings.arguments as String?;
            if (conversationId != null) {
              builder = (_) => ChatScreen(conversationId: conversationId);
            } else {
              // Handle error: Chat screen requires an ID
              print("Error: '/chat' route requires a conversationId argument.");
              builder = (_) => const ErrorScreen(message: 'Chat ID missing');
            }
            break;
        // Add cases for other routes requiring arguments if any
        // case '/recipe':
        //   final recipeId = settings.arguments as String?;
        //   if (recipeId != null) { ... } else { ... }
        //   break;
          default:
          // If route not handled by 'routes' or here, go to unknown route handler
            return null; // Let onUnknownRoute handle it
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