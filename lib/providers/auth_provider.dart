import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Required for WidgetsBinding
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../services/auth_service.dart';
import '../config/sentry_config.dart';

class AuthProvider with ChangeNotifier {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  final AuthService _authService = AuthService();
  StreamSubscription<supabase.AuthState>? _authStateSubscription;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  // --- Getters ---
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _user != null;

  // --- Constructor ---
  AuthProvider() {
    if (kDebugMode) print("AuthProvider: Initializing...");
    _initialize();
  }

  // --- Initialization ---
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
              category: 'auth',
              data: {'userId': _user!.id},
            );
          }
        } catch (e, stackTrace) {
          if (kDebugMode) print("AuthProvider: Error creating User model from initial Supabase user: $e");
          captureException(e, stackTrace: stackTrace); // No hint needed here or it's a generic issue
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
        captureException(error, stackTrace: stackTrace); // No hint needed here or it's a generic issue
      },
    );
    // Defer initial notification to avoid issues if AuthProvider is created during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (/* check if still relevant, though for a provider it's usually always relevant */ true) {
        notifyListeners();
      }
    });
    if (kDebugMode) print("AuthProvider: Initialization complete. Listening for auth changes.");
  }

  // --- Auth State Change Handler ---
  void _handleAuthStateChange(supabase.AuthState data) {
    final supabase.AuthChangeEvent event = data.event;
    final supabase.Session? session = data.session;
    bool changed = false;

    if (kDebugMode) print("AuthProvider: Received auth event: $event, Session exists: ${session != null}");
    addBreadcrumb(
      message: 'Auth state change',
      category: 'auth',
      data: {'event': event.name, 'hasSession': session != null},
    );

    switch (event) {
      case supabase.AuthChangeEvent.signedIn:
      case supabase.AuthChangeEvent.tokenRefreshed:
      case supabase.AuthChangeEvent.userUpdated:
        User? potentialNewUser; String? potentialNewToken;
        if (session != null) {
          potentialNewToken = session.accessToken;
          final supabaseUser = session.user;
          try {
            potentialNewUser = User.fromSupabaseUser(supabaseUser);
            if (potentialNewUser != null) {
              setUser(potentialNewUser.id, email: potentialNewUser.email, name: potentialNewUser.name);
            }
          }
          catch (e, stackTrace) {
            if (kDebugMode) print("Auth Listener User Model Error: $e");
            captureException(e, stackTrace: stackTrace); // No hint needed here or it's a generic issue
            potentialNewUser = null; potentialNewToken = null;
          }
        } else { potentialNewUser = null; potentialNewToken = null; }
        if (_token != potentialNewToken || _user?.id != potentialNewUser?.id) {
          _token = potentialNewToken; _user = potentialNewUser; _error = null; changed = true;
          if (kDebugMode) print("AuthProvider: State updated (SignedIn/TokenRefresh/UserUpdate) - User: ${_user?.id}, Token: ${_token != null}");
        }
        break;

      case supabase.AuthChangeEvent.userDeleted:
      case supabase.AuthChangeEvent.signedOut:
        if (_token != null || _user != null) {
          _token = null; _user = null; _error = null; changed = true;
          clearUser();
          if (kDebugMode) print("AuthProvider: State updated - User signed out (Event: $event).");
        }
        break;

      case supabase.AuthChangeEvent.passwordRecovery:
        if (_token != null || _user != null) {
          _token = null; _user = null; _error = null; changed = true;
          clearUser();
          if (kDebugMode) print("AuthProvider: Password recovery event - User signed out.");
        }
        break;

      case supabase.AuthChangeEvent.initialSession:
        if (kDebugMode) print("AuthProvider: Received initialSession event again. Session: ${session != null}");
        if (session != null && _user == null) { // Only update if user wasn't set initially
          final supabaseUser = session.user;
          try {
            User? initialUser = User.fromSupabaseUser(supabaseUser);
            if (initialUser != null) {
              _user = initialUser;
              _token = session.accessToken;
              setUser(_user!.id, email: _user!.email, name: _user!.name);
              changed = true;
              if (kDebugMode) print("AuthProvider: User re-established from initialSession event.");
            }
          } catch (e, stackTrace) {
            captureException(e, stackTrace: stackTrace, hintText: "Error creating user from initialSession event"); // MODIFIED
          }
        }
        break;

      case supabase.AuthChangeEvent.mfaChallengeVerified:
        if (kDebugMode) print("AuthProvider: MFA Challenge Verified event received.");
        User? mfaUser; String? mfaToken;
        if (session != null) {
          mfaToken = session.accessToken;
          mfaUser = User.fromSupabaseUser(session.user);
          if (mfaUser != null) {
            setUser(mfaUser.id, email: mfaUser.email, name: mfaUser.name);
          }
        }
        if (_token != mfaToken || _user?.id != mfaUser?.id) {
          _token = mfaToken; _user = mfaUser; _error = null; changed = true;
          if (kDebugMode) print("AuthProvider: State updated after MFA - User: ${_user?.id}, Token: ${_token != null}");
        }
        break;
    }

    if (changed) {
      notifyListeners();
    }
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
          category: 'error',
          data: {'error': _error},
          level: SentryLevel.error,
        );
      }
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Sign-up attempt', category: 'auth', data: {'email': email, 'name': name});
    try {
      await _authService.signUp(email, password, name);
      if (kDebugMode) debugPrint("AuthProvider: signUp service call successful (state update relies on listener).");
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint("AuthProvider: signUp failed: $e");
      _setError(e.toString());
      captureException(e, stackTrace: stackTrace); // No hint needed or generic
      rethrow;
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Sign-in attempt', category: 'auth', data: {'email': email});
    try {
      await _authService.signIn(email, password);
      if (kDebugMode) print("AuthProvider: signIn service call successful (state update relies on listener).");
    } catch (e, stackTrace) {
      if (kDebugMode) print("AuthProvider: signIn failed: $e");
      _setError(e.toString());
      captureException(e, stackTrace: stackTrace); // No hint needed or generic
      rethrow;
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    addBreadcrumb(message: 'Sign-out attempt', category: 'auth');
    try {
      if (kDebugMode) print("AuthProvider: Calling Supabase signOut service...");
      await _authService.signOut();

      if (kDebugMode) print("AuthProvider: Calling RevenueCat Purchases.logOut()...");
      await Purchases.logOut();
      if (kDebugMode) print("AuthProvider: RevenueCat Purchases.logOut() called successfully.");

      clearUser();
      if (kDebugMode) print("AuthProvider: signOut process successful (local state update relies on listener).");
    } catch (e, stackTrace) {
      if (kDebugMode) print("AuthProvider: signOut failed: $e");
      _setError(e.toString());
      captureException(e, stackTrace: stackTrace, hintText: "Error during signOut process"); // MODIFIED
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> getCurrentUserProfile() async {
    if (_user == null) {
      if (kDebugMode) print("AuthProvider: Cannot get current user profile, provider user is null.");
      return;
    }
    _isLoading = true; _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    addBreadcrumb(message: 'Refreshing user profile', category: 'auth', data: {'userId': _user?.id});
    try {
      final detailedUser = await _authService.getCurrentUser();
      bool changed = (_user?.id != detailedUser?.id ||
          _user?.email != detailedUser?.email ||
          _user?.name != detailedUser?.name ||
          _user?.preferences != detailedUser?.preferences);
      _user = detailedUser;
      if (_user != null && changed) {
        setUser(_user!.id, email: _user!.email, name: _user!.name);
      }
      if (kDebugMode) print("AuthProvider: User profile refreshed: ${_user?.id}");
      _error = null;
    } catch(e, stackTrace) {
      if (kDebugMode) print("AuthProvider: Failed to refresh user profile: $e");
      _setError("Could not refresh profile: ${e.toString()}");
      captureException(e, stackTrace: stackTrace); // No hint needed or generic
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    final currentUser = _user;
    if (currentUser == null) {
      if (kDebugMode) print("AuthProvider: Cannot update preferences, user not available in provider.");
      _setError("You must be logged in to update preferences.");
      return;
    }
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Updating user preferences', category: 'auth', data: {'userId': currentUser.id});
    try {
      final updatedPreferences = await _authService.updatePreferences(preferences);
      _user = User(
          id: currentUser.id, email: currentUser.email, name: currentUser.name,
          createdAt: currentUser.createdAt, preferences: updatedPreferences
      );
      if (kDebugMode) print("AuthProvider: Preferences updated successfully for user ${_user?.id}.");
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) print("AuthProvider: updatePreferences failed: $e");
      _setError(e.toString());
      captureException(e, stackTrace: stackTrace); // No hint needed or generic
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
}