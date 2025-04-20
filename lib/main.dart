// lib/main_updated.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart'; // We'll update this next
import 'providers/auth_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart'; // New theme provider

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    print('.env file loaded successfully.');
  } catch (e) {
    print('Error loading .env file: $e');
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    print('ERROR: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env file.');
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    print('Supabase initialized successfully.');
  } catch(e) {
    print('Error initializing Supabase: $e');
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        // Theme provider for dark/light mode
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // 1. AuthProvider provided first
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // 2. Other independent providers
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),

        // 3. ChatProvider DEPENDS ON AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          // Create function initializes ChatProvider once.
          create: (context) => ChatProvider(),

          // Update function is called immediately after create and whenever AuthProvider notifies listeners.
          update: (context, auth, previousChatProvider) {
            print("ChangeNotifierProxyProvider: Updating ChatProvider. Auth authenticated: ${auth.isAuthenticated}");
            // Ensure previousChatProvider is not null before updating
            final chatProvider = previousChatProvider ?? ChatProvider();
            chatProvider.updateAuth(auth); // Pass the whole AuthProvider instance
            return chatProvider;
          },
        ),
      ],
      child: const DelisioApp(), // Updated app name
    ),
  );
}