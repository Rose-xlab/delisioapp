// lib/widgets/recipes/generation_limit_dialog.dart
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // For RevenueCat Paywall

// Assuming relative path from lib/widgets/recipes/
import '../../models/subscription.dart'; // Ensure this path is correct and SubscriptionTier is defined here
import '../../constants/myofferings.dart'; // Ensure this path is correct for MyOfferings.pro.identifier

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
    VoidCallback? primaryAction;
    IconData iconData = Icons.restaurant_menu; // Default icon
    Color iconColor = Colors.orangeAccent;   // Default icon color

    switch (currentTier) {
      case SubscriptionTier.free:
        message =
        'You\'ve used all your free recipe generations for this month. Upgrade to Pro for unlimited recipes and more features!';
        actionText = 'Upgrade to Pro';
        iconData = Icons.restaurant_menu;
        iconColor = Colors.orangeAccent;
        primaryAction = () {
          Navigator.of(context).pop(); // Close the dialog
          // Present RevenueCat paywall
          RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro.identifier)
              .then((value) {
            // Optionally handle PaywallResult here if needed, e.g., refresh subscription status
            // For now, just presenting it.
          }).catchError((error) {
            // Handle error from presentPaywallIfNeeded if necessary
            debugPrint("Error presenting paywall from GenerationLimitDialog (Free): $error");
            // Fallback to navigating to subscription screen if paywall fails to present
            Navigator.of(context).pushNamed('/subscription');
          });
        };
        break;
      case SubscriptionTier.basic: // <<< ADDED THIS CASE
        message =
        'You\'ve used all your recipe generations for your Basic plan this month. Upgrade to Pro for unlimited recipes and more features!';
        actionText = 'Upgrade to Pro';
        iconData = Icons.upgrade_outlined; // Slightly different icon for basic
        iconColor = Colors.blueAccent;
        primaryAction = () {
          Navigator.of(context).pop(); // Close the dialog
          RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro.identifier)
              .then((value) {
            // Handle PaywallResult if needed
          }).catchError((error) {
            debugPrint("Error presenting paywall from GenerationLimitDialog (Basic): $error");
            Navigator.of(context).pushNamed('/subscription');
          });
        };
        break;
      case SubscriptionTier.pro:
      // This case implies Pro users *can* hit a limit, which might be an edge case
      // or if "unlimited" isn't truly infinite but a very high number that was reached.
        message =
        'You seem to have reached a generation limit. Pro plans offer extensive usage. If you believe this is an error, please contact support.';
        actionText = 'Contact Support';
        iconData = Icons.error_outline;
        iconColor = Colors.redAccent;
        primaryAction = () {
          Navigator.of(context).pop();
          // TODO: Implement navigation or action for contacting support
          // Example: Navigator.of(context).pushNamed('/contact-support');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Navigate to support (to be implemented)')),
          );
        };
        break;
    // It's good practice to have a default case for enums,
    // even if you think all cases are covered, especially if the enum might expand.
    // However, since SubscriptionTier has a fixed number of values,
    // covering all of them makes the switch exhaustive.
    // If you prefer a default:
    // default:
    //   message = 'You have reached your generation limit. Please check your plan details.';
    //   actionText = 'View Plans';
    //   primaryAction = () {
    //     Navigator.of(context).pop();
    //     Navigator.of(context).pushNamed('/subscription');
    //   };
    //   break;
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
            iconData,
            size: 56, // Slightly smaller icon for a cleaner look
            color: iconColor,
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
      actionsPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), // Adjusted padding
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // "Close" is always an option
          child: Text('CLOSE', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))),
        ),
        if (primaryAction != null) // Only show primary action button if one is defined
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            onPressed: primaryAction,
            child: Text(actionText.toUpperCase()),
          ),
      ],
    );
  }
}