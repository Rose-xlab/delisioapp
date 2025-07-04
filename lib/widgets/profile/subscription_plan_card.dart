// lib/widgets/profile/subscription_plan_card.dart
import 'package:flutter/material.dart';
import '../../models/subscription.dart';

class SubscriptionPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrentPlan;
  final ValueChanged<SubscriptionPlan>? onSubscribe;
  final String buttonText; // <-- Add this

  const SubscriptionPlanCard({
    Key? key,
    required this.plan,
    required this.isCurrentPlan,
    this.onSubscribe,
    this.buttonText = 'Subscribe', // <-- Default value
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color planColor;
    switch (plan.tier) {
      case SubscriptionTier.pro:
        planColor = Colors.deepPurple;
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
                      : '\$${plan.price.toStringAsFixed(2)}/${plan.interval}',
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
                  : plan.price == 0
                      ? const SizedBox.shrink()
                      : ElevatedButton(
                          onPressed: onSubscribe != null ? () => onSubscribe!(plan) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: planColor,
                          ),
                          child: Text(buttonText), // <-- Use custom text
                        ),
            ),
          ],
        ),
      ),
    );
  }
}