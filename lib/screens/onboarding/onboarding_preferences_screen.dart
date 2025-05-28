// lib/screens/onboarding/onboarding_preferences_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Corrected relative import paths assuming 'delisio' structure
import '../../models/user_preferences.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/sentry_config.dart'; // Assuming this path

// Display values for the cooking skill dropdown
const List<String> _cookingSkillLevelsDisplay = ['Beginner', 'Intermediate', 'Advanced'];
// Actual values to be saved (lowercase)
const List<String> _cookingSkillLevelsValues = ['beginner', 'intermediate', 'advanced'];

const List<String> _allDietaryRestrictions = ['Vegetarian', 'Vegan', 'Gluten-Free', 'Keto', 'Paleo', 'Pescatarian'];
const List<String> _allCuisines = ['Italian', 'Mexican', 'Indian', 'Chinese', 'Thai', 'Mediterranean', 'French', 'Japanese', 'Spanish', 'Greek'];
const List<String> _allAllergies = ['Peanuts', 'Shellfish', 'Dairy', 'Eggs', 'Soy', 'Tree Nuts', 'Wheat', 'Fish', 'Sesame'];


class OnboardingPreferencesScreen extends StatefulWidget {
  const OnboardingPreferencesScreen({Key? key}) : super(key: key);

  @override
  _OnboardingPreferencesScreenState createState() => _OnboardingPreferencesScreenState();
}

class _OnboardingPreferencesScreenState extends State<OnboardingPreferencesScreen> {
  List<String> _selectedDietaryRestrictions = [];
  List<String> _selectedFavoriteCuisines = [];
  List<String> _selectedAllergies = [];
  String _selectedCookingSkillDisplay = _cookingSkillLevelsDisplay.first; // Tracks the display value

  bool _isLoading = false;

  void _toggleSelection(List<String> currentSelection, String item, {int maxSelection = 5}) {
    setState(() {
      if (currentSelection.contains(item)) {
        currentSelection.remove(item);
      } else {
        if (currentSelection.length < maxSelection) {
          currentSelection.add(item);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You can select up to $maxSelection items for this category.')),
          );
        }
      }
    });
  }

  Future<void> _savePreferencesAndContinue() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Convert selected display skill to its corresponding lowercase value for saving
    final int selectedSkillIndex = _cookingSkillLevelsDisplay.indexOf(_selectedCookingSkillDisplay);
    final String cookingSkillToSave = _cookingSkillLevelsValues[selectedSkillIndex];

    final preferencesToSave = UserPreferences(
      dietaryRestrictions: _selectedDietaryRestrictions,
      favoriteCuisines: _selectedFavoriteCuisines,
      allergies: _selectedAllergies,
      cookingSkill: cookingSkillToSave, // *** Save the lowercase value ***
    );

    debugPrint("OnboardingPreferencesScreen: Caching preferences with cookingSkill: '${preferencesToSave.cookingSkill}'");
    userProvider.setLocalPreferences(preferencesToSave);
    addBreadcrumb(message: 'User set preferences during onboarding', category: 'onboarding', data: preferencesToSave.toJson());

    if (authProvider.isAuthenticated && authProvider.token != null) {
      try {
        await userProvider.updatePreferences(authProvider.token!, preferencesToSave);
        debugPrint("Onboarding: Preferences updated to backend immediately (user was already authenticated).");
      } catch (e) {
        debugPrint("Onboarding: Failed to update prefs to backend immediately during onboarding (user was authenticated): $e");
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacementNamed('/onboarding_paywall');
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildMultiSelectChipGroup(List<String> options, List<String> selectedOptions, ThemeData theme) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: options.map((item) {
        final bool isSelected = selectedOptions.contains(item);
        return ChoiceChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (bool selected) {
            _toggleSelection(selectedOptions, item);
          },
          selectedColor: theme.colorScheme.secondary,
          labelStyle: TextStyle(
              color: isSelected ? (theme.colorScheme.onSecondary) : theme.textTheme.bodyLarge?.color,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal
          ),
          backgroundColor: theme.chipTheme.backgroundColor ?? Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected ? theme.colorScheme.secondary : (theme.chipTheme.shape as StadiumBorder?)?.side.color ?? Colors.grey.shade400,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: theme.dividerColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: theme.dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor ?? Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
      ),
      value: _selectedCookingSkillDisplay, // Dropdown uses the display value
      items: _cookingSkillLevelsDisplay.map((String displayValue) {
        return DropdownMenuItem<String>(
          value: displayValue,
          child: Text(displayValue),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedCookingSkillDisplay = newValue; // Update the display state
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Culinary Profile'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text( "Help us tailor your experience!", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text( "Select your preferences below. You can always change these later in your profile.", style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            _buildSectionTitle('Any Dietary Restrictions? (Max 5)'),
            _buildMultiSelectChipGroup(_allDietaryRestrictions, _selectedDietaryRestrictions, theme),
            const SizedBox(height: 24),
            _buildSectionTitle('Favorite Cuisines? (Max 5)'),
            _buildMultiSelectChipGroup(_allCuisines, _selectedFavoriteCuisines, theme),
            const SizedBox(height: 24),
            _buildSectionTitle('Known Allergies? (Max 5)'),
            _buildMultiSelectChipGroup(_allAllergies, _selectedAllergies, theme),
            const SizedBox(height: 24),
            _buildSectionTitle('Your Cooking Skill Level'),
            _buildSkillDropdown(theme),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
                onPressed: _savePreferencesAndContinue,
                child: const Text('Next: Subscription'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}