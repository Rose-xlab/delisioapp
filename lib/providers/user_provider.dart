// lib/providers/user_provider.dart
import 'package:flutter/foundation.dart';

// Using relative paths for internal project files
import '../models/user_preferences.dart';
import '../services/user_service.dart';
import '../config/sentry_config.dart';

class UserProvider with ChangeNotifier {
  UserPreferences? _preferences;
  UserPreferences? _onboardingPreferences; // Cache for onboarding
  bool _isLoading = false;
  String? _error;

  final UserService _userService = UserService();

  UserPreferences? get preferences {
    // Prioritize onboarding preferences if they exist and haven't been synced/overridden by backend data
    if (_onboardingPreferences != null) return _onboardingPreferences;
    return _preferences;
  }
  UserPreferences? get onboardingPreferencesHolder => _onboardingPreferences;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLocalPreferences(UserPreferences newPreferences) {
    _onboardingPreferences = newPreferences;
    debugPrint("UserProvider: Local onboarding preferences cached: ${newPreferences.toJson()}");
    addBreadcrumb(message: 'Local onboarding preferences cached', category: 'user_onboarding_cache', data: newPreferences.toJson());
  }

  void clearOnboardingPreferences() {
    if (_onboardingPreferences != null) {
      _onboardingPreferences = null;
      debugPrint("UserProvider: Cleared cached onboarding preferences.");
      addBreadcrumb(message: 'Cleared cached onboarding preferences', category: 'user_onboarding_cache');
    }
  }

  Future<void> getUserPreferences(String token) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;

    addBreadcrumb(message: 'Attempting to load user preferences', category: 'user_preferences');
    UserPreferences? loadedPreferencesFromService;
    String source = "unknown";

    try {
      loadedPreferencesFromService = await _userService.getUserPreferences(token);

      if (loadedPreferencesFromService != null) {
        _preferences = loadedPreferencesFromService;
        clearOnboardingPreferences();
        source = "backend";
        addBreadcrumb(message: 'User preferences loaded from backend', category: 'user_preferences', data: _preferences?.toJson());
      } else if (_onboardingPreferences != null) {
        _preferences = _onboardingPreferences;
        source = "onboarding_cache_pending_sync";
        addBreadcrumb(message: 'No backend preferences, using cached onboarding preferences', category: 'user_preferences', data: _preferences?.toJson());
        // Attempt to save them. updatePreferences will handle clearing _onboardingPreferences on success.
        updatePreferences(token, _onboardingPreferences!).catchError((e, st) {
          captureException(e, stackTrace: st, hintText: 'Failed to auto-sync onboarding preferences in UserProvider.getUserPreferences');
        });
      } else {
        _preferences = UserPreferences(); // Default empty preferences if nothing found
        source = "default_fallback";
        addBreadcrumb(message: 'No backend or cached preferences, using default.', category: 'user_preferences');
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      source = "error_occurred";
      captureException(e, stackTrace: stackTrace, hintText: 'Error in UserProvider.getUserPreferences');
      // Fallback logic if error occurs
      if (_onboardingPreferences != null && _preferences == null) { // If fetch failed but had onboarding cache
        _preferences = _onboardingPreferences;
        source = "onboarding_cache_after_fetch_error";
        addBreadcrumb(message: 'Error fetching backend preferences, using cached onboarding ones temporarily', category: 'user_preferences', data: _preferences?.toJson());
      } else if (_preferences == null) { // If no preferences were set at all
        _preferences = UserPreferences();
        source = "default_fallback_after_fetch_error";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print("UserProvider: Preferences set (source: $source): ${_preferences?.toJson()}");
      }
    }
  }

  Future<void> updatePreferences(String token, UserPreferences preferencesToUpdate) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    addBreadcrumb(
      message: 'Attempting to update user preferences to backend',
      category: 'user_preferences_update',
      data: preferencesToUpdate.toJson(),
    );

    try {
      final updatedPreferences = await _userService.updatePreferences(token, preferencesToUpdate);
      _preferences = updatedPreferences;
      clearOnboardingPreferences(); // Successfully updated backend, clear any cache
      addBreadcrumb(message: 'User preferences updated successfully on backend', category: 'user_preferences_update', data: _preferences?.toJson());
    } catch (e, stackTrace) {
      _error = e.toString();
      captureException(e, stackTrace: stackTrace, hintText: 'Error updating user preferences to backend');
      // Do not clear _onboardingPreferences on error, they might be needed for a retry by AuthProvider.
      rethrow; // Rethrow for the caller (e.g., AuthProvider or UI) to handle
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // THIS IS THE METHOD 'AuthProvider' IS LOOKING FOR:
  // Method to allow AuthProvider to inform UserProvider about externally updated preferences
  // (e.g., if AuthProvider's own updatePreferences method directly updates them via AuthService,
  // or if preferences are refreshed as part of the main User object in AuthProvider)
  void syncExternalPreferencesUpdate(UserPreferences updatedPreferences, String token) {
    // 'token' is passed for potential future use (e.g., validation), not strictly used in this basic version.
    _preferences = updatedPreferences;
    // If preferences are updated externally (e.g., from server via AuthProvider's profile refresh),
    // then any cached onboarding preferences are definitely stale or have been superseded.
    clearOnboardingPreferences();
    addBreadcrumb(
        message: 'User preferences model in UserProvider updated from external source',
        category: 'user_preferences_sync',
        data: updatedPreferences.toJson()
    );
    notifyListeners();
    if (kDebugMode) {
      print("UserProvider: syncExternalPreferencesUpdate called. New preferences: ${_preferences?.toJson()}");
    }
  }
}