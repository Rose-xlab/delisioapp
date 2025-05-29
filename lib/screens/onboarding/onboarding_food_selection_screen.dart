// lib/screens/onboarding/onboarding_food_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Corrected relative import paths
import '../../models/user_preferences.dart';
import '../../providers/user_provider.dart';
import '../../constants/categories.dart';
import '../../widgets/home/category_card.dart';
import '../../config/sentry_config.dart';

class OnboardingFoodSelectionScreen extends StatefulWidget {
  const OnboardingFoodSelectionScreen({Key? key}) : super(key: key);

  @override
  _OnboardingFoodSelectionScreenState createState() =>
      _OnboardingFoodSelectionScreenState();
}

class _OnboardingFoodSelectionScreenState extends State<OnboardingFoodSelectionScreen> {
  final List<String> _selectedCategoryIds = [];
  bool _isLoading = false;

  final List<RecipeCategoryData> _allSelectableCategories = RecipeCategories.allCategories;
  static const int _maxCategorySelections = 5;

  void _toggleCategorySelection(String categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        if (_selectedCategoryIds.length < _maxCategorySelections) {
          _selectedCategoryIds.add(categoryId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Select up to $_maxCategorySelections favorite food categories.')),
          );
        }
      }
    });
  }

  Future<void> _handleSkipOrContinue() async {
    // This function is now called by both "Next" and "Skip"
    // If skipping, _selectedCategoryIds will be empty.
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    UserPreferences currentOnboardingPrefs = userProvider.onboardingPreferencesHolder ?? UserPreferences();

    // Update with the selected food category IDs (will be empty if skipped)
    final updatedPrefs = currentOnboardingPrefs.copyWith(
      likedFoodCategoryIds: _selectedCategoryIds,
    );

    userProvider.setLocalPreferences(updatedPrefs);
    if (_selectedCategoryIds.isNotEmpty) {
      addBreadcrumb(
          message: 'User selected favorite food categories during onboarding',
          category: 'onboarding',
          data: {'likedFoodCategoryIds': _selectedCategoryIds});
    } else {
      addBreadcrumb(
          message: 'User skipped favorite food category selection during onboarding',
          category: 'onboarding');
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacementNamed('/onboarding_paywall');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Ensure button stretches
          children: [
            // Top section with Title and Skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 20.0, 12.0, 10.0), // Adjusted padding
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: kToolbarHeight * 0.2), // Approximate space for icon button alignment
                        Text(
                          "What Foods Do You Love?",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Select up to $_maxCategorySelections. This helps us personalize your recipe feed!",
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.75)
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Skip Button (X icon)
                  IconButton(
                    icon: Icon(Icons.close, color: theme.textTheme.bodySmall?.color),
                    tooltip: 'Skip this step',
                    onPressed: () {
                      // Clear any selections if user explicitly skips
                      setState(() {
                        _selectedCategoryIds.clear();
                      });
                      _handleSkipOrContinue();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height:10), // Spacing after header text

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // You can adjust this based on screen size if needed
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                  childAspectRatio: 1.0, // Adjust if your CategoryCard has a different natural aspect ratio
                ),
                itemCount: _allSelectableCategories.length,
                itemBuilder: (context, index) {
                  final category = _allSelectableCategories[index];
                  final bool isSelected = _selectedCategoryIds.contains(category.id);
                  return CategoryCard(
                    category: category,
                    isHighlighted: isSelected,
                    onTap: () => _toggleCategorySelection(category.id),
                    // recipeCount: null, // Recipe count not relevant here
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 20.0), // Adjusted padding
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                // Button is enabled if at least one selection is made, otherwise its action is to skip
                onPressed: _handleSkipOrContinue, // Now always calls this
                child: Text(_selectedCategoryIds.isNotEmpty ? 'Next' : 'Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}