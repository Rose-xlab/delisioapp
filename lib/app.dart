// lib/app.dart
import 'package:kitchenassistant/screens/chat/chat_history.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

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
import 'screens/profile/subscription_screen.dart';

// --- Other Imports ---
import 'theme/app_theme_updated.dart'; // Assuming AppTheme is here
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart'; // For onGenerateRoute context
// import 'main.dart'; // Avoid importing main.dart here if navigatorKey is passed as param

class DelisioApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey; // <<< ADD THIS FIELD

  const DelisioApp({
    Key? key,
    required this.navigatorKey, // <<< ADD THIS TO CONSTRUCTOR
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // It's good practice to remove splash screen once the first meaningful frame is built.
    // If DelisioApp is your root widget, doing it here or in SplashScreen's initState is common.
    // For StatelessWidget, it might be better in SplashScreen's initState to ensure it's after build.
    // However, if this is the very first widget runApp shows, this is acceptable.
    // To be safer, consider moving to SplashScreen.initState or using a Future.delayed(Duration.zero)
    // if you see issues with it removing too early.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });


    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Delisio',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // <<< ASSIGN THE PASSED navigatorKey HERE
      initialRoute: '/',

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
        // Your existing onGenerateRoute logic remains the same
        debugPrint("onGenerateRoute: Handling route '${settings.name}' with args: ${settings.arguments}");
        WidgetBuilder builder;

        switch (settings.name) {
          case '/chat':
            final args = settings.arguments;
            debugPrint("onGenerateRoute: /chat, args type: ${args.runtimeType}, value: $args");
            if (args is Map<String, dynamic>) {
              final String? initialQuery = args['initialQuery'] as String?;
              final String? purpose = args['purpose'] as String?;
              builder = (_) => ChatScreen(initialQuery: initialQuery, purpose: purpose);
            } else if (args is String) {
              final conversationId = args;
              builder = (_) => ChatScreen(conversationId: conversationId);
            } else {
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
            return MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Page Not Found')), body: Center(child: Text('No specific route defined for ${settings.name} in onGenerateRoute.'))));
        }
        return MaterialPageRoute(builder: builder, settings: settings);
      },

      onUnknownRoute: (settings) {
        // Your existing onUnknownRoute logic
        debugPrint("Warning: Navigated to unknown route: ${settings.name}");
        return MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Error - Page Not Found')), body: Center(child: Text('No route defined for ${settings.name}'))));
      },
    );
  }
}