// app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/user_preferences_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/recipes/nutrition_screen.dart';
import 'providers/auth_provider.dart';
import 'theme/app_theme.dart';

class CookingAssistantApp extends StatelessWidget {
  const CookingAssistantApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cooking Assistant',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/preferences': (context) => const UserPreferencesScreen(),
        '/main': (context) => const MainNavigationScreen(),
        '/recipe': (context) => const RecipeDetailScreen(),
        '/nutrition': (context) => const NutritionScreen(),
      },
    );
  }
}