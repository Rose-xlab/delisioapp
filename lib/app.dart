// lib/app.dart
import 'package:kitchenassistant/screens/chat/chat_history.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // Add this import

// --- Screen Imports ---
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/user_preferences_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/recipes/nutrition_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/profile/notification_preferences_screen.dart';
import 'screens/profile/faq_screen.dart';
import 'screens/profile/about_screen.dart';
import 'screens/profile/contact_support_screen.dart';
import 'screens/profile/subscription_screen.dart'; // New import for subscription screen

// --- Other Imports ---
import 'theme/app_theme_updated.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'main.dart'; // Import for navigatorKey

class DelisioApp extends StatelessWidget {
  const DelisioApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Remove the native splash screen now that app is ready
    FlutterNativeSplash.remove();

    // Use the ThemeProvider to get the current theme
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Delisio',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Add global navigator key for accessing context from providers
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
        '/chatList': (context) => const ChatListScreen(),
        '/notifications': (context) => const NotificationPreferencesScreen(),
        '/faq': (context) => const FAQScreen(),
        '/about': (context) => const AboutScreen(),
        '/contact': (context) => const ContactSupportScreen(),
        '/subscription': (context) => const SubscriptionScreen(),
      },

      onGenerateRoute: (settings) {
        debugPrint("onGenerateRoute: Handling route '${settings.name}' with args: ${settings.arguments}");
        WidgetBuilder builder;

        switch (settings.name) {
        // --- MODIFICATION START for /chat route ---
          case '/chat':
            final args = settings.arguments;
            debugPrint("onGenerateRoute: /chat, args type: ${args.runtimeType}, value: $args");

            if (args is Map<String, dynamic>) {
              // Case: Navigating from "Chat for Recipe Ideas" button in HomeScreenEnhanced
              final String? initialQuery = args['initialQuery'] as String?;
              final String? purpose = args['purpose'] as String?; // e.g., 'generateRecipe'

              // ChatScreen will receive initialQuery and purpose.
              // It needs to handle creating/selecting a conversation internally
              // and then sending the initialQuery if present.
              builder = (_) => ChatScreen(
                initialQuery: initialQuery,
                purpose: purpose,
                // conversationId will be null here, ChatScreen needs to manage this.
              );
            } else if (args is String) {
              // Case: Navigating with a specific conversation_id (e.g., from chat list)
              final conversationId = args;
              builder = (_) => ChatScreen(conversationId: conversationId);
            } else {
              // Case: Navigating to /chat without arguments (e.g., generic "new chat" action)
              // This creates a new conversation and then navigates to ChatScreen with its ID.
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
                              onPressed: () => Navigator.pop(context), // Or navigate to a safe place
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
        // --- MODIFICATION END for /chat route ---

          case "/chat/history":
            final conversationId = settings.arguments as String?;
            if (conversationId != null) {
              builder = (_) => ChatHistoryScreen(conversationId: conversationId);
            } else {
              // Fallback or error for chat history without ID
              builder = (_) => Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(child: Text('Conversation ID missing for chat history.')),
              );
            }
            break;
        // Add cases for other routes requiring arguments if any
          default:
          // If route not handled by 'routes' or here, onUnknownRoute will be called.
          // However, to prevent MaterialPageRoute from being called with a null builder:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Page Not Found')),
                body: Center(
                  child: Text('No specific route defined for ${settings.name} in onGenerateRoute.'),
                ),
              ),
            );
        }

        return MaterialPageRoute(builder: builder, settings: settings);
      },

      onUnknownRoute: (settings) {
        debugPrint("Warning: Navigated to unknown route: ${settings.name}");
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