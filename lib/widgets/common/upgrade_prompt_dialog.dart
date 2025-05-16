// lib/widgets/common/upgrade_prompt_dialog.dart
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // For RevenueCat Paywall

class UpgradePromptDialog extends StatelessWidget {
  const UpgradePromptDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      title: Row(
        children: [
          Icon(Icons.rocket_launch_outlined, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Text('Upgrade to Pro!', style: theme.textTheme.headlineSmall),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              "You've used your free recipe generation for this month.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Pro to enjoy:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildFeatureRow(Icons.check_circle_outline, 'Unlimited recipe generations'),
            const SizedBox(height: 4),
            _buildFeatureRow(Icons.check_circle_outline, 'HD image quality'),
            const SizedBox(height: 4),
            _buildFeatureRow(Icons.check_circle_outline, 'Full access to recipe library'),
            const SizedBox(height: 4),
            _buildFeatureRow(Icons.check_circle_outline, 'Priority chat assistance'),
            const SizedBox(height: 4),
            _buildFeatureRow(Icons.check_circle_outline, 'All features unlocked'),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      actions: <Widget>[
        TextButton(
          child: Text('Maybe Later', style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7))),
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          child: const Text('Upgrade to Pro'),
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog first
            // Present the RevenueCat paywall.
            // Ensure your "TestPro" offering is correctly configured in RevenueCat.
            // This is the identifier for your offering in RevenueCat.
            RevenueCatUI.presentPaywallIfNeeded("TestPro");
          },
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}