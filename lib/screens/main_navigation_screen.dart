// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import '../widgets/common/bottom_navigation.dart'; // Assuming this widget exists
import 'home_screen.dart';
// import 'chat/chat_screen.dart'; // No longer directly needed here
import 'chat/chat_list_screen.dart'; // <-- Import ChatListScreen instead
import 'recipes/recipe_list_screen.dart'; // Assuming this exists
import 'profile/profile_screen.dart'; // Assuming this exists

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  // Ignore this specific private type warning for createState, it's standard practice
  // ignore: library_private_types_in_public_api
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  // Make screens late final if they don't change after initState
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Initialize the list of screens for the BottomNavigationBar
    _screens = [
      const HomeScreen(),
      const ChatListScreen(), // <-- Use ChatListScreen for the second tab
      const RecipeListScreen(), // Placeholder for recipe list view
      const ProfileScreen(), // Placeholder for profile view
    ];
  }

  // Callback for when a bottom navigation item is tapped
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Building MainNavigationScreen, index: $_currentIndex");
    return Scaffold(
      // Use IndexedStack to keep the state of each screen when switching tabs
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Your custom bottom navigation bar widget
      bottomNavigationBar: BottomNavigation( // Ensure this widget exists and works
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        // Pass necessary items/labels to your BottomNavigation widget
      ),
    );
  }
}


// --- Placeholder Widgets (Ensure you have real implementations) ---
// You need implementations for these if they don't exist

// class RecipeListScreen extends StatelessWidget {
//   const RecipeListScreen({Key? key}) : super(key: key);
//   @override
//   Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Recipe List')));
// }

// class ProfileScreen extends StatelessWidget {
//   const ProfileScreen({Key? key}) : super(key: key);
//   @override
//   Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Profile')));
// }

// Ensure your custom BottomNavigation widget exists and is correctly imported, e.g.:
// import '../widgets/common/bottom_navigation.dart';
// class BottomNavigation extends StatelessWidget {
//   final int currentIndex;
//   final ValueChanged<int> onTap;
//   const BottomNavigation({Key? key, required this.currentIndex, required this.onTap}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return BottomNavigationBar(
//       currentIndex: currentIndex,
//       onTap: onTap,
//       items: const [
//         BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
//         BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
//         BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Recipes'),
//         BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
//       ],
//       // Add styling like selectedItemColor, unselectedItemColor, type etc.
//       type: BottomNavigationBarItemType.fixed, // Example styling
//     );
//   }
// }