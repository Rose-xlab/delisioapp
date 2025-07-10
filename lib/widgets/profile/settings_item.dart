// lib/widgets/profile/settings_item.dart
import 'package:flutter/material.dart';
import 'package:kitchenassistant/theme/app_colors_extension.dart';


class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // Getting colors from the theme for consistency.
    final theme = Theme.of(context);
    // final finalIconColor = iconColor ?? theme.primaryColor;
    // final finalTextColor = textColor ?? theme.primaryColor;

    final colorSchema = theme.colorScheme;
    final appColors = Theme.of(context).extension<AppColorsExtension>()!;

    return InkWell(
      onTap: onTap,
      // The InkWell provides the tap feedback effect.
      borderRadius: BorderRadius.circular(8.0), // Match the container's border radius
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        decoration: BoxDecoration(
          // Using the theme's hint color for the light pinkish background.
          color:Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          // Adding a subtle border as seen in the image.
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            // Leading Icon
            Icon(
              icon,
              color:colorSchema.primary,
              size: 24,
            ),
            const SizedBox(width: 16),

            // Title (takes up all available space)
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color:appColors.gray500,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Trailing Widget (defaults to a chevron icon)
            trailing ?? Icon(
              Icons.chevron_right,
              size: 24,
              color: appColors.gray500,
            ),
          ],
        ),
      ),
    );
  }
}