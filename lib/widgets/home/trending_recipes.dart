// lib/widgets/home/trending_recipes.dart

import 'package:flutter/material.dart';
import '../../models/recipe.dart';
// Import CachedNetworkImage package
import 'package:cached_network_image/cached_network_image.dart';

class TrendingRecipes extends StatelessWidget {
  final List<Recipe> recipes;
  final Function(Recipe)? onRecipeTap;
  final bool isLoading;

  const TrendingRecipes({
    Key? key,
    required this.recipes,
    this.onRecipeTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingList();
    }

    if (recipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'No trending recipes available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

  return SizedBox(
  height: 230,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    itemCount: recipes.length,
    separatorBuilder: (context, index) => const SizedBox(width: 8),
    itemBuilder: (context, index) {
      final recipe = recipes[index];
      return TrendingRecipeItem(
        recipe: recipe,
        onTap: onRecipeTap != null ? () => onRecipeTap!(recipe) : null,
      );
    },
  ),
);
  }

  // --- Loading List Method (Unchanged from your original) ---
  Widget _buildLoadingList() {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 3, // Show 3 loading placeholders
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
// --- End Loading List Method ---
}


// --- MODIFIED WIDGET ---
class TrendingRecipeItem extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const TrendingRecipeItem({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Define the accent color from the image for reusability.
    const Color accentColor = Color(0xFFF23B5A);
    final String? thumbnailUrl = recipe.thumbnailUrl;
    final bool hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:180, // Adjusted width for better proportions
        height: 280, // Added height for a more vertical card
        decoration: BoxDecoration(
          color: Colors.white, // Set a base color for the card
          borderRadius: BorderRadius.circular(16), // Slightly more rounded corners
          boxShadow: [ // A softer shadow for a more subtle depth
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- Background Image ---
              Positioned.fill(
                child: hasThumbnail
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                            ),
                          );
                        },
                      )
                    : Container( // Placeholder if no image is available
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
              ),

              // --- Content Overlay at the Bottom ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  // This container creates the dark, semi-transparent background for the text.
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Recipe Title
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18, // Slightly larger font for the title
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Info Row (Time and Category)
                      Row(
                        children: [
                          // Time Info
                          if (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0)
                            _buildInfoWidget(
                              icon: Icons.timer_outlined,
                              text: '${recipe.totalTimeMinutes} mins',
                              iconColor: accentColor,
                            ),

                          const SizedBox(width: 16), // Spacer between the two info items

                          // Category Info
                          if (recipe.category != null)
                            _buildInfoWidget(
                              icon: Icons.restaurant_menu_outlined,
                              text: _formatCategory(recipe.category!),
                              iconColor: accentColor,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper widget to build the icon-text pairs for the info row.
  Widget _buildInfoWidget({required IconData icon, required String text, required Color iconColor}) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Helper to format category name (e.g., "lunch" -> "Lunch").
  String _formatCategory(String category) {
    if (category.isEmpty) return '';
    return '${category[0].toUpperCase()}${category.substring(1).toLowerCase()}';
  }
}