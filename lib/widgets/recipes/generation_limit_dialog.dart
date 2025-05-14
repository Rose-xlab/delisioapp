// lib/widgets/recipes/generation_limit_dialog.dart
import 'package:flutter/material.dart';
import '../../models/subscription.dart'; // Ensure this path is correct

class GenerationLimitDialog extends StatelessWidget {
  final SubscriptionTier currentTier;

  const GenerationLimitDialog({
    Key? key,
    required this.currentTier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String message;
    String actionText;
    VoidCallback? primaryAction; // To allow for different actions if needed

    switch (currentTier) {
      case SubscriptionTier.free:
        message =
        'You\'ve used all your free recipe generations for this month. Upgrade to Pro for unlimited recipes and more features!';
        actionText = 'Upgrade to Pro';
        primaryAction = () {
          Navigator.of(context).pop(); // Close the dialog
          Navigator.of(context)
              .pushNamed('/subscription'); // Navigate to subscription screen
        };
        break;
      case SubscriptionTier.pro:
      // This case should ideally not be reached if Pro has unlimited generations.
      // It indicates a potential discrepancy or an unexpected limitation.
        message =
        'You seem to have reached a generation limit on your Pro plan, which should offer unlimited generations. Please contact support to resolve this issue.';
        actionText = 'Contact Support';
        primaryAction = () {
          Navigator.of(context).pop(); // Close the dialog
          // TODO: Implement navigation or action for contacting support
          // For example, launch a support URL or navigate to a support screen:
          // Navigator.of(context).pushNamed('/support');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Navigate to support (not implemented yet)')),
          );
        };
        break;
    // Removed cases for SubscriptionTier.basic and SubscriptionTier.premium
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      title: const Text(
        'Recipe Limit Reached',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            // Using a different icon for Pro tier to differentiate if needed,
            // or keep it generic. For now, keeping it generic.
            currentTier == SubscriptionTier.pro ? Icons.error_outline : Icons.restaurant_menu,
            size: 64,
            color: currentTier == SubscriptionTier.pro ? Colors.redAccent : Colors.orangeAccent,
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor, // Use theme color
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: primaryAction,
          child: Text(actionText),
        ),
      ],
    );
  }
}
