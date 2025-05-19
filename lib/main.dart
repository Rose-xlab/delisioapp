// lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // <<< ADDED THIS IMPORT FOR kDebugMode
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'app.dart'; // Assuming DelisioApp is here
import 'providers/auth_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/subscription_provider.dart';
import 'config/sentry_config.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  String? supabaseUrl;
  String? supabaseAnonKey;
  String? revenueCatAndroidApiKey;
  String? revenueCatIOSApiKey;
  bool dotEnvLoadFailed = false;

  try {
    await dotenv.load(fileName: ".env");
    if (kDebugMode) { // Use kDebugMode safely
      print('.env file loaded successfully.');
    }
    supabaseUrl = dotenv.env['SUPABASE_URL'];
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    revenueCatAndroidApiKey = dotenv.env["REVENUECAT_ANDROID_API_KEY"];
    revenueCatIOSApiKey = dotenv.env["REVENUECAT_IOS_API_KEY"];
  } catch (e) {
    dotEnvLoadFailed = true;
    if (kDebugMode) {
      print('CRITICAL: Error loading .env file: $e');
    }
  }

  try {
    await initSentry((options) {
      if (kDebugMode) {
        print('Sentry init callback executed (options: ${options != null})');
      }
    });
    if (kDebugMode) {
      print("Sentry initialization process attempted.");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error during Sentry initialization process: $e");
    }
    // await captureException(e, stackTrace: StackTrace.current); // Sentry might not be ready
  }

  if (dotEnvLoadFailed) {
    if (kDebugMode) {
      print('ERROR: Cannot initialize Supabase because .env file failed to load.');
    }
    await captureException('Supabase init skipped: .env loading failed', stackTrace: StackTrace.current);
    FlutterNativeSplash.remove();
    return;
  }

  if (supabaseUrl == null || supabaseAnonKey == null) {
    if (kDebugMode) {
      print('ERROR: SUPABASE_URL or SUPABASE_ANON_KEY not found in environment variables.');
    }
    await captureException('Missing Supabase credentials in environment', stackTrace: StackTrace.current);
    FlutterNativeSplash.remove();
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    if (kDebugMode) {
      print('Supabase initialized successfully.');
    }
  } catch (e) {
    if (kDebugMode) {
      print('CRITICAL: Error initializing Supabase: $e');
    }
    await captureException(e, stackTrace: StackTrace.current, hint: 'Supabase initialization failed');
    FlutterNativeSplash.remove();
    return;
  }

  if (revenueCatAndroidApiKey != null && revenueCatAndroidApiKey.isNotEmpty &&
      revenueCatIOSApiKey != null && revenueCatIOSApiKey.isNotEmpty) {
    try {
      final revenueCatConfig = PurchasesConfiguration(
        Platform.isAndroid ? revenueCatAndroidApiKey : revenueCatIOSApiKey,
      );
      await Purchases.configure(revenueCatConfig);
      if (kDebugMode) {
        print('RevenueCat configured successfully.');
      }
    } catch (e, stackTrace) { // Added stackTrace
      if (kDebugMode) {
        print('Error configuring RevenueCat: $e');
      }
      await captureException(e, stackTrace: stackTrace, hint: 'RevenueCat configuration failed');
    }
  } else {
    if (kDebugMode) {
      print('WARNING: RevenueCat API keys not found in .env. In-app purchases will not work.');
    }
  }

  // FlutterNativeSplash.remove(); // Recommended to move to first screen's initState or similar

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProxyProvider2<AuthProvider, SubscriptionProvider, ChatProvider>(
          create: (context) => ChatProvider(),
          update: (context, auth, subscription, previousChatProvider) {
            if (kDebugMode) { // Use kDebugMode safely
              print("ChangeNotifierProxyProvider: Updating ChatProvider.");
              print("  AuthProvider Authenticated: ${auth.isAuthenticated}");
              print("  SubscriptionProvider Instance: ${subscription != null}");
              if (subscription != null) {
                print("  SubscriptionProvider isPro: ${subscription.isProSubscriber}");
                print("  SubscriptionProvider Info: ${subscription.subscriptionInfo != null}");
              }
            }
            final chatProvider = previousChatProvider ?? ChatProvider();
            chatProvider.updateProviders(auth: auth, subs: subscription); // Using the new method
            return chatProvider;
          },
        ),
      ],
      child: DelisioApp(navigatorKey: navigatorKey),
    ),
  );
}