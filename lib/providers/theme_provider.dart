import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/sentry_config.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = false;

  ThemeProvider() {
    _loadThemePreference();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Load theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    _isLoading = true;

    // Add breadcrumb for theme loading
    addBreadcrumb(
      message: 'Loading theme preferences',
      category: 'theme',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeMode = prefs.getString('themeMode');

      if (savedThemeMode != null) {
        if (savedThemeMode == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (savedThemeMode == 'light') {
          _themeMode = ThemeMode.light;
        } else {
          _themeMode = ThemeMode.system;
        }

        // Add breadcrumb for loaded theme
        addBreadcrumb(
          message: 'Theme loaded from preferences',
          category: 'theme',
          data: {'themeMode': _themeMode.toString()},
        );
      }
    } catch (e) {
      // Log error to Sentry
      captureException(e,
          stackTrace: StackTrace.current,
          hintText: 'Error loading theme preferences' // MODIFIED
      );

      // Default to system theme on error
      _themeMode = ThemeMode.system;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set dark mode preference
  Future<void> setDarkMode(bool isDarkMode) async {
    _isLoading = true;
    notifyListeners();

    final ThemeMode newMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;

    // Add breadcrumb for theme change
    addBreadcrumb(
      message: 'Setting theme preference',
      category: 'theme',
      data: {'isDarkMode': isDarkMode, 'newMode': newMode.toString()},
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', isDarkMode ? 'dark' : 'light');
      _themeMode = newMode;
    } catch (e) {
      // Log error to Sentry
      captureException(e,
          stackTrace: StackTrace.current,
          hintText: 'Error saving theme preference' // MODIFIED
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Toggle between light and dark mode
  Future<void> toggleTheme() async {
    final newIsDarkMode = _themeMode != ThemeMode.dark;
    await setDarkMode(newIsDarkMode);
  }

  // Set theme to system default
  Future<void> setSystemTheme() async {
    _isLoading = true;
    notifyListeners();

    // Add breadcrumb for system theme setting
    addBreadcrumb(
      message: 'Setting system theme preference',
      category: 'theme',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', 'system');
      _themeMode = ThemeMode.system;
    } catch (e) {
      // Log error to Sentry
      captureException(e,
          stackTrace: StackTrace.current,
          hintText: 'Error setting system theme' // MODIFIED
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}