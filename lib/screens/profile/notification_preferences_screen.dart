// lib/screens/profile/notification_preferences_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({Key? key}) : super(key: key);

  @override
  _NotificationPreferencesScreenState createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _isLoading = true;
  bool _recipeRecommendations = true;
  bool _weeklyDigest = true;
  bool _appUpdates = true;
  bool _cookingReminders = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _recipeRecommendations = prefs.getBool('notify_recipes') ?? true;
        _weeklyDigest = prefs.getBool('notify_digest') ?? true;
        _appUpdates = prefs.getBool('notify_updates') ?? true;
        _cookingReminders = prefs.getBool('notify_reminders') ?? false;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notification preferences: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      print('Error saving notification preference: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preference: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'Choose which notifications you\'d like to receive from Delisio.',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Recipe Recommendations'),
                  subtitle: const Text(
                      'Personalized recipe ideas based on your preferences'),
                  value: _recipeRecommendations,
                  onChanged: (value) {
                    setState(() {
                      _recipeRecommendations = value;
                    });
                    _savePreference('notify_recipes', value);
                  },
                  secondary: Icon(
                    Icons.restaurant,
                    color: theme.primaryColor,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Weekly Digest'),
                  subtitle: const Text(
                      'A roundup of popular recipes and cooking tips'),
                  value: _weeklyDigest,
                  onChanged: (value) {
                    setState(() {
                      _weeklyDigest = value;
                    });
                    _savePreference('notify_digest', value);
                  },
                  secondary: Icon(
                    Icons.auto_awesome,
                    color: theme.primaryColor,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('App Updates'),
                  subtitle: const Text(
                      'Information about new features and improvements'),
                  value: _appUpdates,
                  onChanged: (value) {
                    setState(() {
                      _appUpdates = value;
                    });
                    _savePreference('notify_updates', value);
                  },
                  secondary: Icon(
                    Icons.system_update,
                    color: theme.primaryColor,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Cooking Reminders'),
                  subtitle: const Text(
                      'Gentle nudges to try your saved recipes'),
                  value: _cookingReminders,
                  onChanged: (value) {
                    setState(() {
                      _cookingReminders = value;
                    });
                    _savePreference('notify_reminders', value);
                  },
                  secondary: Icon(
                    Icons.alarm,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Note: You can change these preferences at any time. Notifications may still be affected by your device settings.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}