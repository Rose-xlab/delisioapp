// screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Please log in to view your profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await authProvider.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile avatar and name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Preferences section
            const Text(
              'Your Preferences',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (userProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (user.preferences != null) ...[
              // Dietary restrictions
              _buildPreferenceSection(
                context,
                'Dietary Restrictions',
                user.preferences!.dietaryRestrictions,
                Icons.restaurant,
              ),
              const SizedBox(height: 16),

              // Favorite cuisines
              _buildPreferenceSection(
                context,
                'Favorite Cuisines',
                user.preferences!.favoriteCuisines,
                Icons.public,
              ),
              const SizedBox(height: 16),

              // Allergies
              _buildPreferenceSection(
                context,
                'Allergies',
                user.preferences!.allergies,
                Icons.warning,
              ),
              const SizedBox(height: 16),

              // Cooking skill
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Cooking Skill'),
                subtitle: Text(
                  _capitalizeFirst(user.preferences!.cookingSkill),
                ),
              ),
            ] else
              const Text(
                'No preferences set. Update your preferences to get personalized recipes.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/preferences');
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Preferences'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceSection(
      BuildContext context,
      String title,
      List<String> items,
      IconData icon,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
        ),
        const SizedBox(height: 4),
        items.isEmpty
            ? const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Text(
            'None specified',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        )
            : Wrap(
          spacing: 8,
          children: items.map((item) {
            return Chip(
              label: Text(_capitalizeFirst(item)),
              backgroundColor: Colors.grey[200],
            );
          }).toList(),
        ),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}