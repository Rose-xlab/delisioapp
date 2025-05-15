// widgets/common/bottom_navigation.dart
import 'package:flutter/material.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex; // Index of the currently active screen
  final Function(int) onTap; // Callback for tapping on a navigation item (Home, Chat, Recipes, Profile)
  final VoidCallback onFabPressed; // Callback for tapping the central "+" button

  const BottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.onFabPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get theme data for consistent styling
    final theme = Theme.of(context);
    final bottomNavTheme = theme.bottomNavigationBarTheme;
    final primaryColor = theme.primaryColor;
    final unselectedColor = bottomNavTheme.unselectedItemColor ?? Colors.grey.shade600;
    final selectedLabelStyle = bottomNavTheme.selectedLabelStyle ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    final unselectedLabelStyle = bottomNavTheme.unselectedLabelStyle ?? const TextStyle(fontSize: 12);


    // Define the navigation items with their icons and labels
    // The screenIndex corresponds to the index in MainNavigationScreen's _screens list
    final List<_BottomNavItemData> navItemsData = [
      _BottomNavItemData(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', screenIndex: 0),
      _BottomNavItemData(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chats', screenIndex: 1),
      // Placeholder for the FAB, will be handled separately in the Row
      _BottomNavItemData(icon: Icons.list_alt_outlined, activeIcon: Icons.book_outlined, label: 'Recipes', screenIndex: 2), // Changed activeIcon to book_outlined to match original if desired, or keep list_alt
      _BottomNavItemData(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', screenIndex: 3),
    ];

    return Container(
      // Set the height of the navigation bar, including padding for the safe area (notch, etc.)
      height: kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom + 8, // Added a bit more height for labels
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom, left: 8, right: 8, top: 4), // Add padding
      decoration: BoxDecoration(
        // Use the theme's bottom app bar color or canvas color as background
        color: bottomNavTheme.backgroundColor ?? theme.canvasColor,
        // Optional: Add a subtle shadow for depth
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, -2), // Shadow on the top edge
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute items evenly
        crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
        children: <Widget>[
          // First two navigation items
          _buildNavItem(context, navItemsData[0], currentIndex == navItemsData[0].screenIndex, primaryColor, unselectedColor, selectedLabelStyle, unselectedLabelStyle),
          _buildNavItem(context, navItemsData[1], currentIndex == navItemsData[1].screenIndex, primaryColor, unselectedColor, selectedLabelStyle, unselectedLabelStyle),

          // The central "+" button
          _buildFabItem(context, primaryColor),

          // Last two navigation items
          _buildNavItem(context, navItemsData[2], currentIndex == navItemsData[2].screenIndex, primaryColor, unselectedColor, selectedLabelStyle, unselectedLabelStyle),
          _buildNavItem(context, navItemsData[3], currentIndex == navItemsData[3].screenIndex, primaryColor, unselectedColor, selectedLabelStyle, unselectedLabelStyle),
        ],
      ),
    );
  }

  // Helper widget to build each standard navigation item
  Widget _buildNavItem(
      BuildContext context,
      _BottomNavItemData itemData,
      bool isActive,
      Color activeColor,
      Color inactiveColor,
      TextStyle activeLabelStyle,
      TextStyle inactiveLabelStyle,
      ) {
    final Color color = isActive ? activeColor : inactiveColor;
    final IconData icon = isActive ? itemData.activeIcon : itemData.icon;
    final TextStyle labelStyle = isActive ? activeLabelStyle.copyWith(color: color) : inactiveLabelStyle.copyWith(color: color);

    return Expanded( // Ensures each item takes up equal width
      child: InkWell(
        onTap: () => onTap(itemData.screenIndex), // Call onTap with the screen's index
        borderRadius: BorderRadius.circular(24), // Circular feedback for tap
        splashColor: activeColor.withOpacity(0.1),
        highlightColor: activeColor.withOpacity(0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Use minimum space vertically
          children: <Widget>[
            Icon(icon, color: color, size: 24), // Icon size reduced slightly to accommodate label
            SizedBox(height: 3), // Space between icon and label
            Text( // Label text is now displayed
              itemData.label,
              style: labelStyle,
              overflow: TextOverflow.ellipsis, // Handle long labels
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the central "+" button
  Widget _buildFabItem(BuildContext context, Color iconColor) {
    return Expanded( // Ensures the FAB item also participates in space distribution
      child: InkWell(
          onTap: onFabPressed, // Call the dedicated FAB press callback
          customBorder: const CircleBorder(), // Circular tap feedback
          splashColor: iconColor.withOpacity(0.15),
          highlightColor: iconColor.withOpacity(0.1),
          child: Column( // Using Column to center
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline, // Instagram-like plus icon
                color: iconColor, // Use primary color or a distinct color
                size: 28, // Size of the "+" icon
              ),
              // No label for the central FAB button to keep it clean
            ],
          )
      ),
    );
  }
}

// Helper class to hold data for each navigation item
class _BottomNavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int screenIndex;

  _BottomNavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screenIndex,
  });
}
