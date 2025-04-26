// lib/widgets/home/recipe_grid.dart

import 'package:flutter/material.dart';
import '../../models/recipe.dart';
// Import CachedNetworkImage package (ensure it's added to pubspec.yaml)
import 'package:cached_network_image/cached_network_image.dart';

class RecipeGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final ScrollController? scrollController;
  final String emptyMessage;
  final Function(Recipe)? onRecipeTap;
  final bool isLoading;
  final int crossAxisCount;
  final double childAspectRatio;

  const RecipeGrid({
    Key? key,
    required this.recipes,
    this.scrollController,
    this.emptyMessage = 'No recipes found',
    this.onRecipeTap,
    this.isLoading = false,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.75, // Adjust aspect ratio if needed
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Show loading shimmer if specified
    if (isLoading) {
      return _buildLoadingGrid(context);
    }

    // Show empty state if no recipes
    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Show the grid of recipes
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        // Use the updated RecipeGridItem
        return RecipeGridItem(
          recipe: recipe,
          onTap: onRecipeTap != null ? () => onRecipeTap!(recipe) : null,
        );
      },
    );
  }

  // --- Loading Grid Methods (Unchanged from your original) ---
  Widget _buildLoadingGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6, // Show 6 loading placeholders
      itemBuilder: (context, index) {
        return _buildLoadingItem(context);
      },
    );
  }
  Widget _buildLoadingItem(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Container(color: Colors.grey[300], width: double.infinity)),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: double.infinity, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, color: Colors.grey[300]),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(height: 12, width: 40, color: Colors.grey[300]),
                      Container(height: 12, width: 40, color: Colors.grey[300]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
// --- End Loading Grid Methods ---
}


// *** RecipeGridItem MODIFIED to use thumbnailUrl ***
class RecipeGridItem extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeGridItem({
    Key? key,
    required this.recipe,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- MODIFICATION START: Use thumbnailUrl ---
    final String? thumbnailUrl = recipe.thumbnailUrl; // Get the correct URL
    final bool hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    // --- MODIFICATION END ---

    return Card(
      clipBehavior: Clip.antiAlias, // Good for rounded corners on images
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Thumbnail Image
            Expanded(
              flex: 3, // Adjust flex as needed
              child: Hero( // Optional: Add Hero animation
                // Use a unique tag, including hashCode as fallback if id is null
                tag: 'recipe_image_${recipe.id ?? recipe.hashCode}',
                child: Container( // Container for placeholder background
                  color: Colors.grey[100], // Background color for placeholder area
                  child: hasThumbnail
                      ? CachedNetworkImage( // Use CachedNetworkImage
                    imageUrl: thumbnailUrl!, // Use the correct URL
                    fit: BoxFit.cover,
                    width: double.infinity, // Fill width
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) {
                      print("Error loading grid image: $url, Error: $error");
                      return Center( // Error placeholder
                        child: Icon(
                          Icons.restaurant_menu, // Icon for error/missing
                          color: Colors.grey[400],
                          size: 40,
                        ),
                      );
                    } ,
                  )
                      : Center( // Placeholder icon if no thumbnail URL
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 40,
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
            // Recipe info (Unchanged from your original)
            Expanded(
              flex: 2, // Adjust flex
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes details to bottom
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.servings}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            ),
                          ],
                        ),
                        if (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${recipe.totalTimeMinutes}m',
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                            ],
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
    );
  }

  // Helper to format category name (Unchanged from your original)
  String _formatCategory(String category) {
    return category.replaceAll('-', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }
}