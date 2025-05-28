// lib/widgets/common/upgrade_prompt_dialog.dart
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // For RevenueCat Paywall

// Corrected to relative import path
import '../../../constants/myofferings.dart'; // Assumes myofferings.dart is in lib/constants/

class UpgradePromptDialog extends StatelessWidget {
  final String titleText;
  final String messageText;
  final List<String> proFeatures;

  const UpgradePromptDialog({
    Key? key,
    this.titleText = 'Unlock Pro Features!',
    required this.messageText,
    this.proFeatures = const [
      'Unlimited recipe generations',
      'Unlimited AI chat replies',
      'Enhanced HD image quality',
      'Full access to recipe library',
      'Priority chat assistance',
      'All current & future features unlocked',
    ],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    final surfaceColor = theme.colorScheme.surface; // Dialog background
    final onSurfaceColor = theme.colorScheme.onSurface; // Main text on dialog
    final onSurfaceVariantColor = theme.colorScheme.onSurfaceVariant; // Secondary text, icons
    final successColor = Colors.green.shade600; // For checkmark icons

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      elevation: isDarkMode ? 4.0 : 8.0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.rocket_launch_outlined,
                  color: primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    titleText,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Icon(
                  Icons.close,
                  color: onSurfaceVariantColor.withOpacity(0.8),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(20.0, 16.0, 12.0, 12.0),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                messageText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  color: onSurfaceColor.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Upgrade to Pro to enjoy:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurfaceColor,
                ),
              ),
              const SizedBox(height: 12),
              ...proFeatures.map((feature) =>
                  _buildFeatureRow(Icons.check_circle, feature, theme, successColor))
                  .toList(),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.workspace_premium_outlined, size: 20),
              label: const Text('View Pro Plans'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: onPrimaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                elevation: 2.0,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close this dialog first
                // Corrected: Use the offering identifier string
                RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro.identifier);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  color: onSurfaceVariantColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, ThemeData theme, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}