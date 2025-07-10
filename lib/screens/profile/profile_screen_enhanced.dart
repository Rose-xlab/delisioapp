// lib/screens/profile/profile_screen_enhanced.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart'; // Not used in this file currently

// Relative imports
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/user.dart'; // User model
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
    // FIX: Call _loadUserData after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure widget is still in the tree
        _loadUserData();
      }
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return; // Guard against calling setState on unmounted widget
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.token != null) {
        // Refresh user profile data which includes preferences via AuthProvider's internal service
        await authProvider.getCurrentUserProfile();

        final recipeProvider =
            Provider.of<RecipeProvider>(context, listen: false);
        await recipeProvider.getUserRecipes(authProvider.token!);
        await recipeProvider.getFavoriteRecipes(authProvider.token!);

        // Load/refresh subscription status (from backend, which might have been updated by RC sync)
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(authProvider.token!);
      } else {
        // This case should ideally be handled by the main auth check in the build method.
        // If reached here, it might indicate an inconsistent state.
        print(
            'ProfileScreenEnhanced: _loadUserData called but user not authenticated or token missing.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Session expired. Please log in again.')),
          );
          // Consider navigating to login or relying on AuthProvider listener for this
          // await _signOut(); // This might be too aggressive here
        }
      }
    } catch (e) {
      print('Error loading user data in ProfileScreenEnhanced: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error loading profile data: ${e.toString().split(':').last.trim()}')),
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Use listen: false because we are in a method, not reacting to changes in build.
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      // AuthProvider's onAuthStateChange listener should handle global state update.
      // Navigation to login screen is appropriate here.
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
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
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete Account?'),
            content: const Text(
                'This will permanently delete your account and all your data. This action cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('CANCEL')),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('DELETE'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      print('Account deletion requested by user.');
      // TODO: Implement actual account deletion logic via AuthProvider/AuthService
      // Example:
      // setState(() { _isLoading = true; });
      // try {
      //   bool success = await Provider.of<AuthProvider>(context, listen: false).deleteUserAccount();
      //   if (success && mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account successfully deleted.')));
      //     Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      //   } else if(mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion failed. Please try again.')));
      //   }
      // } catch (e) {
      //   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      // } finally {
      //   if (mounted) setState(() { _isLoading = false; });
      // }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Account deletion feature not yet implemented.')),
      );
    }
  }

  Widget _buildPreferencesSection(BuildContext context, User user) {
    final theme = Theme.of(context); // Get theme for colors

    if (user.preferences == null) {
      return Card(
        /* ... "No preferences set yet." card from your code ... */
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          side: BorderSide(
                      color: Colors.grey[200] ?? Colors.grey,
                      width:2.0
                    ),
          borderRadius: BorderRadius.circular(12)
          ),
        elevation: 0.0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cooking Preferences',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                  'No preferences set yet. Personalize your experience!'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Set Your Preferences'),
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/preferences'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                    )),
              ),
            ],
          ),
        ),
      );
    }

    final preferences = user.preferences!;

    IconData getDietaryIcon(String restriction) {
      /* ... your existing helper ... */
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

    Color getAllergenColor(String allergen) {
      /* ... your existing helper ... */
      switch (allergen.toLowerCase()) {
        case 'nuts':
        case 'peanuts':
          return Colors.brown;
        case 'shellfish':
        case 'fish':
          return Colors.blueAccent;
        case 'dairy':
        case 'milk':
          return Colors.lightBlue.shade200;
        case 'eggs':
          return Colors.amber.shade700;
        case 'soy':
          return Colors.green.shade600;
        case 'wheat':
          return Colors.orange.shade600;
        default:
          return Colors.red.shade700;
      }
    }

    return Card(
      /* ... Card styling ... */
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(
                      color: Colors.grey[200] ?? Colors.grey,
                      width:2.0
                    ),
        borderRadius: BorderRadius.circular(12)
        ),
        elevation: 0.0,
        color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cooking Preferencesc',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SkillLevelIndicator(
                level: preferences
                    .cookingSkill), // Assumes cookingSkill is never null here
            const SizedBox(height: 20),
            if (preferences.dietaryRestrictions.isNotEmpty) ...[
              const Text('Dietary Restrictions',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: preferences.dietaryRestrictions
                      .map((r) =>
                          PreferenceTag(label: r, icon: getDietaryIcon(r)))
                      .toList()),
              const SizedBox(height: 16),
            ],
            if (preferences.allergies.isNotEmpty) ...[
              const Text('Allergies',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: preferences.allergies.map((a) {
                    final color = getAllergenColor(a);
                    return PreferenceTag(
                        label: a,
                        backgroundColor: color.withOpacity(0.2),
                        textColor: color,
                        icon: Icons.warning_amber_rounded);
                  }).toList()),
              const SizedBox(height: 16),
            ],
            if (preferences.favoriteCuisines.isNotEmpty) ...[
              const Text('Favorite Cuisines',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: preferences.favoriteCuisines
                      .map((c) => PreferenceTag(
                          label: c,
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          textColor: Colors.blue.shade700,
                          icon: Icons.public))
                      .toList()),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Preferences'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/preferences')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final recipeProvider = Provider.of<RecipeProvider>(
        context); // Keep listen:true if stats update UI
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final user = authProvider.user;

    if (_isLoading && user == null) {
      // Show loading only if user data isn't available yet and we are loading
      return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: const Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isAuthenticated || user == null) {
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
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed('/login'),
                            child: const Text('Login / Sign Up'))
                      ]))));
    }

    final savedRecipesCount = recipeProvider.userRecipes.length;
    final favoritesCount = recipeProvider.favoriteRecipes.length;
    final joinDate = user.createdAt; // User is not null here
    final formattedJoinDate = DateFormat.yMMMd().format(joinDate);

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Your Profilex'),
      //   actions: [ IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh profile', onPressed: _isLoading ? null : _loadUserData)],
      // ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 250,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      child: Image.asset(
                        "assets/profile_bg.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        left: 0,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4)),
                        )),
                    Positioned(
                      top: 50,
                      bottom: 0,
                      right: 0,
                      left: 0,
                      child: Column(children: [
                        CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary))),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                              Text(
                                user.name.isNotEmpty
                                    ? user.name
                                    : 'Valued User',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                                                         
                              if (user.email.isNotEmpty)
                                Text(user.email,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        height: 1.0,
                                            ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            
                              Text('Member since $formattedJoinDate',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color:Colors.white,
                                      height: 1.0,
                                      
                                      ))
                            ]))
                      ]),
                    ),

                    Positioned(
                      
                      bottom: -100,
                      right: 0,
                      left: 0,
                      child:Card(
                /* User Stats */
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: Colors.grey[200] ?? Colors.grey,
                      width:2.0
                    ),
                    borderRadius: BorderRadius.circular(12)
                    ),
                elevation: 0.0,
                color: Colors.white,
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height:8),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                    child: StatItem(
                                        value: savedRecipesCount.toString(),
                                        label: 'Recipes',
                                        icon: Icons.menu_book,
                                        color: theme.colorScheme.primary)),
                                Expanded(
                                    child: StatItem(
                                        value: favoritesCount.toString(),
                                        label: 'Favorites',
                                        icon: Icons.favorite,
                                        color: Colors.redAccent)),
                                Expanded(
                                    child: StatItem(
                                        value:
                                            DateFormat('MMM').format(joinDate),
                                        label: 'Joined',
                                        icon: Icons.calendar_today,
                                        color: Colors.blueAccent))
                              ])
                        ])),
              ),
                      )
                  ],
                ),
              ),

              SizedBox(height: 100,),
              
              _buildPreferencesSection(context, user),
              Card(
                  /* Account Settings */
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      side: BorderSide(
                      color: Colors.grey[200] ?? Colors.grey,
                      width:2.0
                    ),
                      borderRadius: BorderRadius.circular(12)),
                   elevation: 0.0,
                   color: Colors.white,
                   
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text('Account Settings',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold))),
                          SettingsItem(
                              icon: Icons.card_membership,
                              title: 'Subscription Plans',
                              onTap: () => Navigator.of(context)
                                  .pushNamed('/subscription')),
                          SizedBox(height: 4,),
                          SettingsItem(
                              icon: Icons.lock_outline,
                              title: 'Change Password',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Change password screen not implemented')));
                              }),
                          SizedBox(height: 4,),
                          SettingsItem(
                              icon: Icons.edit_outlined,
                              title: 'Edit Cooking Preferences',
                              onTap: () => Navigator.of(context)
                                  .pushNamed('/preferences')),
                          SizedBox(height: 4,),
                          SettingsItem(
                              icon: Icons.delete_outline,
                              title: 'Delete Account',
                              textColor: Colors.red,
                              iconColor: Colors.red,
                              onTap: _showDeleteAccountDialog),
                          const Divider(indent: 16, endIndent: 16),
                          SettingsItem(
                              icon: Icons.exit_to_app,
                              title: 'Sign Out',
                              onTap: _signOut)
                        ]),
                  )),
              Card(
                  /* App Settings */
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      side: BorderSide(
                      color: Colors.grey[200] ?? Colors.grey,
                      width:2.0
                    ),
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0.0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text('App Settings',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold))),
                          // SwitchListTile(
                          //     title: const Text('Dark Mode'),
                          //     secondary: Icon(themeProvider.isDarkMode
                          //         ? Icons.dark_mode
                          //         : Icons.light_mode),
                          //     value: themeProvider.isDarkMode,
                          //     onChanged: (value) {
                          //       Provider.of<ThemeProvider>(context, listen: false)
                          //           .setDarkMode(value);
                          //     },
                          //     activeColor: theme.colorScheme.primary),
                              SizedBox(height: 4,),
                          SettingsItem(
                              icon: Icons.notifications_outlined,
                              title: 'Notification Preferences',
                              onTap: () => Navigator.of(context)
                                  .pushNamed('/notifications'))
                        ]),
                  )),
              Card(
                  /* Help & Support */
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      side: BorderSide(
                      color: Colors.grey[200] ?? Colors.grey,
                      width:2.0
                    ),
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0.0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text('Help & Support',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold))),
                                     
                          SettingsItem(
                              icon: Icons.help_outline,
                              title: 'FAQ',
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/faq')),
                                  SizedBox(height: 4,),
                          SettingsItem(
                              icon: Icons.support_agent,
                              title: 'Contact Support',
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/contact')),
                          SizedBox(height: 4,),
                          SettingsItem(
                              icon: Icons.info_outline,
                              title: 'About Kitchen Assistant',
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/about'))
                        ]),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
