// lib/widgets/profile/subscription_plan_card.dart
import 'package:flutter/material.dart';
import '../../models/subscription.dart';

class SubscriptionPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrentPlan;
  final VoidCallback? onSubscribe;

  const SubscriptionPlanCard({
    Key? key,
    required this.plan,
    required this.isCurrentPlan,
    this.onSubscribe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Set colors based on plan tier
    Color planColor;
    switch (plan.tier) {
      case SubscriptionTier.premium:
        planColor = Colors.purple;
        break;
      case SubscriptionTier.basic:
        planColor = Colors.blue;
        break;
      default:
        planColor = Colors.green;
    }

    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isCurrentPlan
              ? BorderSide(color: planColor, width: 2)
              : BorderSide.none,
        ),
        elevation: isCurrentPlan ? 3 : 1,
        child: Padding(
        padding: const EdgeInsets.all(16.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: planColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: planColor),
          ),
          child: Text(
            plan.name,
            style: TextStyle(
              color: planColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        Text(
          plan.price == 0
              ? 'Free'
              : '\$${plan.price}/${plan.interval}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
      const SizedBox(height: 8),
      Text(
        plan.description,
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 8),
      // Features list
      ...plan.features.map((feature) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: planColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(feature),
            ),
          ],
        ),
      )),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: isCurrentPlan
            ? ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
          ),
          child: const Text('Current Plan'),
        )
            : ElevatedButton(
          onPressed: onSubscribe,
          style: ElevatedButton.styleFrom(
            backgroundColor: planColor,
          ),
          child: Text(
            plan.price == 0
                ? 'Use Free Plan'
                : 'Subscribe',
          ),
        ),
      ),
    ],
    ),
        ),
    );
  }
}