import 'package:flutter/foundation.dart';
import '../models/user_preferences.dart';
import '../services/user_service.dart';
import '../config/sentry_config.dart'; // Import Sentry config

class UserProvider with ChangeNotifier {
  UserPreferences? _preferences;
  bool _isLoading = false;
  String? _error;

  final UserService _userService = UserService();

  UserPreferences? get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get user preferences
  Future<void> getUserPreferences(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add breadcrumb for loading preferences
    addBreadcrumb(
      message: 'Loading user preferences',
      category: 'user',
    );

    try {
      final preferences = await _userService.getUserPreferences(token);
      _preferences = preferences;

      // Add breadcrumb with basic preference info
      if (preferences != null) {
        addBreadcrumb(
          message: 'User preferences loaded',
          category: 'user',
          data: {
            'cookingSkill': preferences.cookingSkill,
            'hasDietaryRestrictions': preferences.dietaryRestrictions.isNotEmpty,
            'hasAllergies': preferences.allergies.isNotEmpty,
          },
        );
      } else {
        addBreadcrumb(
          message: 'No user preferences found',
          category: 'user',
        );
      }
    } catch (e, stackTrace) { // Added stackTrace
      _error = e.toString();

      // Log to Sentry
      captureException(e,
          stackTrace: stackTrace, // Pass stackTrace
          hintText: 'Error loading user preferences' // MODIFIED: hint to hintText
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user preferences
  Future<void> updatePreferences(String token, UserPreferences preferences) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add breadcrumb for updating preferences
    addBreadcrumb(
      message: 'Updating user preferences',
      category: 'user',
      data: {
        'cookingSkill': preferences.cookingSkill,
        'dietaryRestrictionsCount': preferences.dietaryRestrictions.length,
        'allergiesCount': preferences.allergies.length,
      },
    );

    try {
      final updatedPreferences = await _userService.updatePreferences(token, preferences);
      _preferences = updatedPreferences;

      // Add breadcrumb for successful update
      addBreadcrumb(
        message: 'User preferences updated successfully',
        category: 'user',
      );
    } catch (e, stackTrace) { // Added stackTrace
      _error = e.toString();

      // Log to Sentry
      captureException(e,
          stackTrace: stackTrace, // Pass stackTrace
          hintText: 'Error updating user preferences' // MODIFIED: hint to hintText
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}