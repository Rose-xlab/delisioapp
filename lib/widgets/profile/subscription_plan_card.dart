import 'package:flutter/material.dart';
import '../../models/subscription.dart';

class SubscriptionPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrentPlan;
  final ValueChanged<SubscriptionPlan>? onSubscribe;
  final String buttonText;

  const SubscriptionPlanCard({
    Key? key,
    required this.plan,
    required this.isCurrentPlan,
    this.onSubscribe,
    this.buttonText = 'Subscribe',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Colors based on the UI
    const Color headerColor = Color(0xFFFF7F2D); // Orange
    const Color priceCircleColor = Colors.white;
    const Color priceTextColor = Color(0xFFFF7F2D);
    const Color checkColor = Color(0xFF22C55E); // Green
    const Color crossColor = Color(0xFFEF4444); // Red
    const Color borderColor = Color(0xFFF87171); // Light red

    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor.withOpacity(0.15)),
        ),
        elevation: 0,
        color: const Color(0xFFFFF6F6), // Very light pink
        clipBehavior: Clip.none, // Allow overflow for price circle
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with orange background
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none, // Allow overflow for price circle
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 24, bottom: 48), // Increase bottom padding for circle
                  decoration: const BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        plan.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock All Pro Features for a ${plan.name == 'Pro Weekly' ? 'week' : plan.name == 'Pro Monthly' ? 'month' : plan.name == 'Pro Annual' ? 'year' : plan.name.toLowerCase()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Price circle
                Positioned(
                  bottom: -24,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      plan.price.toString(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: priceTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40), // Space for the price circle overlap

            // Feature list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: List.generate(plan.features.length, (index) {
                  final feature = plan.features[index];
                  // Example: You can customize which features are "not included"
                  final isAvailable = !feature.contains('not'); // Adjust logic as needed
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle : Icons.cancel,
                          color: isAvailable ? checkColor : crossColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // Subscribe button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: borderColor,
                    side: BorderSide(color: borderColor, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: isCurrentPlan
                      ? null
                      : onSubscribe != null
                          ? () => onSubscribe!(plan)
                          : null,
                  child: Text(
                    isCurrentPlan ? 'Current Plan' : buttonText,
                    style: TextStyle(
                      color: borderColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
