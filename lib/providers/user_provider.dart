// lib/providers/user_provider.dart
import 'package:flutter/foundation.dart';

import '../models/user_preferences.dart';
import '../services/user_service.dart'; // You'll need a UserService to interact with your backend
import '../config/sentry_config.dart';

class UserProvider with ChangeNotifier {
  UserPreferences? _preferences;
  UserPreferences? _onboardingPreferences; // Cache for onboarding
  bool _isLoading = false;
  String? _error;

  final UserService _userService = UserService();

  UserPreferences? get preferences {
    if (_onboardingPreferences != null) return _onboardingPreferences;
    return _preferences;
  }
  UserPreferences? get onboardingPreferencesHolder => _onboardingPreferences;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Called during onboarding to cache preferences locally
  void setLocalPreferences(UserPreferences newPreferences) {
    _onboardingPreferences = newPreferences;
    debugPrint("UserProvider: Local onboarding preferences cached: ${newPreferences.toJson()}");
    addBreadcrumb(message: 'Local onboarding preferences cached', category: 'user_onboarding_cache', data: newPreferences.toJson());
    // No notifyListeners() here, as this is typically called before the UI needs to react immediately to this specific cache.
    // If a UI does need to react to the cache itself, you could add it.
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
    // notifyListeners(); // Notify loading start if needed for UI

    addBreadcrumb(message: 'Attempting to load user preferences from backend', category: 'user_preferences');
    UserPreferences? loadedPreferencesFromService;
    String source = "unknown";

    try {
      loadedPreferencesFromService = await _userService.getUserPreferences(token);

      if (loadedPreferencesFromService != null) {
        _preferences = loadedPreferencesFromService;
        clearOnboardingPreferences(); // Backend data supersedes onboarding cache
        source = "backend";
        addBreadcrumb(message: 'User preferences loaded from backend', category: 'user_preferences', data: _preferences?.toJson());
      } else if (_onboardingPreferences != null) {
        // No preferences from backend, but we have cached onboarding ones.
        // This implies they might not have been synced yet.
        _preferences = _onboardingPreferences; // Use cached ones for now
        source = "onboarding_cache_pending_sync";
        addBreadcrumb(message: 'No backend preferences, using cached onboarding preferences', category: 'user_preferences', data: _preferences?.toJson());
        // Attempt to save them (updatePreferences will handle clearing _onboardingPreferences on success)
        // This auto-sync might be better handled by AuthProvider after login.
        // updatePreferences(token, _onboardingPreferences!).catchError((e, st) {
        //   captureException(e, stackTrace: st, hintText: 'Failed to auto-sync onboarding preferences in UserProvider.getUserPreferences');
        // });
      } else {
        _preferences = UserPreferences(); // Default empty if nothing found
        source = "default_fallback";
        addBreadcrumb(message: 'No backend or cached preferences, using default.', category: 'user_preferences');
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      source = "error_occurred";
      captureException(e, stackTrace: stackTrace, hintText: 'Error in UserProvider.getUserPreferences');
      if (_onboardingPreferences != null && _preferences == null) {
        _preferences = _onboardingPreferences;
        source = "onboarding_cache_after_fetch_error";
      } else if (_preferences == null) {
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

    addBreadcrumb(message: 'Attempting to update user preferences to backend', category: 'user_preferences_update', data: preferencesToUpdate.toJson());

    try {
      final updatedPreferences = await _userService.updatePreferences(token, preferencesToUpdate);
      _preferences = updatedPreferences;
      clearOnboardingPreferences(); // Successfully updated backend, clear any onboarding cache
      addBreadcrumb(message: 'User preferences updated successfully on backend', category: 'user_preferences_update', data: _preferences?.toJson());
    } catch (e, stackTrace) {
      _error = e.toString();
      captureException(e, stackTrace: stackTrace, hintText: 'Error updating user preferences to backend');
      rethrow; // Rethrow for the caller (e.g., AuthProvider) to handle if needed
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Called by AuthProvider to ensure UserProvider's state is in sync if AuthProvider fetched/updated User object
  void syncExternalPreferencesUpdate(UserPreferences? updatedPreferences) {
    if (updatedPreferences != null) {
      _preferences = updatedPreferences;
      clearOnboardingPreferences(); // External update means onboarding cache is superseded
      addBreadcrumb(message: 'User preferences model in UserProvider updated from external source (e.g., AuthProvider)', category: 'user_preferences_sync', data: updatedPreferences.toJson());
      notifyListeners();
      if (kDebugMode) {
        print("UserProvider: syncExternalPreferencesUpdate called. New preferences: ${_preferences?.toJson()}");
      }
    } else {
      // If external update provides null (e.g., user signed out and AuthProvider clears its user object),
      // reset local _preferences, but keep _onboardingPreferences if a new user might be onboarding.
      _preferences = UserPreferences(); // Reset to default
      // Do not clear _onboardingPreferences here as it might be for a new flow.
      addBreadcrumb(message: 'User preferences model in UserProvider reset due to external null update.', category: 'user_preferences_sync');
      notifyListeners();
    }
  }
}