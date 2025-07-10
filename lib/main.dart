// lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// Your original relative imports for files within lib/
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/subscription_provider.dart';
import 'config/sentry_config.dart';

// Global navigator key (from your original)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  String? supabaseUrl;
  String? supabaseAnonKey;
  String? revenueCatAndroidApiKey;
  String? revenueCatIOSApiKey;
  bool dotEnvLoadFailed = false;

  // --- Your .env loading logic (preserved) ---
  try {
    await dotenv.load(fileName: ".env");
    if (kDebugMode) {
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
    await captureException(e,
        stackTrace: StackTrace.current,
        hintText: 'Critical: .env file loading failed during app startup.'
    );
  }

  // --- Your Sentry initialization (preserved) ---
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
  }

  // --- Your .env failure handling (preserved) ---
  if (dotEnvLoadFailed) {
    if (kDebugMode) {
      print('ERROR: Cannot initialize Supabase because .env file failed to load.');
    }
    await captureException(
        'Supabase init skipped due to .env loading failure',
        stackTrace: StackTrace.current,
        hintText: 'Supabase initialization skipped: .env loading failed prior to Sentry DSN availability.'
    );
    FlutterNativeSplash.remove();
    runApp(ErrorAppWidget(errorMessage: "Failed to load critical app configurations from .env. Please check setup."));
    return;
  }

  // --- Your Supabase URL/Key check (preserved) ---
  if (supabaseUrl == null || supabaseAnonKey == null) {
    final errorMsg = 'ERROR: SUPABASE_URL or SUPABASE_ANON_KEY not found in environment variables.';
    if (kDebugMode) {
      print(errorMsg);
    }
    await captureException(
        errorMsg,
        stackTrace: StackTrace.current,
        hintText: 'Missing Supabase credentials in environment'
    );
    FlutterNativeSplash.remove();
    runApp(ErrorAppWidget(errorMessage: "Supabase configuration missing. App cannot start."));
    return;
  }

  // --- Your Supabase initialization (preserved) ---
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    if (kDebugMode) {
      print('Supabase initialized successfully.');
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('CRITICAL: Error initializing Supabase: $e');
    }
    await captureException(e, stackTrace: stackTrace, hintText: 'Supabase initialization failed');
    FlutterNativeSplash.remove();
    runApp(ErrorAppWidget(errorMessage: "Failed to initialize core service (Supabase). App cannot start. Error: $e"));
    return;
  }

  // --- Your RevenueCat initialization (preserved) ---
  if (revenueCatAndroidApiKey != null && revenueCatAndroidApiKey.isNotEmpty &&
      revenueCatIOSApiKey != null && revenueCatIOSApiKey.isNotEmpty) {
    try {
      final revenueCatConfig = PurchasesConfiguration(
        Platform.isAndroid ? revenueCatAndroidApiKey : revenueCatIOSApiKey,
      );
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(revenueCatConfig);
      if (kDebugMode) {
        print('RevenueCat configured successfully.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error configuring RevenueCat: $e');
      }
      await captureException(e, stackTrace: stackTrace, hintText: 'RevenueCat configuration failed');
    }
  } else {
    if (kDebugMode) {
      print('WARNING: RevenueCat API keys not found in .env. In-app purchases will not work.');
    }
  }

  // FlutterNativeSplash.remove(); // Your comment: Moved removal to the first screen (e.g., SplashScreen or initial route)
  // This is correctly handled by your SplashScreen.dart now.

  // MODIFICATION: Create AuthProvider instance to be able to call setNavigatorContext on it.
  final authProviderInstance = AuthProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // MODIFICATION: Use ChangeNotifierProvider.value for the existing authProviderInstance
        ChangeNotifierProvider.value(value: authProviderInstance),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProxyProvider2<AuthProvider, SubscriptionProvider, ChatProvider>(
          create: (context) => ChatProvider(),
          update: (context, auth, subscription, previousChatProvider) {
            // Your existing debug prints and logic for ChatProvider update
            if (kDebugMode) {
              print("ChangeNotifierProxyProvider: Updating ChatProvider.");
              print("  AuthProvider Authenticated: ${auth.isAuthenticated}");
              print("  SubscriptionProvider Instance: ${subscription != null}");
              if (subscription != null) {
                print("  SubscriptionProvider isPro: ${subscription.isProSubscriber}");
                print("  SubscriptionProvider Info: ${subscription.subscriptionInfo != null}");
              }
            }
            final chatProvider = previousChatProvider ?? ChatProvider();
            chatProvider.updateProviders(auth: auth, subs: subscription);
            return chatProvider;
          },
        ),
      ],
      child: DelisioApp(navigatorKey: navigatorKey), // Your original DelisioApp call
    ),
  );

  // MODIFICATION: After runApp, set the navigator context for AuthProvider.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentContext != null) {
      authProviderInstance.setNavigatorContext(navigatorKey.currentContext!);
      if (kDebugMode) {
        print("AuthProvider navigator context set in main.dart.");
      }
    } else {
      if (kDebugMode) {
        print("AuthProvider: Failed to set navigator context in main.dart, navigatorKey.currentContext is null post-frame.");
      }
    }
  });
}

// Your ErrorAppWidget (preserved)
class ErrorAppWidget extends StatelessWidget {
  final String errorMessage;
  const ErrorAppWidget({Key? key, required this.errorMessage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Critical Application Error:\n$errorMessage\nPlease contact support or try again later.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}