// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Required for WidgetsBinding
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

// Using relative paths for internal project files
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../services/auth_service.dart';
import '../config/sentry_config.dart';

// Added for onboarding sync, using relative paths
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

  void _initialize() {
    final currentSession = _supabase.auth.currentSession;
    if (currentSession != null) {
      if (kDebugMode) print("AuthProvider: Found initial session.");
      _token = currentSession.accessToken;
      final supabaseUser = _supabase.auth.currentUser;
      if (supabaseUser != null) {
        try {
          _user = User.fromSupabaseUser(supabaseUser);
          if (kDebugMode) print("AuthProvider: Initial user set from session: ${_user?.id}");
          if (_user != null) {
            setUser(_user!.id, email: _user!.email, name: _user!.name);
            addBreadcrumb(
              message: 'User initialized from existing session',
              category: 'auth', data: {'userId': _user!.id},
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_navigatorContext != null && _token != null && isAuthenticated) {
                _syncOnboardingDataAfterAuth(_navigatorContext!, _token!);
              }
            });
          }
        } catch (e, stackTrace) {
          if (kDebugMode) print("AuthProvider: Error creating User model from initial Supabase user: $e");
          captureException(e, stackTrace: stackTrace, hintText: "Error creating User model from initial Supabase user");
          _user = null; _token = null;
        }
      } else {
        if (kDebugMode) print("AuthProvider: Initial session exists, but currentUser is null.");
        _token = null; _user = null;
      }
    } else {
      if (kDebugMode) print("AuthProvider: No initial session found.");
      _token = null; _user = null;
    }

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (error, stackTrace) {
        if (kDebugMode) print("AuthProvider: AuthStateChange Stream Error: $error");
        _setError("Auth listener error: ${error.toString()}");
        captureException(error, stackTrace: stackTrace, hintText: "Error in AuthStateChange stream listener");
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (true) {
        notifyListeners();
      }
    });
    if (kDebugMode) print("AuthProvider: Initialization complete. Listening for auth changes.");
  }

  void _handleAuthStateChange(supabase.AuthState data) {
    final supabase.AuthChangeEvent event = data.event;
    final supabase.Session? session = data.session;
    bool needsNotify = false;
    bool justSignedInOrUserEstablished = false;

    if (kDebugMode) print("AuthProvider: Received auth event: $event, Session exists: ${session != null}");
    addBreadcrumb(message: 'Auth state change', category: 'auth', data: {'event': event.name, 'hasSession': session != null});

    User? previousUser = _user;
    String? previousToken = _token;

    switch (event) {
      case supabase.AuthChangeEvent.signedIn:
      case supabase.AuthChangeEvent.tokenRefreshed:
      case supabase.AuthChangeEvent.userUpdated:
      case supabase.AuthChangeEvent.mfaChallengeVerified:
        if (session != null) {
          _token = session.accessToken;
          final supabaseUser = session.user;
          try {
            _user = User.fromSupabaseUser(supabaseUser);
            if (_user != null) {
              setUser(_user!.id, email: _user!.email, name: _user!.name);
            }
            _error = null;
            if (event == supabase.AuthChangeEvent.signedIn ||
                (event == supabase.AuthChangeEvent.mfaChallengeVerified && previousUser == null) ) {
              justSignedInOrUserEstablished = true;
            }
          } catch (e, stackTrace) {
            if (kDebugMode) print("Auth Listener User Model Error: $e");
            captureException(e, stackTrace: stackTrace, hintText: "Error creating User model from auth event session");
            _user = null; _token = null;
          }
        } else {
          if (_token != null) {
            _user = null; _token = null;
          }
        }
        break;

      case supabase.AuthChangeEvent.userDeleted:
      case supabase.AuthChangeEvent.signedOut:
      case supabase.AuthChangeEvent.passwordRecovery:
        if (_token != null || _user != null) {
          _token = null; _user = null; _error = null;
          clearUser();
        }
        break;

      case supabase.AuthChangeEvent.initialSession:
        if (kDebugMode) print("AuthProvider: Received initialSession event again. Session: ${session != null}");
        if (session != null && _user == null && previousUser == null) {
          final supabaseUser = session.user;
          try {
            _user = User.fromSupabaseUser(supabaseUser);
            if (_user != null) {
              _token = session.accessToken;
              setUser(_user!.id, email: _user!.email, name: _user!.name);
              if (kDebugMode) print("AuthProvider: User re-established from initialSession event listener.");
              justSignedInOrUserEstablished = true;
            }
          } catch (e, stackTrace) {
            captureException(e, stackTrace: stackTrace, hintText: "Error creating user from initialSession event listener");
            _user = null; _token = null;
          }
        }
        break;
    }

    if (previousToken != _token || previousUser?.id != _user?.id || (_error != null && previousUser == null && _user == null) ) {
      needsNotify = true;
      if (kDebugMode) print("AuthProvider: State updated (Event: $event) - User: ${_user?.id}, Token: ${_token != null}, Error: $_error");
    }

    if (justSignedInOrUserEstablished && _navigatorContext != null && _token != null && isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_navigatorContext!.mounted) {
          _syncOnboardingDataAfterAuth(_navigatorContext!, _token!);
        }
      });
    }

    if (needsNotify) {
      notifyListeners();
    }
  }

  Future<void> _syncOnboardingDataAfterAuth(BuildContext context, String token) async {
    addBreadcrumb(message: 'AuthProvider: Syncing onboarding data after authentication', category: 'auth_sync_onboarding');
    if (kDebugMode) print("AuthProvider: Attempting to sync onboarding data post-authentication.");

    if (!context.mounted) {
      if (kDebugMode) print("AuthProvider: _syncOnboardingDataAfterAuth - Context is not mounted. Skipping sync.");
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);

    UserPreferences? onboardingPrefs = userProvider.onboardingPreferencesHolder;
    if (onboardingPrefs != null) {
      if (kDebugMode) print("AuthProvider: Found cached onboarding preferences. Attempting to sync.");
      addBreadcrumb(message: 'AuthProvider: Syncing cached onboarding preferences', category: 'auth_sync_onboarding', data: onboardingPrefs.toJson());
      try {
        await userProvider.updatePreferences(token, onboardingPrefs);
        if (kDebugMode) print("AuthProvider: Onboarding preferences synced to backend.");
      } catch (e, st) {
        if (kDebugMode) print("AuthProvider: Error syncing onboarding preferences: $e");
        captureException(e, stackTrace: st, hintText: 'Failed to sync onboarding preferences in AuthProvider');
      }
    } else {
      if (kDebugMode) print("AuthProvider: No cached onboarding preferences. Loading existing from backend if necessary.");
      await userProvider.getUserPreferences(token).catchError((e, st) {
        captureException(e, stackTrace: st, hintText: 'Failed to load user preferences post-auth (no onboarding cache)');
      });
    }

    if (kDebugMode) print("AuthProvider: Refreshing subscription status from RevenueCat and syncing with backend.");
    await subProvider.revenueCatSubscriptionStatus(token).catchError((e, st) {
      captureException(e, stackTrace: st, hintText: 'Failed to refresh/sync RevenueCat subscription post-auth');
    });
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
        addBreadcrumb(
          message: 'Auth error occurred',
          category: 'auth_error',
          data: {'error': _error},
          level: SentryLevel.error,
        );
      }
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Sign-up attempt', category: 'auth_action', data: {'email': email, 'name': name});
    try {
      await _authService.signUp(email, password, name);
      if (kDebugMode) debugPrint("AuthProvider: signUp service call successful. State update relies on listener.");
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint("AuthProvider: signUp failed: $e");
      _setError(e.toString().replaceFirst("Exception: ", ""));
      captureException(e, stackTrace: stackTrace, hintText: "Error during AuthProvider.signUp"); // MODIFIED: Pass original 'e'
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Sign-in attempt', category: 'auth_action', data: {'email': email});
    try {
      await _authService.signIn(email, password);
      if (kDebugMode) print("AuthProvider: signIn service call successful. State update relies on listener.");
    } catch (e, stackTrace) {
      if (kDebugMode) print("AuthProvider: signIn failed: $e");
      _setError(e.toString().replaceFirst("Exception: ", ""));
      captureException(e, stackTrace: stackTrace, hintText: "Error during AuthProvider.signIn"); // MODIFIED: Pass original 'e'
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Sign-out attempt', category: 'auth_action');
    try {
      if (kDebugMode) print("AuthProvider: Calling AuthService signOut...");
      await _authService.signOut();

      if (kDebugMode) print("AuthProvider: Calling RevenueCat Purchases.logOut()...");
      await Purchases.logOut().catchError((e,st) {
        if (kDebugMode) print("AuthProvider: Error during RevenueCat Purchases.logOut(): $e");
        captureException(e, stackTrace: st, hintText: "Error during RevenueCat logOut on sign out"); // MODIFIED: Pass original 'e'
      });
      if (kDebugMode) print("AuthProvider: RevenueCat Purchases.logOut() called.");

      _user = null; _token = null; _error = null;
      clearUser();
      if(_navigatorContext != null && _navigatorContext!.mounted) {
        Provider.of<UserProvider>(_navigatorContext!, listen: false).clearOnboardingPreferences();
      }
      if (kDebugMode) print("AuthProvider: signOut process finished.");
    } catch (e, stackTrace) {
      if (kDebugMode) print("AuthProvider: signOut failed: $e");
      _setError(e.toString().replaceFirst("Exception: ", ""));
      captureException(e, stackTrace: stackTrace, hintText: "Error during AuthProvider.signOut process"); // MODIFIED: Pass original 'e'
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getCurrentUserProfile() async {
    if (!isAuthenticated) {
      if (kDebugMode) print("AuthProvider: Cannot get current user profile, user not authenticated.");
      return;
    }
    _isLoading = true; _error = null;
    notifyListeners();

    addBreadcrumb(message: 'Refreshing user profile via AuthProvider.getCurrentUserProfile', category: 'auth_profile', data: {'userId': _user?.id});
    try {
      final detailedUser = await _authService.getCurrentUser();

      bool changed = _user?.id != detailedUser?.id ||
          _user?.email != detailedUser?.email ||
          _user?.name != detailedUser?.name ||
          !listEquals(_user?.preferences?.dietaryRestrictions, detailedUser?.preferences?.dietaryRestrictions) ||
          !listEquals(_user?.preferences?.favoriteCuisines, detailedUser?.preferences?.favoriteCuisines) ||
          !listEquals(_user?.preferences?.allergies, detailedUser?.preferences?.allergies) ||
          _user?.preferences?.cookingSkill != detailedUser?.preferences?.cookingSkill;

      _user = detailedUser;

      if (_user != null && changed) {
        setUser(_user!.id, email: _user!.email, name: _user!.name);
        if (_user!.preferences != null && _navigatorContext != null && _navigatorContext!.mounted && token != null) {
          Provider.of<UserProvider>(_navigatorContext!, listen: false)
              .syncExternalPreferencesUpdate(_user!.preferences!, token!);
        }
      }
      if (kDebugMode) print("AuthProvider: User profile refreshed via AuthProvider.getCurrentUserProfile: ${_user?.id}");
      _error = null;
    } catch(e, stackTrace) {
      if (kDebugMode) print("AuthProvider: Failed to refresh user profile via AuthProvider.getCurrentUserProfile: $e");
      _setError("Could not refresh profile: ${e.toString().replaceFirst("Exception: ", "")}");
      captureException(e, stackTrace: stackTrace, hintText: "Error refreshing profile in AuthProvider.getCurrentUserProfile"); // MODIFIED: Pass original 'e'
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    final currentUser = _user;
    if (currentUser == null) {
      if (kDebugMode) print("AuthProvider: Cannot update preferences via AuthProvider.updatePreferences, user not available.");
      _setError("You must be logged in to update preferences.");
      return;
    }
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Updating user preferences via AuthProvider.updatePreferences', category: 'auth_preferences', data: {'userId': currentUser.id});
    try {
      final updatedPreferences = await _authService.updatePreferences(preferences);
      _user = User(
          id: currentUser.id, email: currentUser.email, name: currentUser.name,
          createdAt: currentUser.createdAt, preferences: updatedPreferences
      );
      if (kDebugMode) print("AuthProvider: Preferences updated successfully via AuthProvider.updatePreferences for user ${_user?.id}.");

      if (_navigatorContext != null && _navigatorContext!.mounted && token != null) {
        Provider.of<UserProvider>(_navigatorContext!, listen: false)
            .syncExternalPreferencesUpdate(updatedPreferences, token!);
      }
      _error = null;

    } catch (e, stackTrace) {
      if (kDebugMode) print("AuthProvider: updatePreferences via AuthProvider.updatePreferences failed: $e");
      _setError(e.toString().replaceFirst("Exception: ", ""));
      captureException(e, stackTrace: stackTrace, hintText: "Error in AuthProvider.updatePreferences"); // MODIFIED: Pass original 'e'
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}