// lib/widgets/home/category_card.dart
import 'package:flutter/material.dart';
import '../../constants/categories.dart';

class CategoryCard extends StatelessWidget {
  final RecipeCategoryData category;
  final VoidCallback onTap;
  final int? recipeCount;
  final bool isHighlighted;

  const CategoryCard({
    Key? key,
    required this.category,
    required this.onTap,
    this.recipeCount,
    this.isHighlighted = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate gradient colors based on category's color
    final primaryColor = category.color;
    final secondaryColor = HSLColor.fromColor(primaryColor)
        .withLightness(HSLColor.fromColor(primaryColor).lightness * 0.7)
        .toColor();

    return Card(
      elevation: isHighlighted ? 4 : 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? BorderSide(color: primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: primaryColor.withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                // Use opacity to make the gradient subtle
                primaryColor.withOpacity(isHighlighted ? 0.3 : 0.1),
                secondaryColor.withOpacity(isHighlighted ? 0.15 : 0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Category icon
                Icon(
                  category.icon,
                  size: 40,
                  color: primaryColor,
                ),
                const SizedBox(height: 8),
                // Category name
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (recipeCount != null) ...[
                  const SizedBox(height: 4),
                  // Recipe count
                  Text(
                    '$recipeCount ${recipeCount == 1 ? 'recipe' : 'recipes'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}