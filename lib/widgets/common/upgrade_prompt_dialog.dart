// lib/widgets/common/upgrade_prompt_dialog.dart
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // For RevenueCat Paywall
import 'package:kitchenassistant/constants/myofferings.dart'; // Import MyOfferings

class UpgradePromptDialog extends StatelessWidget {
  final String titleText;
  final String messageText;
  final List<String> proFeatures;

  const UpgradePromptDialog({
    Key? key,
    this.titleText = 'Upgrade to Pro!',
    required this.messageText,
    this.proFeatures = const [ // Default features, can be overridden
      'Unlimited recipe generations',
      'Unlimited AI chat replies', // Added this feature
      'HD image quality',
      'Full access to recipe library',
      'Priority chat assistance',
      'All features unlocked',
    ],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      title: Row(
        children: [
          Icon(Icons.rocket_launch_outlined, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Text(titleText, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              messageText, // Use the passed message
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Upgrade to Pro to enjoy:',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...proFeatures.map((feature) => _buildFeatureRow(Icons.check_circle_outline, feature, theme)).toList(),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        TextButton(
          child: Text('Maybe Later', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.workspace_premium_outlined, size: 18),
          label: const Text('View Pro Plans'),
          style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
          ),
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog first
            // Present the RevenueCat paywall using the offering identifier from MyOfferings
            RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro);
          },
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}