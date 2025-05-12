// lib/screens/profile/profile_screen_enhanced.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart'; // Import for subscription provider
import '../../models/user.dart';
import '../../widgets/profile/settings_item.dart';
import '../../widgets/profile/preference_tag.dart';
import '../../widgets/profile/stat_item.dart';
import '../../widgets/profile/skill_level_indicator.dart';

class ProfileScreenEnhanced extends StatefulWidget {
  const ProfileScreenEnhanced({Key? key}) : super(key: key);

  @override
  State<ProfileScreenEnhanced> createState() => _ProfileScreenEnhancedState();
}

class _ProfileScreenEnhancedState extends State<ProfileScreenEnhanced> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        // Refresh user profile data and preferences
        await authProvider.getCurrentUserProfile();

        // Load recipes for stats
        final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
        // Ensure token is not null before using !
        if (authProvider.token != null) {
          await recipeProvider.getUserRecipes(authProvider.token!);
          await recipeProvider.getFavoriteRecipes(authProvider.token!);

          // Load subscription data
          await Provider.of<SubscriptionProvider>(context, listen: false)
              .loadSubscriptionStatus(authProvider.token!);
        } else {
          print('Authentication token is null.');
          // Handle the case where token is null, maybe sign out or show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Authentication error. Please log in again.')),
            );
            // Optionally sign out:
            // await _signOut();
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        // Show specific error message if possible
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    // Use listen: false for one-off actions in callbacks/futures
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Check mounted before async gap and state change
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await authProvider.signOut();
      if (mounted) {
        // Use pushNamedAndRemoveUntil for cleaner stack on logout
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      }
    } catch (e) {
      print('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    // Check mounted before showing dialog
    if (!mounted) return;

    // Use a different context for the builder
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
            'This will permanently delete your account and all your data. This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    ) ?? false; // Handle null case (dialog dismissed)

    // Check confirmed and mounted state after the dialog
    if (confirmed && mounted) {
      // Implement account deletion
      // TODO: Add account deletion logic (e.g., call provider method)
      print('Account deletion requested.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion not implemented yet')),
      );
      // Example:
      // setState(() { _isLoading = true; });
      // try {
      //   await Provider.of<AuthProvider>(context, listen: false).deleteAccount();
      //   if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      // } catch (e) {
      //    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
      // } finally {
      //    if (mounted) setState(() { _isLoading = false; });
      // }
    }
  }

  Widget _buildPreferencesSection(BuildContext context, User user) {
    // Check for null preferences early
    if (user.preferences == null) {
      // Return an empty container or a message indicating no preferences set
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cooking Preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('No preferences set yet.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Set Preferences'),
                  onPressed: () => Navigator.of(context).pushNamed('/preferences'),
                ),
              ),
            ],
          ),
        ),
      );
      // return const SizedBox.shrink(); // Alternatively, show nothing
    }

    // Preferences exist, safe to use !
    final preferences = user.preferences!;

    // Helper function to get icon for dietary restriction (keep inside build method or make private class member)
    IconData getDietaryIcon(String restriction) {
      switch (restriction.toLowerCase()) {
        case 'vegetarian':
          return Icons.eco;
        case 'vegan':
          return Icons.spa;
        case 'gluten-free':
          return Icons.grain;
        case 'dairy-free':
          return Icons.no_drinks;
        case 'keto':
          return Icons.fitness_center;
        case 'paleo':
          return Icons.deck;
        default:
          return Icons.restaurant_menu;
      }
    }

    // Helper function to get color for allergen (keep inside build method or make private class member)
    Color getAllergenColor(String allergen) {
      switch (allergen.toLowerCase()) {
        case 'nuts':
        case 'peanuts':
          return Colors.brown;
        case 'shellfish':
        case 'fish':
          return Colors.blue;
        case 'dairy':
        case 'milk': // Consider variations
          return Colors.lightBlue.shade100;
        case 'eggs':
          return Colors.amber;
        case 'soy':
          return Colors.green;
        case 'wheat':
          return Colors.orange.shade300;
        default:
          return Colors.red.shade400; // More distinct warning color
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cooking Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Skill Level
            // Ensure SkillLevelIndicator handles null/default values gracefully if needed
            SkillLevelIndicator(level: preferences.cookingSkill),
            const SizedBox(height: 20),

            // Dietary Restrictions
            if (preferences.dietaryRestrictions.isNotEmpty) ...[
              const Text(
                'Dietary Restrictions',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preferences.dietaryRestrictions.map((restriction) {
                  return PreferenceTag(
                    label: restriction,
                    icon: getDietaryIcon(restriction),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Allergies with warning colors
            if (preferences.allergies.isNotEmpty) ...[
              const Text(
                'Allergies',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preferences.allergies.map((allergen) {
                  final color = getAllergenColor(allergen);
                  return PreferenceTag(
                    label: allergen,
                    // FIX: Use withOpacity instead of withValues
                    backgroundColor: color.withOpacity(0.2),
                    textColor: color,
                    icon: Icons.warning_amber_rounded,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Favorite Cuisines
            if (preferences.favoriteCuisines.isNotEmpty) ...[
              const Text(
                'Favorite Cuisines',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preferences.favoriteCuisines.map((cuisine) {
                  return PreferenceTag(
                    label: cuisine,
                    // FIX: Use withOpacity instead of withValues
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    textColor: Colors.blue, // Consider a darker shade for better contrast
                    icon: Icons.public,
                  );
                }).toList(),
              ),
              // Add SizedBox if sections follow
              const SizedBox(height: 16),
            ],

            // Edit Preferences Button (always show if preferences section is built)
            // const SizedBox(height: 16), // This might create too much space if cuisines is empty
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit Preferences'),
                onPressed: () => Navigator.of(context).pushNamed('/preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth changes to rebuild UI accordingly
    final authProvider = Provider.of<AuthProvider>(context);
    // Only listen to recipe/theme providers if their data directly affects this build method
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: true); // Listen for stat changes
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true); // Listen for theme changes
    final theme = Theme.of(context);

    // User object from AuthProvider
    final user = authProvider.user;

    // --- Authentication Check ---
    if (!authProvider.isAuthenticated || user == null) { // Also check if user object is null
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            
            padding: const EdgeInsets.all(15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Please log in to view your profile'),
                const SizedBox(height: 16),
                ElevatedButton(
                  // Use pushReplacementNamed for login to replace the current screen
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                  child: const Text('Login / Sign Up'), // More inviting text
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- Loading State Check ---
    // Keep loading indicator if _isLoading is true OR if user is technically authenticated but user data hasn't loaded yet (user == null check above handles initial load)
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // --- Authenticated and Data Loaded ---
    // Calculate stats (now safe to assume user is not null)
    final savedRecipesCount = recipeProvider.userRecipes.length;
    final favoritesCount = recipeProvider.favoriteRecipes.length;
    // Use a default date only if createdAt is truly null, which is unlikely for a logged-in user
    final joinDate = user.createdAt ?? DateTime.now();
    // Use a standard, readable format
    final formattedJoinDate = DateFormat.yMMMd().format(joinDate); // e.g., Apr 20, 2025

    return Scaffold(
        appBar: AppBar(
        title: const Text('Your Profile'),
    actions: [
    IconButton(
    icon: const Icon(Icons.refresh),
    tooltip: 'Refresh profile',
    // Disable refresh button while loading
    onPressed: _isLoading ? null : _loadUserData,
    ),
    ],
    ),
    body: RefreshIndicator(
    onRefresh: _loadUserData,
    child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll physics allow refresh
    padding: const EdgeInsets.only(bottom: 32), // Bottom padding for scrollable content
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch cards to full width
    children: [
    // --- Profile header ---
    Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
    // Use theme colors for better adaptation
    color: theme.colorScheme.primary,
    boxShadow: [
    BoxShadow(
    // FIX: Use withOpacity instead of withValues
    color: Colors.black.withOpacity(0.1),
    blurRadius: 8,
    offset: const Offset(0, 3),
    ),
    ],
    // Optional: Add border radius to bottom
    // borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
    ),
    child: Row(
    children: [
    CircleAvatar(
    radius: 40,
    // FIX: Use withOpacity instead of withValues
    backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.9),
    child: Text(
    // Check for empty name
    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
    style: TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    // Color should contrast with avatar background
    color: theme.colorScheme.primary,
    ),
    ),
    ),
    const SizedBox(width: 20),
    Expanded( // Allow text to expand and wrap/truncate
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    user.name.isNotEmpty ? user.name : 'Valued User', // Fallback name
    style: theme.textTheme.headlineSmall?.copyWith( // Use theme text styles
    color: theme.colorScheme.onPrimary,
    fontWeight: FontWeight.bold
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    ),
    const SizedBox(height: 4),
    // Only display email if it's not empty
    if (user.email.isNotEmpty)
    Text(
    user.email,
    style: theme.textTheme.bodyLarge?.copyWith(
    // FIX: Use withOpacity instead of withValues
    color: theme.colorScheme.onPrimary.withOpacity(0.9),
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    ),
    const SizedBox(height: 8),
    Text(
    'Member since $formattedJoinDate',
    style: theme.textTheme.bodyMedium?.copyWith(
    // FIX: Use withOpacity instead of withValues
    color: theme.colorScheme.onPrimary.withOpacity(0.8),
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ),

    // --- User Stats ---
    Card(
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    elevation: 1.0, // Subtle elevation
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text( // Use themed text style
    'Your Stats',
    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 16),
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
    // Use Expanded for even spacing
    Expanded(
    child: StatItem(
    value: savedRecipesCount.toString(),
    label: 'Recipes',
    icon: Icons.menu_book, // More specific icon
    color: theme.colorScheme.primary,
    ),
    ),
    Expanded(
    child: StatItem(
    value: favoritesCount.toString(),
    label: 'Favorites',
    icon: Icons.favorite, // Keep filled favorite icon
    color: Colors.redAccent, // Slightly brighter red
    ),
    ),
    Expanded(
    child: StatItem(
    // Show month name for Join Date stat
    value: DateFormat('MMM').format(joinDate), // e.g., Apr
    label: 'Joined',
    icon: Icons.calendar_today,
    color: Colors.blueAccent, // Brighter blue
    ),
    ),
    ],
    ),
    ],
    ),
    ),
    ),

    // --- Cooking Preferences Section ---
    _buildPreferencesSection(context, user), // Build the section

    // --- Account Settings ---
    Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    elevation: 1.0,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Padding( // Consistent padding
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
    'Account Settings',
    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    ),
    ),
    // Add Subscription Settings Item
    SettingsItem(
    icon: Icons.card_membership,
    title: 'Subscription Plans',
    onTap: () => Navigator.of(context).pushNamed('/subscription'),
    ),
    SettingsItem(
    icon: Icons.lock_outline,
    title: 'Change Password',
    onTap: () {
    // TODO: Implement password change navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change password screen not implemented')),
    );
      // Example: Navigator.of(context).pushNamed('/change-password');
    },
    ),
      SettingsItem(
        icon: Icons.email_outlined,
        title: 'Update Email',
        onTap: () {
          // TODO: Implement email update navigation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update email screen not implemented')),
          );
          // Example: Navigator.of(context).pushNamed('/update-email');
        },
      ),
      // This item is slightly redundant if there's a dedicated preferences section/button
      // Keep it if it serves a distinct purpose or navigates differently
      SettingsItem(
        icon: Icons.edit_outlined,
        title: 'Edit Cooking Preferences',
        onTap: () => Navigator.of(context).pushNamed('/preferences'),
      ),
      SettingsItem(
        icon: Icons.delete_outline,
        title: 'Delete Account',
        textColor: Colors.red,
        iconColor: Colors.red, // Make icon red too
        onTap: _showDeleteAccountDialog,
      ),
      const Divider(indent: 16, endIndent: 16), // Visual separator
      SettingsItem(
        icon: Icons.exit_to_app,
        title: 'Sign Out',
        onTap: _signOut, // Use the sign out method
      ),
    ],
    ),
    ),

      // --- App Settings ---
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'App Settings',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: const Text('Dark Mode'),
              // Show appropriate icon based on state
              secondary: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                // Update theme via provider (use listen: false for actions)
                Provider.of<ThemeProvider>(context, listen: false).setDarkMode(value);
              },
              activeColor: theme.colorScheme.primary, // Use theme color for active switch
            ),
            SettingsItem(
              icon: Icons.notifications_outlined,
              title: 'Notification Preferences',
              onTap: () => Navigator.of(context).pushNamed('/notifications'),
            ),
          ],
        ),
      ),

      // --- Help & Support ---
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Help & Support',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SettingsItem(
              icon: Icons.help_outline,
              title: 'FAQ',
              onTap: () => Navigator.of(context).pushNamed('/faq'),
            ),
            SettingsItem(
              icon: Icons.support_agent,
              title: 'Contact Support',
              onTap: () => Navigator.of(context).pushNamed('/contact'),
            ),

            SettingsItem(
              icon: Icons.info_outline,
              title: 'About Kitchen Assistant', // App name
              onTap: () => Navigator.of(context).pushNamed('/about'),
            ),
          ],
        ),
      ),
    ],
    ),
    ),
    ),
    );
  }
}