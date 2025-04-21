// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart'; // Ensure User.fromSupabaseUser factory exists here
import '../models/user_preferences.dart';
import '../services/auth_service.dart';

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
        } catch (e) {
          if (kDebugMode) print("AuthProvider: Error creating User model from initial Supabase user: $e");
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
      onError: (error) {
        if (kDebugMode) print("AuthProvider: AuthStateChange Stream Error: $error");
        _setError("Auth listener error: ${error.toString()}");
      },
    );
    Future.microtask(() => notifyListeners());
    if (kDebugMode) print("AuthProvider: Initialization complete. Listening for auth changes.");
  }

  // --- Auth State Change Handler ---
  void _handleAuthStateChange(supabase.AuthState data) {
    final supabase.AuthChangeEvent event = data.event;
    final supabase.Session? session = data.session;
    bool changed = false;

    if (kDebugMode) print("AuthProvider: Received auth event: $event, Session exists: ${session != null}");

    switch (event) {
      case supabase.AuthChangeEvent.signedIn:
      case supabase.AuthChangeEvent.tokenRefreshed:
      case supabase.AuthChangeEvent.userUpdated:
        User? potentialNewUser; String? potentialNewToken;
        if (session != null) {
          potentialNewToken = session.accessToken;
          final supabaseUser = session.user;
          try { potentialNewUser = User.fromSupabaseUser(supabaseUser); }
          catch (e) { if (kDebugMode) print("Auth Listener User Model Error: $e"); potentialNewUser = null; potentialNewToken = null; }
                } else { potentialNewUser = null; potentialNewToken = null; }
        if (_token != potentialNewToken || _user?.id != potentialNewUser?.id) {
          _token = potentialNewToken; _user = potentialNewUser; _error = null; changed = true;
          if (kDebugMode) print("AuthProvider: State updated (SignedIn/TokenRefresh/UserUpdate) - User: ${_user?.id}, Token: ${_token != null}");
        }
        break;

      case supabase.AuthChangeEvent.userDeleted: // Handle deprecated case
      case supabase.AuthChangeEvent.signedOut:
      // ignore: unnecessary_null_comparison
        if (_token != null || _user != null) {
          _token = null; _user = null; _error = null; changed = true;
          if (kDebugMode) print("AuthProvider: State updated - User signed out (Event: $event).");
        }
        break;

      case supabase.AuthChangeEvent.passwordRecovery:
      // ignore: unnecessary_null_comparison
        if (_token != null || _user != null) {
          _token = null; _user = null; _error = null; changed = true;
          if (kDebugMode) print("AuthProvider: Password recovery event - User signed out.");
        }
        break;

      case supabase.AuthChangeEvent.initialSession:
        if (kDebugMode) print("AuthProvider: Received initialSession event again. Session: ${session != null}");
        break;

      case supabase.AuthChangeEvent.mfaChallengeVerified:
        if (kDebugMode) print("AuthProvider: MFA Challenge Verified event received.");
        User? mfaUser; String? mfaToken;
        if (session != null) {
          mfaToken = session.accessToken;
          // ignore: unnecessary_non_null_assertion
          mfaUser = User.fromSupabaseUser(session.user!);
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

  // --- Dispose ---
  @override
  void dispose() {
    if (kDebugMode) print("AuthProvider: Disposing - Cancelling auth state subscription.");
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // --- Error Helper ---
  void _setError(String errorMessage) {
    if (_error != errorMessage) {
      _error = errorMessage;
      notifyListeners();
    }
  }

  // --- Sign Up ---
  Future<void> signUp(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signUp(email, password, name); // Uses Supabase client now
      if (kDebugMode) print("AuthProvider: signUp service call successful (state update relies on listener).");
    } catch (e) {
      if (kDebugMode) print("AuthProvider: signUp failed: $e");
      _setError(e.toString());
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Sign In ---
  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signIn(email, password); // Uses Supabase client now
      if (kDebugMode) print("AuthProvider: signIn service call successful (state update relies on listener).");
    } catch (e) {
      if (kDebugMode) print("AuthProvider: signIn failed: $e");
      _setError(e.toString());
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // No token needed for service call now
      if (kDebugMode) print("AuthProvider: Calling signOut service...");
      await _authService.signOut(); // Uses Supabase client now
      if (kDebugMode) print("AuthProvider: signOut service call successful (state update relies on listener).");
      // Listener will clear _token and _user
    } catch (e) {
      if (kDebugMode) print("AuthProvider: signOut failed: $e");
      bool changed = false;
      if (_token != null) { _token = null; changed = true; }
      if (_user != null) { _user = null; changed = true; }
      _setError(e.toString());
      if (changed) notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- getCurrentUserProfile (Refreshes detailed user data from custom backend) ---
  Future<void> getCurrentUserProfile() async {
    // Removed token check here as AuthService gets it internally now
    if (_user == null) { // Still need to know we *have* a user concept locally
      if (kDebugMode) print("AuthProvider: Cannot get current user profile, provider user is null.");
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Call service (which gets token internally from Supabase session)
      final detailedUser = await _authService.getCurrentUser();
      bool changed = (_user != detailedUser); // Basic object check
      _user = detailedUser;
      if (kDebugMode) print("AuthProvider: User profile refreshed: ${_user?.id}");
      if (changed) notifyListeners();
    } catch(e) {
      if (kDebugMode) print("AuthProvider: Failed to refresh user profile: $e");
      _setError("Could not refresh profile: ${e.toString()}");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  // --- Update Preferences ---
  Future<void> updatePreferences(UserPreferences preferences) async {
    // Only need to check if user is conceptually logged in according to provider
    final currentUser = _user;
    if (currentUser == null) { // Check user object instead of token
      if (kDebugMode) print("AuthProvider: Cannot update preferences, user not available in provider.");
      _setError("You must be logged in to update preferences.");
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // FIX: Call service with only the preferences argument
      // Assuming AuthService signature is: Future<UserPreferences> updatePreferences(UserPreferences preferences)
      final updatedPreferences = await _authService.updatePreferences(preferences);

      // Update local user model's preferences
      _user = User( // Create new user object
          id: currentUser.id,
          email: currentUser.email,
          name: currentUser.name,
          createdAt: currentUser.createdAt,
          preferences: updatedPreferences
      );
      if (kDebugMode) print("AuthProvider: Preferences updated successfully for user ${_user?.id}.");
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("AuthProvider: updatePreferences failed: $e");
      _setError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}