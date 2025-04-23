// lib/widgets/profile/usage_progress_bar.dart
import 'package:flutter/material.dart';

class UsageProgressBar extends StatelessWidget {
  final int used;
  final int total;
  final Color color;

  const UsageProgressBar({
    Key? key,
    required this.used,
    required this.total,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? used / total : 0.0;
    final isWarning = progress >= 0.8; // Warning when close to limit

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isWarning ? Colors.orange : color,
            ),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}