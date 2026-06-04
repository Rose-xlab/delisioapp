// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// --- Screen Imports (using relative paths from lib/app.dart) ---
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/user_preferences_screen.dart'; // Your general preferences screen
import 'screens/main_navigation_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/recipes/nutrition_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_history.dart'; // Was in your original
import 'screens/profile/notification_preferences_screen.dart';
import 'screens/profile/faq_screen.dart';
import 'screens/profile/about_screen.dart';
import 'screens/profile/contact_support_screen.dart';
import 'screens/profile/subscription_screen.dart';
// import 'screens/profile/profile_screen_enhanced.dart'; // Not directly routed by name here, usually part of MainNavigationScreen

// --- ONBOARDING SCREEN IMPORTS ---
import 'screens/onboarding/onboarding_welcome_screen.dart';
// Removed: onboarding_preferences_screen, onboarding_food_selection_screen,
// onboarding_paywall_screen — these screens were deleted.

// --- Other Imports (using relative paths) ---
import 'theme/app_theme_updated.dart'; // Assuming this is your theme file
import 'providers/chat_provider.dart'; // For onGenerateRoute context if needed

class DelisioApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const DelisioApp({
    Key? key,
    required this.navigatorKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Remove splash screen once the first meaningful frame is built.
    // This is fine here if DelisioApp is the root widget under MultiProvider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    return MaterialApp(
      title: 'Kitchen Assistant', // Or 'Kitchen Assistant' if that's your app name
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme, // Your dark theme
      // The app is designed light-first (many widgets hardcode white surfaces with
      // theme-coloured text). On a device set to dark mode, that produced white text
      // on white backgrounds ("words hidden under white"). Until the dark theme is fully
      // audited, force the light theme so every screen renders with readable contrast.
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: '/', // Start with the SplashScreen

      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),

        // This is your general preferences screen, editable from profile
        '/preferences': (context) => const UserPreferencesScreen(),

        // Main app screen after login/onboarding
        '/app': (context) => const MainNavigationScreen(),
        '/home': (context) => const MainNavigationScreen(initialIndex: 0),

        // Onboarding flow (only the welcome screen remains)
        '/onboarding_welcome': (context) => const OnboardingWelcomeScreen(),

        // Other app routes from your original file
        '/recipe': (context) => const RecipeDetailScreen(), // Needs argument handling if ID is passed
        '/nutrition': (context) => const NutritionScreen(), // Needs argument handling if ID is passed
        '/chatList': (context) => const ChatListScreen(),
        '/notifications': (context) => const NotificationPreferencesScreen(),
        '/faq': (context) => const FAQScreen(),
        '/about': (context) => const AboutScreen(),
        '/contact': (context) => const ContactSupportScreen(),
        '/subscription': (context) => const SubscriptionScreen(),
        // Note: '/category/:id' type routes are typically handled by onGenerateRoute
      },

      onGenerateRoute: (settings) {
        debugPrint("onGenerateRoute: Handling route '${settings.name}' with args: ${settings.arguments}");
        WidgetBuilder? builder; // Make builder nullable

        // Handle routes with arguments or more complex logic here
        switch (settings.name) {
          case '/chat':
            final args = settings.arguments;
            debugPrint("onGenerateRoute: /chat, args type: ${args.runtimeType}, value: $args");
            if (args is Map<String, dynamic>) {
              final String? initialQuery = args['initialQuery'] as String?;
              final String? purpose = args['purpose'] as String?;
              final String? conversationId = args['conversationId'] as String?;
              builder = (_) => ChatScreen(initialQuery: initialQuery, purpose: purpose, conversationId: conversationId);
            } else if (args is String) { // Assumed to be conversationId for existing chat
              builder = (_) => ChatScreen(conversationId: args);
            } else { // Default: create a new chat if no specific args
              builder = (_) => FutureBuilder<String?>(
                future: Provider.of<ChatProvider>(context, listen: false).createNewConversation(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Creating new chat...')])));
                  } else if (snapshot.hasError || snapshot.data == null) {
                    return Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), const Text('Failed to create new chat'), const SizedBox(height: 8), Text(snapshot.error?.toString() ?? 'Unknown error', style: const TextStyle(color: Colors.grey)), const SizedBox(height: 24), ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back'))])));
                  } else {
                    return ChatScreen(conversationId: snapshot.data!);
                  }
                },
              );
            }
            break;
          case '/chat/history': // Corrected from "/chat/history"
            final conversationId = settings.arguments as String?;
            if (conversationId != null) {
              builder = (_) => ChatHistoryScreen(conversationId: conversationId);
            } else {
              // Fallback or error for missing conversationId
              builder = (_) => Scaffold(appBar: AppBar(title: const Text('Error')), body: const Center(child: Text('Conversation ID missing for chat history.')));
            }
            break;

          default:
            debugPrint("onGenerateRoute: Route '${settings.name}' not handled by specific cases.");
            return null; // Let onUnknownRoute handle it if not found in routes map either
        }
        // If builder was assigned, create the route
        if (builder != null) {
          return MaterialPageRoute(builder: builder, settings: settings);
        }
        return null;
      },

      onUnknownRoute: (settings) {
        // Your existing onUnknownRoute logic
        debugPrint("Warning: Navigated to unknown route: ${settings.name}");
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(child: Text('The page "${settings.name}" could not be found.')),
          ),
        );
      },
    );
  }
}