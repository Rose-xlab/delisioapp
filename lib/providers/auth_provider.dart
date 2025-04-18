// providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  final AuthService _authService = AuthService();

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  // Sign up a new user
  Future<void> signUp(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signUp(email, password, name);
      _user = user;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in an existing user
  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.signIn(email, password);
      _user = result['user'];
      _token = result['session']['access_token'];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out current user
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_token != null) {
        await _authService.signOut(_token!);
      }
      _user = null;
      _token = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get current user profile
  Future<void> getCurrentUser() async {
    if (_token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.getCurrentUser(_token!);
      _user = user;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user preferences
  Future<void> updatePreferences(UserPreferences preferences) async {
    if (_token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedPreferences = await _authService.updatePreferences(_token!, preferences);
      if (_user != null) {
        _user!.preferences = updatedPreferences;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}