// lib/widgets/profile/skill_level_indicator.dart
import 'package:flutter/material.dart';

class SkillLevelIndicator extends StatelessWidget {
  final String level;

  const SkillLevelIndicator({
    Key? key,
    required this.level,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Convert the level string to a numeric value
    int levelValue;
    Color levelColor;
    String levelLabel;

    switch (level.toLowerCase()) {
      case 'beginner':
        levelValue = 1;
        levelColor = Colors.green;
        levelLabel = 'Beginner';
        break;
      case 'intermediate':
        levelValue = 2;
        levelColor = Colors.orange;
        levelLabel = 'Intermediate';
        break;
      case 'advanced':
        levelValue = 3;
        levelColor = Colors.red;
        levelLabel = 'Advanced';
        break;
      default:
        levelValue = 1;
        levelColor = Colors.green;
        levelLabel = 'Beginner';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Cooking Skill:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              levelLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: levelColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              // Level 1 (Beginner) - always filled
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: levelValue >= 1 ? levelColor : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      bottomLeft: Radius.circular(5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // Level 2 (Intermediate)
              Expanded(
                child: Container(
                  color: levelValue >= 2 ? levelColor : Colors.transparent,
                ),
              ),
              const SizedBox(width: 2),
              // Level 3 (Advanced)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: levelValue >= 3 ? levelColor : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(5),
                      bottomRight: Radius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}