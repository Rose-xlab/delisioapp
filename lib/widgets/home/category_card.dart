//C:\Users\mukas\StudioProjects\delisio\lib\widgets\home\category_card.dart

import 'package:flutter/material.dart';
import '../../constants/categories.dart'; // This import is correct

class CategoryCard extends StatelessWidget {
  final RecipeCategoryData category;
  final VoidCallback onTap;
  final int? recipeCount;
  final bool isHighlighted; // This will be used to show "selected" state

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

    final primaryColor = category.color;
    // Ensure secondaryColor doesn't become too dark or too similar if lightness is already low
    final hslPrimary = HSLColor.fromColor(primaryColor);
    final secondaryColor = hslPrimary
        .withLightness((hslPrimary.lightness * 0.7).clamp(0.0, 1.0)) // Clamp lightness
        .toColor();

    return Card(
      elevation: isHighlighted ? 6 : 2, // Slightly more elevation when highlighted
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? BorderSide(color: primaryColor.withOpacity(0.8), width: 2.5) // More prominent border
            : BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 0.5), // Subtle border otherwise
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: primaryColor.withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isHighlighted
                  ? [ // More vibrant gradient when selected
                primaryColor.withOpacity(0.4),
                secondaryColor.withOpacity(0.25),
              ]
                  : [
                primaryColor.withOpacity(0.15), // Subtle default gradient
                secondaryColor.withOpacity(0.07),
              ],
            ),
          ),
          child: Stack( // Use Stack to overlay a checkmark if selected
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center, // Center content
                  children: [
                    Icon(
                      category.icon,
                      size: 40,
                      color: isHighlighted ? primaryColor : primaryColor.withOpacity(0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                        color: isHighlighted ? primaryColor : colorScheme.onSurface,
                      ),
                      maxLines: 1, // Ensure category name doesn't wrap too much
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipeCount != null && recipeCount! > 0) ...[ // Only show if count > 0
                      const SizedBox(height: 4),
                      Text(
                        '$recipeCount ${recipeCount == 1 ? 'recipe' : 'recipes'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isHighlighted
                              ? primaryColor.withOpacity(0.9)
                              : colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isHighlighted) // Show a checkmark icon when selected
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}