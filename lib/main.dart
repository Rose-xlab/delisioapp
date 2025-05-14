// lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // Add this import
import 'app.dart'; // Assuming DelisioApp is here
import 'providers/auth_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/subscription_provider.dart';
import 'config/sentry_config.dart'; // Import the Sentry config (includes initSentry and captureException)

// Global navigator key for accessing context from providers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // This is needed for the splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Keep the splash screen visible until app is fully loaded
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // --- CORRECTED INITIALIZATION ORDER ---

  // 1. Load .env file and essential keys FIRST
  String? supabaseUrl;
  String? supabaseAnonKey;
  String? revenueCatAndroidApiKey;
  String? revenueCatIOSApiKey;
  // Keep track if dotenv loading failed
  bool dotEnvLoadFailed = false;

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('.env file loaded successfully.');
    // Read keys immediately after loading
    supabaseUrl = dotenv.env['SUPABASE_URL'];
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    revenueCatAndroidApiKey = dotenv.env["REVENUECAT_ANDROID_API_KEY"];
    revenueCatIOSApiKey = dotenv.env["REVENUECAT_IOS_API_KEY"];
    // You could also load SENTRY_DSN here if needed elsewhere,
    // but initSentry reads it internally anyway.
  } catch (e) {
    dotEnvLoadFailed = true;
    debugPrint('CRITICAL: Error loading .env file: $e');
    // Cannot proceed without .env, but try to report if Sentry can init without DSN
    // (though unlikely without DSN loaded here)
  }

  // 2. Initialize Sentry (it will read SENTRY_DSN from dotenv internally now)
  // We are NOT using the appRunner callback approach anymore.
  // Assuming initSentry is modified or designed to be called standalone *after* dotenv load.
  // If initSentry MUST wrap runApp, the structure needs rethinking, but let's follow
  // the diagnosis that initSentry was just called too early before.
  try {
    // Pass a dummy runner or adjust initSentry if it absolutely requires one,
    // but ideally, it just initializes Sentry settings.
    // Let's assume initSentry can be called like this IF dotenv is loaded:
    await initSentry((options) {
      // This callback might now be minimal or only run if Sentry init succeeds
      debugPrint('Sentry init callback executed (options: ${options != null})');
    });
    debugPrint("Sentry initialization process attempted.");
  } catch (e) {
    debugPrint("Error during Sentry initialization process: $e");
    // Attempt to capture if possible, though Sentry might not be functional
    await captureException(e, stackTrace: StackTrace.current);
  }


  // 3. Check Supabase keys (that we tried to load earlier) and Initialize Supabase
  if (dotEnvLoadFailed) {
    debugPrint('ERROR: Cannot initialize Supabase because .env file failed to load.');
    // Maybe show an error screen or exit?
    await captureException(
      'Supabase init skipped: .env loading failed',
      stackTrace: StackTrace.current,
    );
    return; // Stop execution if .env failed
  }

  if (supabaseUrl == null || supabaseAnonKey == null) {
    debugPrint('ERROR: SUPABASE_URL or SUPABASE_ANON_KEY not found in environment variables after loading .env.');
    // Log this critical error (Sentry might be working now)
    await captureException(
      'Missing Supabase credentials in environment',
      stackTrace: StackTrace.current,
    );
    return; // Stop execution if keys are missing
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('Supabase initialized successfully.');
  } catch (e) {
    debugPrint('CRITICAL: Error initializing Supabase: $e');
    // Log this critical error
    await captureException(e, stackTrace: StackTrace.current);
    return; // Stop execution if Supabase fails to initialize
  }


  ////////////////////// INITIALISE REVENUE CAT //////////////////////////
  if(revenueCatAndroidApiKey != null && revenueCatIOSApiKey != null){
    
      final revenueCatConfig = PurchasesConfiguration(

        Platform.isAndroid  
        ? revenueCatAndroidApiKey
        : revenueCatIOSApiKey,
      );

      await Purchases.configure(revenueCatConfig);
  }

  // 4. Run the App (only if all initializations succeeded)
  runApp(
    MultiProvider(
      providers: [
        // --- Your exact Provider setup from before ---
        // Theme provider for dark/light mode
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // 1. AuthProvider provided first
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // 2. Other independent providers
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),

        // 3. ChatProvider DEPENDS ON AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          // Create function initializes ChatProvider once.
          create: (context) => ChatProvider(),

          // Update function is called immediately after create and whenever AuthProvider notifies listeners.
          update: (context, auth, previousChatProvider) {
            debugPrint("ChangeNotifierProxyProvider: Updating ChatProvider. Auth authenticated: ${auth.isAuthenticated}");
            // Ensure previousChatProvider is not null before updating
            final chatProvider = previousChatProvider ?? ChatProvider();
            chatProvider.updateAuth(auth); // Pass the whole AuthProvider instance
            return chatProvider;
          },
        ),
      ],
      child: const DelisioApp(), // Assuming this is your root App widget file
    ),
  );
}