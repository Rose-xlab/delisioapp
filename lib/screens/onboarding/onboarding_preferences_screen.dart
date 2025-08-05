// lib/screens/onboarding/onboarding_preferences_screen.dart
import 'package:flutter/material.dart';
import 'package:kitchenassistant/theme/app_colors_extension.dart';
import 'package:provider/provider.dart';

// Corrected relative import paths
import '../../models/user_preferences.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/sentry_config.dart';

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
  String _selectedCookingSkillDisplay = _cookingSkillLevelsDisplay.first;

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

    final int selectedSkillIndex = _cookingSkillLevelsDisplay.indexOf(_selectedCookingSkillDisplay);
    final String cookingSkillToSave = _cookingSkillLevelsValues[selectedSkillIndex];

    // Get existing cached preferences (if any) to update them, not overwrite
    UserPreferences currentCachedPrefs = userProvider.onboardingPreferencesHolder ?? UserPreferences();

    final preferencesToSave = currentCachedPrefs.copyWith( // Use copyWith to preserve likedFoodCategoryIds if already set
      dietaryRestrictions: _selectedDietaryRestrictions,
      favoriteCuisines: _selectedFavoriteCuisines,
      allergies: _selectedAllergies,
      cookingSkill: cookingSkillToSave,
      // likedFoodCategoryIds will be handled by the next screen or remain as is from currentCachedPrefs
    );

    debugPrint("OnboardingPreferencesScreen: Caching preferences: ${preferencesToSave.toJson()}");
    userProvider.setLocalPreferences(preferencesToSave);
    addBreadcrumb(message: 'User set general preferences during onboarding', category: 'onboarding', data: {
      'dietaryRestrictions': preferencesToSave.dietaryRestrictions,
      'favoriteCuisines': preferencesToSave.favoriteCuisines,
      'allergies': preferencesToSave.allergies,
      'cookingSkill': preferencesToSave.cookingSkill,
    });

    // If user is already authenticated at this stage, sync immediately.
    // Otherwise, AuthProvider will sync after login/signup.
    if (authProvider.isAuthenticated && authProvider.token != null) {
      try {
        await userProvider.updatePreferences(authProvider.token!, preferencesToSave);
        debugPrint("Onboarding (Preferences): Preferences updated to backend immediately (user was authenticated).");
      } catch (e) {
        debugPrint("Onboarding (Preferences): Failed to update prefs to backend immediately: $e");
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacementNamed('/onboarding_food_selection');
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildMultiSelectChipGroup(List<String> options, List<String> selectedOptions, ThemeData theme) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!;

    return Wrap(
      spacing: 8.0, runSpacing: 8.0,
      children: options.map((item) {
        final bool isSelected = selectedOptions.contains(item);
        return ChoiceChip(
          label: Text(item),
          avatar: null,
          showCheckmark: false,
          selected: isSelected,
          onSelected: (bool selected) { _toggleSelection(selectedOptions, item); },
          selectedColor: theme.colorScheme.primary,
          labelStyle: TextStyle(color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color, fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal),
          backgroundColor: theme.chipTheme.backgroundColor ?? Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (theme.chipTheme.shape as RoundedRectangleBorder?)?.side.color ?? appColors.borderLight,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: theme.dividerColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: theme.dividerColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)), filled: true, fillColor: theme.inputDecorationTheme.fillColor ?? Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0)),
      value: _selectedCookingSkillDisplay,
      items: _cookingSkillLevelsDisplay.map((String displayValue) => DropdownMenuItem<String>(value: displayValue, child: Text(displayValue))).toList(),
      onChanged: (String? newValue) { if (newValue != null) { setState(() { _selectedCookingSkillDisplay = newValue; });}},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine the correct text color for the AppBar based on its background brightness
    final appBarColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final brightness = ThemeData.estimateBrightnessForColor(appBarColor);
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Culinary Profile'),
        automaticallyImplyLeading: false,
        centerTitle: true,
        // *** UPDATED SKIP BUTTON WITH VISIBLE STYLING ***
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: textColor, // Explicitly set text color for visibility
              ),
              onPressed: _isLoading ? null : _savePreferencesAndContinue,
              child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ],
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
                child: const Text('Choose Favorite Foods'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}