// lib/widgets/recipes/generation_limit_dialog.dart
import 'package:flutter/material.dart';
import '../../models/subscription.dart';

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

    switch (currentTier) {
      case SubscriptionTier.free:
        message = 'You\'ve used all your free recipe generations for this month. Upgrade to a paid plan for more recipes!';
        actionText = 'See Plans';
        break;
      case SubscriptionTier.basic:
        message = 'You\'ve used all 5 recipe generations for this month on your Basic plan. Upgrade to Premium for unlimited recipes!';
        actionText = 'Upgrade to Premium';
        break;
      case SubscriptionTier.premium:
      // This shouldn't happen with unlimited recipes, but just in case
        message = 'Something went wrong with your subscription. Please contact support.';
        actionText = 'Contact Support';
        break;
    }

    return AlertDialog(
      title: const Text('Recipe Generation Limit Reached'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.restaurant_menu,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushNamed('/subscription');
          },
          child: Text(actionText),
        ),
      ],
    );
  }
}