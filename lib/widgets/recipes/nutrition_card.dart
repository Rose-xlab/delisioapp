import 'package:flutter/material.dart';
import '../../models/nutrition_info.dart';
import 'package:intl/intl.dart';

class NutritionCard extends StatelessWidget {
  final NutritionInfo nutrition;
  const NutritionCard({ Key? key, required this.nutrition }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final gramFmt = NumberFormat("0.#");
    final mgFmt   = NumberFormat("0");

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      color: cs.surfaceVariant, // a gentle backdrop
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Facts',
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Per serving',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Divider(color: cs.outline, thickness: 1),
            const SizedBox(height: 16),

            _row(context, 'Calories', nutrition.calories.toString(), 'kcal',  cs),
            _row(context, 'Protein', gramFmt.format(nutrition.protein), 'g',   cs),
            _row(context, 'Fat',     gramFmt.format(nutrition.fat),     'g',   cs),
            _row(context, 'Carbs',   gramFmt.format(nutrition.carbs),   'g',   cs),

            if (nutrition.saturatedFat != null)
              _row(context, 'Sat. Fat', gramFmt.format(nutrition.saturatedFat!), 'g', cs),
            if (nutrition.fiber != null)
              _row(context, 'Fiber',    gramFmt.format(nutrition.fiber!),    'g', cs),
            if (nutrition.sugar != null)
              _row(context, 'Sugar',    gramFmt.format(nutrition.sugar!),    'g', cs),
            if (nutrition.sodium != null)
              _row(context, 'Sodium',   mgFmt.format(nutrition.sodium!),     'mg',cs),
          ],
        ),
      ),
    );
  }

  Widget _row(
      BuildContext context,
      String label,
      String value,
      String unit,
      ColorScheme cs,
      ) {
    final display = '$value ${unit.isNotEmpty ? unit : ''}';
    // alternate row background to improve readability
    final isEven = label.hashCode.isEven;
    final bgColor = isEven
        ? cs.surface
        : cs.surfaceVariant.withOpacity(0.2);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            display,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            semanticsLabel: '$label: $display',
          ),
        ],
      ),
    );
  }
}
