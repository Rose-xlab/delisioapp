// widgets/recipes/nutrition_card.dart
import 'package:flutter/material.dart';
import '../../models/nutrition_info.dart';

class NutritionCard extends StatelessWidget {
  final NutritionInfo nutrition;

  const NutritionCard({
    Key? key,
    required this.nutrition,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nutrition Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Per serving',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            _buildNutritionRow('Calories', '${nutrition.calories} kcal'),
            _buildNutritionRow('Protein', nutrition.protein),
            _buildNutritionRow('Fat', nutrition.fat),
            _buildNutritionRow('Carbohydrates', nutrition.carbs),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}