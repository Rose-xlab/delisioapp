// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// --- Screen Imports (using relative paths from lib/app.dart) ---
import 'screens/chat/chat_history.dart'; // Corrected to relative
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
import 'screens/profile/subscription_screen.dart';

// --- ADD IMPORTS FOR ONBOARDING SCREENS (using relative paths) ---
import 'screens/onboarding/onboarding_welcome_screen.dart';
import 'screens/onboarding/onboarding_preferences_screen.dart';
import 'screens/onboarding/onboarding_paywall_screen.dart';

// --- Other Imports (using relative paths) ---
import 'theme/app_theme_updated.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';

class DelisioApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const DelisioApp({
    Key? key,
    required this.navigatorKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Delisio', // Your app title (presumably, or 'Kitchen Assistant')
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: '/', // Starts with SplashScreen

      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        // This route seems specific, ensure UserPreferencesScreen is intended here
        '/preferences': (context) => const UserPreferencesScreen(),

        // Changed '/main' to '/app' for consistency with onboarding navigation
        '/app': (context) => const MainNavigationScreen(), // Main app screen after login/onboarding

        '/recipe': (context) => const RecipeDetailScreen(),
        '/nutrition': (context) => const NutritionScreen(),
        '/chatList': (context) => const ChatListScreen(),
        '/notifications': (context) => const NotificationPreferencesScreen(),
        '/faq': (context) => const FAQScreen(),
        '/about': (context) => const AboutScreen(),
        '/contact': (context) => const ContactSupportScreen(),
        '/subscription': (context) => const SubscriptionScreen(),

        // --- ADDED ONBOARDING ROUTES ---
        '/onboarding_welcome': (context) => const OnboardingWelcomeScreen(),
        '/onboarding_preferences': (context) => const OnboardingPreferencesScreen(),
        '/onboarding_paywall': (context) => const OnboardingPaywallScreen(),
      },

      onGenerateRoute: (settings) {
        debugPrint("onGenerateRoute: Handling route '${settings.name}' with args: ${settings.arguments}");
        WidgetBuilder builder;

        switch (settings.name) {
          case '/chat':
            final args = settings.arguments;
            debugPrint("onGenerateRoute: /chat, args type: ${args.runtimeType}, value: $args");
            if (args is Map<String, dynamic>) {
              final String? initialQuery = args['initialQuery'] as String?;
              final String? purpose = args['purpose'] as String?;
              final String? conversationId = args['conversationId'] as String?; // Added to handle map
              builder = (_) => ChatScreen(initialQuery: initialQuery, purpose: purpose, conversationId: conversationId);
            } else if (args is String) { // Assumed to be conversationId
              builder = (_) => ChatScreen(conversationId: args);
            } else { // Default to creating a new chat
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
          case "/chat/history":
            final conversationId = settings.arguments as String?;
            if (conversationId != null) {
              builder = (_) => ChatHistoryScreen(conversationId: conversationId);
            } else {
              builder = (_) => Scaffold(appBar: AppBar(title: const Text('Error')), body: const Center(child: Text('Conversation ID missing for chat history.')));
            }
            break;
          default:
          // This fallback is good practice within onGenerateRoute
            return MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Page Not Found')), body: Center(child: Text('No specific route defined for ${settings.name} in onGenerateRoute.'))));
        }
        return MaterialPageRoute(builder: builder, settings: settings);
      },

      onUnknownRoute: (settings) {
        debugPrint("Warning: Navigated to unknown route: ${settings.name}");
        return MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Error - Page Not Found')), body: Center(child: Text('The page ${settings.name} could not be found.'))));
      },
    );
  }
}