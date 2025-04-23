// lib/config/sentry_config.dart
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

export 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;


/// Initialize Sentry for the entire application
Future<void> initSentry(Function(dynamic options) appRunner) async {
  // Try to get DSN from .env file
  final String? sentryDsn = dotenv.env['SENTRY_DSN'];

  if (sentryDsn == null || sentryDsn.isEmpty) {
    // If no DSN is provided, just run the app without Sentry
    if (kDebugMode) {
      print('SentryConfig: No DSN found in .env file. Running without Sentry.');
    }
    appRunner(null);
    return;
  }

  try {
    await SentryFlutter.init(
          (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.5; // Adjust based on your needs
        options.environment = kDebugMode ? 'development' : 'production';
        options.debug = kDebugMode;
        options.enableAutoSessionTracking = true;
        options.release = 'delisio@1.0.0'; // Should match your app version
        options.attachStacktrace = true;

        // Pass options to the app runner
        appRunner(options);
      },
    );
  } catch (e) {
    if (kDebugMode) {
      print('SentryConfig: Error initializing Sentry: $e');
    }
    // Run the app without Sentry if initialization fails
    appRunner(null);
  }
}

/// Capture an exception with Sentry
Future<void> captureException(
    dynamic exception, {
      dynamic stackTrace,
      dynamic hint,
      ScopeCallback? withScope,
    }) async {
  try {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: hint,
      withScope: withScope,
    );
  } catch (e) {
    if (kDebugMode) {
      print('SentryConfig: Error capturing exception with Sentry: $e');
    }
  }
}

/// Add a breadcrumb to the current scope
void addBreadcrumb({
  required String message,
  String? category,
  Map<String, dynamic>? data,
  SentryLevel level = SentryLevel.info,
}) {
  try {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
      ),
    );
  } catch (e) {
    if (kDebugMode) {
      print('SentryConfig: Error adding breadcrumb: $e');
    }
  }
}

/// Set user information in Sentry
void setUser(String userId, {String? email, String? name}) {
  try {
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: userId,
        email: email,
        username: name,
      ));
    });
  } catch (e) {
    if (kDebugMode) {
      print('SentryConfig: Error setting user: $e');
    }
  }
}

/// Clear user information from Sentry
void clearUser() {
  try {
    Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  } catch (e) {
    if (kDebugMode) {
      print('SentryConfig: Error clearing user: $e');
    }
  }
}