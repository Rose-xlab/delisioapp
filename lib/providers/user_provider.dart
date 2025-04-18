// providers/user_provider.dart
import 'package:flutter/foundation.dart';
import '../models/user_preferences.dart';
import '../services/user_service.dart';

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

    try {
      final preferences = await _userService.getUserPreferences(token);
      _preferences = preferences;
    } catch (e) {
      _error = e.toString();
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

    try {
      final updatedPreferences = await _userService.updatePreferences(token, preferences);
      _preferences = updatedPreferences;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}