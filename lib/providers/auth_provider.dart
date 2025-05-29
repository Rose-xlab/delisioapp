// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For listEquals

import '../models/user.dart';
import '../models/user_preferences.dart';
import '../services/auth_service.dart';
import '../config/sentry_config.dart';
import '../providers/user_provider.dart';
import '../providers/subscription_provider.dart';

class AuthProvider with ChangeNotifier {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  final AuthService _authService = AuthService();
  StreamSubscription<supabase.AuthState>? _authStateSubscription;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  BuildContext? _navigatorContext;

  void setNavigatorContext(BuildContext context) {
    _navigatorContext = context;
    if (kDebugMode) print("AuthProvider: Navigator context set.");
  }

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _user != null;

  AuthProvider() {
    if (kDebugMode) print("AuthProvider: Initializing...");
    _initialize();
  }

  String _extractNameFromSupabaseUser(supabase.User supabaseUser) {
    return supabaseUser.userMetadata?['name'] as String? ??
        supabaseUser.userMetadata?['full_name'] as String? ??
        (supabaseUser.email?.split('@').first ?? ''); // Fallback
  }

  void _initialize() {
    final currentSession = _supabase.auth.currentSession;
    bool needsInitialSync = false;

    if (currentSession != null) {
      if (kDebugMode) print("AuthProvider: Found initial session.");
      _token = currentSession.accessToken;
      final supabaseUser = _supabase.auth.currentUser;

      if (supabaseUser != null) {
        try {
          _user = User.fromSupabaseUser(supabaseUser);
          if (kDebugMode) print("AuthProvider: Initial user set from session: ${_user?.id}, Name: ${_user?.name}");

          if (_user != null) {
            // Corrected Sentry setUser call
            setUser(_user!.id, email: _user!.email, name: _user!.name);
            addBreadcrumb(message: 'User initialized from existing session', category: 'auth', data: {'userId': _user!.id});
            needsInitialSync = true;
          }
        } catch (e, stackTrace) {
          if (kDebugMode) print("AuthProvider: Error creating User model from initial Supabase user: $e");
          captureException(e, stackTrace: stackTrace, hintText: "Error creating User model from initial Supabase user");
          _user = null; _token = null;
        }
      } else {
        if (kDebugMode) print("AuthProvider: Initial session exists, but Supabase currentUser is null. Clearing token.");
        _token = null;
      }
    } else {
      if (kDebugMode) print("AuthProvider: No initial session found.");
    }

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (error, stackTrace) {
        if (kDebugMode) print("AuthProvider: AuthStateChange Stream Error: $error");
        _setError("Auth listener error: ${error.toString().split(':').last.trim()}");
        captureException(error, stackTrace: stackTrace, hintText: "Error in AuthStateChange stream listener");
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (needsInitialSync && _navigatorContext != null && _navigatorContext!.mounted && _token != null && isAuthenticated) {
        _syncOnboardingDataAfterAuth(_navigatorContext!, _token!);
      }
      notifyListeners();
    });
    if (kDebugMode) print("AuthProvider: Initialization complete. Listening for auth changes.");
  }

  void _handleAuthStateChange(supabase.AuthState data) {
    final supabase.AuthChangeEvent event = data.event;
    final supabase.Session? session = data.session;
    bool needsUiUpdate = false;
    bool isSignificantAuthChange = false;

    if (kDebugMode) print("AuthProvider: Received auth event: $event, Session exists: ${session != null}");
    addBreadcrumb(message: 'Auth state change', category: 'auth', data: {'event': event.name, 'hasSession': session != null});

    final User? previousUser = _user;
    final String? previousToken = _token;

    switch (event) {
      case supabase.AuthChangeEvent.signedIn:
      case supabase.AuthChangeEvent.mfaChallengeVerified:
        if (session != null) {
          _token = session.accessToken;
          final supabaseUser = session.user;
          try {
            _user = User.fromSupabaseUser(supabaseUser);
            if (_user != null) {
              // Corrected Sentry setUser call
              setUser(_user!.id, email: _user!.email, name: _user!.name);
            }
            _error = null;
            if (event == supabase.AuthChangeEvent.signedIn || (previousUser == null && _user != null) ) {
              isSignificantAuthChange = true;
            }
          } catch (e, stackTrace) { _user = null; _token = null; captureException(e, stackTrace: stackTrace, hintText: "Error creating User in _handleAuthStateChange (SignedIn)");}
        } else {
          if (_token != null || _user != null) { _token = null; _user = null; isSignificantAuthChange = true; }
        }
        break;

      case supabase.AuthChangeEvent.tokenRefreshed:
      case supabase.AuthChangeEvent.userUpdated:
        if (session != null) {
          _token = session.accessToken;
          final supabaseUser = session.user;
          try {
            _user = User.fromSupabaseUser(supabaseUser);
            if (_user != null) { setUser(_user!.id, email: _user!.email, name: _user!.name); } // Corrected
          } catch (e, st) { captureException(e, stackTrace: st, hintText: "Error creating User from updated/refreshed Supabase user"); }
        } else {
          if (_token != null || _user != null) { _token = null; _user = null; isSignificantAuthChange = true; }
        }
        break;

      case supabase.AuthChangeEvent.userDeleted:
      case supabase.AuthChangeEvent.signedOut:
        if (_token != null || _user != null) {
          _token = null; _user = null; _error = null;
          clearUser(); // Sentry - this takes 0 arguments as per your sentry_config.dart
          isSignificantAuthChange = true;
        }
        break;

      case supabase.AuthChangeEvent.passwordRecovery:
        break;

      case supabase.AuthChangeEvent.initialSession:
        if (session != null) {
          if (_user == null || _token == null) {
            _token = session.accessToken;
            final supabaseUser = session.user;
            try {
              _user = User.fromSupabaseUser(supabaseUser);
              if (_user != null) { setUser(_user!.id, email: _user!.email, name: _user!.name); isSignificantAuthChange = true; } // Corrected
            } catch (e, st) { captureException(e, stackTrace: st, hintText: "Error from User.fromSupabaseUser in initialSession listener"); _user = null; _token = null;}
          }
        } else {
          if (_token != null || _user != null) { _token = null; _user = null; isSignificantAuthChange = true; }
        }
        break;
    }

    if (previousToken != _token || previousUser?.id != _user?.id || (_error != null && (previousUser?.id != _user?.id || previousToken != _token ))) {
      needsUiUpdate = true;
    }

    if (isSignificantAuthChange && isAuthenticated && _navigatorContext != null && _token != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_navigatorContext != null && _navigatorContext!.mounted) {
          _syncOnboardingDataAfterAuth(_navigatorContext!, _token!);
        }
      });
    }

    if (needsUiUpdate) {
      if (kDebugMode) print("AuthProvider: Notifying listeners due to state change (Event: $event) - User: ${_user?.id}, Token: ${_token != null}, AuthError: $_error");
      notifyListeners();
    }
  }

  Future<void> _syncOnboardingDataAfterAuth(BuildContext context, String token) async {
    if (!context.mounted) { if (kDebugMode) print("AuthProvider: _syncOnboardingDataAfterAuth - Context not mounted, skipping."); return; }
    addBreadcrumb(message: 'AuthProvider: Syncing onboarding data & subscriptions post-auth', category: 'auth_post_sync');
    if (kDebugMode) print("AuthProvider: Attempting to sync onboarding data & subscriptions post-authentication for token: $token");
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    UserPreferences? onboardingPrefs = userProvider.onboardingPreferencesHolder;
    if (onboardingPrefs != null) {
      if (kDebugMode) print("AuthProvider: Found cached onboarding preferences. Attempting to sync to backend.");
      addBreadcrumb(message: 'AuthProvider: Syncing cached onboarding preferences to backend', category: 'auth_post_sync', data: onboardingPrefs.toJson());
      try {
        // Corrected: Pass token as named parameter if AuthService.updatePreferences expects it.
        // Your AuthService.updatePreferences(UserPreferences preferences) only takes one positional.
        await userProvider.updatePreferences(token, onboardingPrefs);
        if (kDebugMode) print("AuthProvider: Onboarding preferences successfully synced to backend.");
      } catch (e, st) {
        if (kDebugMode) print("AuthProvider: Error syncing onboarding preferences to backend: $e");
        captureException(e, stackTrace: st, hintText: 'Failed to sync onboarding preferences to backend in AuthProvider');
      }
    } else {
      if (kDebugMode) print("AuthProvider: No cached onboarding preferences. Ensuring existing preferences are loaded.");
      await userProvider.getUserPreferences(token).catchError((e, st) {
        captureException(e, stackTrace: st, hintText: 'Failed to load user preferences post-auth (no onboarding cache)');
      });
    }
    if (kDebugMode) print("AuthProvider: Refreshing RevenueCat status and syncing with our backend.");
    await subProvider.revenueCatSubscriptionStatus(token).catchError((e, st) {
      captureException(e, stackTrace: st, hintText: 'Failed to refresh/sync RevenueCat subscription post-auth');
    });
    if (kDebugMode) print("AuthProvider: Post-auth sync operations complete.");
  }

  @override
  void dispose() {
    if (kDebugMode) print("AuthProvider: Disposing - Cancelling auth state subscription.");
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _setError(String errorMessage) {
    if (_error != errorMessage) {
      _error = errorMessage;
      if (_error != null) {
        addBreadcrumb(message: 'AuthProvider error set', category: 'auth_error', data: {'error': _error}, level: SentryLevel.error);
      }
      notifyListeners();
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    _isLoading = true; clearError(); notifyListeners();
    addBreadcrumb(message: 'Sign-up attempt', category: 'auth_action', data: {'email': email, 'name': name});
    try {
      await _authService.signUp(email, password, name);
      if (kDebugMode) debugPrint("AuthProvider: signUp service call successful. Supabase onAuthStateChange listener will handle state update.");
    } catch (e, stackTrace) {
      final errorMsg = e.toString().replaceFirst("Exception: ", "").split(':').last.trim();
      _setError(errorMsg);
      captureException(e, stackTrace: stackTrace, hintText: "Error during AuthProvider.signUp");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true; clearError(); notifyListeners();
    addBreadcrumb(message: 'Sign-in attempt', category: 'auth_action', data: {'email': email});
    try {
      await _authService.signIn(email, password);
      if (kDebugMode) print("AuthProvider: signIn service call successful. Supabase onAuthStateChange listener will handle state update.");
    } catch (e, stackTrace) {
      final errorMsg = e.toString().replaceFirst("Exception: ", "").split(':').last.trim();
      _setError(errorMsg);
      captureException(e, stackTrace: stackTrace, hintText: "Error during AuthProvider.signIn");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true; clearError(); notifyListeners();
    addBreadcrumb(message: 'Sign-out attempt', category: 'auth_action');
    try {
      await _authService.signOut();
      await Purchases.logOut().catchError((e,st) {
        captureException(e, stackTrace: st, hintText: "Error during RevenueCat logOut on sign out");
      });
      if (_user != null || _token != null) { _user = null; _token = null; clearUser(); }
      if(_navigatorContext != null && _navigatorContext!.mounted) {
        Provider.of<UserProvider>(_navigatorContext!, listen: false).clearOnboardingPreferences();
        Provider.of<UserProvider>(_navigatorContext!, listen: false).syncExternalPreferencesUpdate(null);
      }
    } catch (e, stackTrace) {
      final errorMsg = e.toString().replaceFirst("Exception: ", "").split(':').last.trim();
      _setError(errorMsg);
      captureException(e, stackTrace: stackTrace, hintText: "Error during AuthProvider.signOut process");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getCurrentUserProfile() async {
    if (!isAuthenticated || _token == null) {
      if (kDebugMode) print("AuthProvider: Cannot get current user profile, user not authenticated or token missing.");
      return;
    }
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    addBreadcrumb(message: 'Refreshing user profile via AuthProvider.getCurrentUserProfile', category: 'auth_profile', data: {'userId': _user?.id});
    try {
      // This call assumes _authService.getCurrentUser() exists and returns Future<User?>
      final detailedUserFromService = await _authService.getCurrentUser();

      bool userObjectChanged = _user?.id != detailedUserFromService?.id ||
          _user?.email != detailedUserFromService?.email ||
          _user?.name != detailedUserFromService?.name;

      bool preferencesObjectChanged = !const DeepCollectionEquality().equals(_user?.preferences, detailedUserFromService?.preferences);

      if (detailedUserFromService != null && (userObjectChanged || preferencesObjectChanged)) {
        _user = detailedUserFromService;
        if(_user != null) {
          // Corrected Sentry setUser call
          setUser(_user!.id, email: _user!.email, name: _user!.name);
        }

        if (_user?.preferences != null && _navigatorContext != null && _navigatorContext!.mounted) {
          Provider.of<UserProvider>(_navigatorContext!, listen: false)
              .syncExternalPreferencesUpdate(_user!.preferences!);
        }
        if (kDebugMode) print("AuthProvider: User profile data refreshed and updated in AuthProvider for user: ${_user?.id}");
      } else if (detailedUserFromService == null) {
        if (kDebugMode) print("AuthProvider: getCurrentUserProfile service returned null. User state not changed.");
      } else {
        if (kDebugMode) print("AuthProvider: User profile data fetched, no change detected.");
      }
      _error = null;
    } catch(e, stackTrace) {
      final errorMsg = e.toString().replaceFirst("Exception: ", "").split(':').last.trim();
      if (kDebugMode) print("AuthProvider: Failed to refresh user profile: $errorMsg");
      _setError("Could not refresh profile: $errorMsg");
      captureException(e, stackTrace: stackTrace, hintText: "Error refreshing profile in AuthProvider.getCurrentUserProfile");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    final currentUser = _user;
    // final currentToken = _token; // Token is fetched inside AuthService.updatePreferences

    if (currentUser == null) { // Only need to check for currentUser, token is handled by AuthService
      _setError("You must be logged in to update preferences.");
      if (kDebugMode) print("AuthProvider: Cannot update preferences, user not available.");
      return;
    }
    _isLoading = true; clearError(); notifyListeners();
    addBreadcrumb(message: 'Updating user preferences via AuthProvider.updatePreferences', category: 'auth_preferences', data: {'userId': currentUser.id});
    try {
      // Call _authService.updatePreferences matching its actual signature (takes only preferences)
      final UserPreferences updatedPreferences = await _authService.updatePreferences(preferences);

      if (_user != null) {
        // Ensure User model has copyWith method
        _user = _user!.copyWith(preferences: updatedPreferences);
      }

      if (kDebugMode) print("AuthProvider: Preferences updated successfully via AuthProvider for user ${_user?.id}.");

      if (_navigatorContext != null && _navigatorContext!.mounted) {
        // The syncExternalPreferencesUpdate in UserProvider does not require a token
        Provider.of<UserProvider>(_navigatorContext!, listen: false)
            .syncExternalPreferencesUpdate(updatedPreferences);
      }
      _error = null;

    } catch (e, stackTrace) {
      final errorMsg = e.toString().replaceFirst("Exception: ", "").split(':').last.trim();
      _setError(errorMsg);
      captureException(e, stackTrace: stackTrace, hintText: "Error in AuthProvider.updatePreferences");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}