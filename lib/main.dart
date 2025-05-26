import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
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
    // Sentry might not be initialized yet, so this might not always work
    // but it's worth a try if initSentry has already run or if it handles this case.
    await captureException(e, // Capture the original error
        stackTrace: StackTrace.current,
        hintText: 'Critical: .env file loading failed during app startup.' // MODIFIED
    );
  }

  // Initialize Sentry as early as possible, but after .env load attempt for DSN
  try {
    await initSentry((options) {
      if (kDebugMode) {
        print('Sentry init callback executed (options: ${options != null})');
      }
      // If appRunner needed to do something with options, it would be here.
      // For this setup, appRunner doesn't seem to use the options directly.
    });
    if (kDebugMode) {
      print("Sentry initialization process attempted.");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error during Sentry initialization process: $e");
    }
    // At this point, if Sentry init failed, captureException might also fail.
    // Consider a simpler, local fallback logging if Sentry is critical this early.
  }

  if (dotEnvLoadFailed) {
    if (kDebugMode) {
      print('ERROR: Cannot initialize Supabase because .env file failed to load.');
    }
    // This captureException might not reach Sentry if Sentry init also failed due to no DSN from .env
    await captureException(
        'Supabase init skipped due to .env loading failure',
        stackTrace: StackTrace.current,
        hintText: 'Supabase initialization skipped: .env loading failed prior to Sentry DSN availability.' // MODIFIED
    );
    FlutterNativeSplash.remove(); // Ensure splash is removed on early exit
    runApp(ErrorAppWidget(errorMessage: "Failed to load critical app configurations from .env. Please check setup.")); // Show a minimal error UI
    return;
  }

  if (supabaseUrl == null || supabaseAnonKey == null) {
    final errorMsg = 'ERROR: SUPABASE_URL or SUPABASE_ANON_KEY not found in environment variables.';
    if (kDebugMode) {
      print(errorMsg);
    }
    await captureException(
        errorMsg, // Send the message as the exception
        stackTrace: StackTrace.current,
        hintText: 'Missing Supabase credentials in environment' // MODIFIED
    );
    FlutterNativeSplash.remove();
    runApp(ErrorAppWidget(errorMessage: "Supabase configuration missing. App cannot start."));
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
  } catch (e, stackTrace) { // Added stackTrace
    if (kDebugMode) {
      print('CRITICAL: Error initializing Supabase: $e');
    }
    await captureException(e, stackTrace: stackTrace, hintText: 'Supabase initialization failed'); // MODIFIED
    FlutterNativeSplash.remove();
    runApp(ErrorAppWidget(errorMessage: "Failed to initialize core service (Supabase). App cannot start. Error: $e"));
    return;
  }

  if (revenueCatAndroidApiKey != null && revenueCatAndroidApiKey.isNotEmpty &&
      revenueCatIOSApiKey != null && revenueCatIOSApiKey.isNotEmpty) {
    try {
      final revenueCatConfig = PurchasesConfiguration(
        Platform.isAndroid ? revenueCatAndroidApiKey : revenueCatIOSApiKey,
      );
      // Configure Purchases before App first build
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(revenueCatConfig);
      if (kDebugMode) {
        print('RevenueCat configured successfully.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error configuring RevenueCat: $e');
      }
      await captureException(e, stackTrace: stackTrace, hintText: 'RevenueCat configuration failed'); // MODIFIED
    }
  } else {
    if (kDebugMode) {
      print('WARNING: RevenueCat API keys not found in .env. In-app purchases will not work.');
    }
    // Optionally capture this warning to Sentry if it's critical for your monitoring
    // await captureException('RevenueCat API keys missing', level: SentryLevel.warning, hintText: 'RevenueCat keys not found in .env');
  }

  // FlutterNativeSplash.remove(); // Moved removal to the first screen (e.g., SplashScreen or initial route)

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
      child: DelisioApp(navigatorKey: navigatorKey),
    ),
  );
}

// A simple widget to display critical startup errors
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