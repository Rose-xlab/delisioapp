// lib/screens/auth/user_preferences_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Assuming relative paths
import '../../providers/auth_provider.dart';
import '../../models/user_preferences.dart';

class UserPreferencesScreen extends StatefulWidget {
  const UserPreferencesScreen({Key? key}) : super(key: key);

  @override
  _UserPreferencesScreenState createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final List<String> _selectedDietary = [];
  final List<String> _selectedCuisines = [];
  final List<String> _selectedAllergies = [];
  String _cookingSkill = 'beginner'; // Correctly lowercase
  bool _isLoading = false;

  // Sample options (already lowercase where appropriate)
  final List<String> _dietaryOptions = ['vegetarian', 'vegan', 'pescatarian', 'keto', 'paleo', 'gluten-free', 'dairy-free', 'low-carb'];
  final List<String> _cuisineOptions = ['italian', 'mexican', 'chinese', 'indian', 'japanese', 'thai', 'french', 'mediterranean', 'american', 'korean'];
  final List<String> _allergyOptions = ['nuts', 'peanuts', 'dairy', 'eggs', 'soy', 'wheat', 'fish', 'shellfish'];
  final List<Map<String, dynamic>> _skillOptions = [
    {'value': 'beginner', 'label': 'Beginner', 'description': 'I\'m new to cooking or still learning basics'},
    {'value': 'intermediate', 'label': 'Intermediate', 'description': 'I can follow recipes and have some experience'},
    {'value': 'advanced', 'label': 'Advanced', 'description': 'I\'m comfortable with most cooking techniques'},
  ];

  Future<void> _savePreferences() async {
    setState(() { _isLoading = true; });

    try {
      final preferences = UserPreferences(
        dietaryRestrictions: _selectedDietary,
        favoriteCuisines: _selectedCuisines,
        allergies: _selectedAllergies,
        cookingSkill: _cookingSkill, // Already lowercase
      );

      // This screen uses AuthProvider.updatePreferences, which directly updates via AuthService
      await Provider.of<AuthProvider>(context, listen: false).updatePreferences(preferences);

      if (mounted) {
        // Corrected navigation target
        Navigator.of(context).pushReplacementNamed('/app');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Preferences')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Your existing UI for Text, FilterChips, RadioListTiles) ...
            // Ensure the UI correctly uses _skillOptions and updates _cookingSkill
            const Text('Tell us about your preferences', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This helps us tailor recipes to your needs. You can change these anytime.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),

            const Text('Dietary Restrictions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: _dietaryOptions.map((option) { final isSelected = _selectedDietary.contains(option); return FilterChip(label: Text(option), selected: isSelected, onSelected: (selected) { setState(() { if (selected) _selectedDietary.add(option); else _selectedDietary.remove(option); }); }); }).toList()),
            const SizedBox(height: 24),

            const Text('Favorite Cuisines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: _cuisineOptions.map((option) { final isSelected = _selectedCuisines.contains(option); return FilterChip(label: Text(option), selected: isSelected, onSelected: (selected) { setState(() { if (selected) _selectedCuisines.add(option); else _selectedCuisines.remove(option); }); }); }).toList()),
            const SizedBox(height: 24),

            const Text('Allergies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: _allergyOptions.map((option) { final isSelected = _selectedAllergies.contains(option); return FilterChip(label: Text(option), selected: isSelected, onSelected: (selected) { setState(() { if (selected) _selectedAllergies.add(option); else _selectedAllergies.remove(option); }); }); }).toList()),
            const SizedBox(height: 24),

            const Text('Cooking Skill Level', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Column(children: _skillOptions.map((option) { return RadioListTile<String>(title: Text(option['label']), subtitle: Text(option['description']), value: option['value'], groupValue: _cookingSkill, onChanged: (value) { setState(() { _cookingSkill = value!; }); }); }).toList()),
            const SizedBox(height: 32),

            ElevatedButton(onPressed: _savePreferences, child: const Text('Save Preferences')),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // Corrected navigation target
                Navigator.of(context).pushReplacementNamed('/app');
              },
              child: const Text('Skip for Now'),
            ),
          ],
        ),
      ),
    );
  }
}