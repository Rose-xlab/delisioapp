// lib/widgets/home/recipe_grid.dart
import 'package:flutter/material.dart';
import '../../models/recipe.dart';
// Import CachedNetworkImage package (ensure it's added to pubspec.yaml)
import 'package:cached_network_image/cached_network_image.dart';

class RecipeGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final ScrollController? scrollController; // Retained as it's part of the original API
  final String emptyMessage;
  final Function(Recipe)? onRecipeTap;
  final bool isLoading; // This will now be _isLoadingRecipes from the parent
  final int crossAxisCount;
  final double childAspectRatio;

  const RecipeGrid({
    Key? key,
    required this.recipes,
    this.scrollController,
    this.emptyMessage = 'No recipes found',
    this.onRecipeTap,
    this.isLoading = false,
    this.crossAxisCount = 1,
    this.childAspectRatio = 0.75, // Adjust aspect ratio if needed
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Show loading shimmer if specified by the parent AND recipes list is not empty
    // If recipes IS empty, the parent HomeScreenEnhanced will show a centered CircularProgressIndicator.
    if (isLoading && recipes.isNotEmpty) { // Only show shimmer if loading more on existing items
      return _buildLoadingGrid(context);
    }

    // Show empty state if no recipes (and not loading initial set - parent handles that)
    if (recipes.isEmpty && !isLoading) { // Ensure not to show empty if parent is still loading initial
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
    // If recipes is empty and isLoading is true, parent HomeScreenEnhanced shows the primary loader.
    // So we only reach here if recipes has items OR if recipes is empty and not loading.

    // Show the grid of recipes
    return GridView.builder(
      controller: scrollController, // Parent passes its own scrollController if needed for other logic
      // but this GridView itself won't scroll.
      padding: const EdgeInsets.all(8),
      physics: const NeverScrollableScrollPhysics(), // Ensures this grid doesn't scroll independently
      shrinkWrap: true, // Important when inside another scrollable and not scrolling itself
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: screenWidth > 600 ? 4 : crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return RecipeGridItem(
          recipe: recipe,
          onTap: onRecipeTap != null ? () => onRecipeTap!(recipe) : null,
        );
      },
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    // This builds shimmer/placeholder items
    final screenWidth = MediaQuery.sizeOf(context).width;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const NeverScrollableScrollPhysics(), // Should not scroll
      shrinkWrap: true, // Important
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: screenWidth > 600 ? 4 : crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: recipes.isNotEmpty ? recipes.length : 6, // Show placeholders matching current items or a default
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
}

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
    final String? thumbnailUrl = recipe.thumbnailUrl;
    final bool hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;

    return SizedBox(
      height: 100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(10))
        ),
        padding: EdgeInsets.all(8.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recipe Image
            AspectRatio(
              aspectRatio:1,
              child: Hero(
                tag: 'recipe_image_${recipe.id ?? recipe.hashCode}',
                child: hasThumbnail
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            Icons.restaurant_menu,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 40,
                          color: Theme.of(context).primaryColor.withOpacity(0.5),
                        ),
                      ),
              ),
            ),
            // Title and Attributes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                recipe.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Servings
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 16, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.servings}',
                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                      ),
                    ],
                  ),
                  // Difficulty
                  Row(
                    children: [
                      Icon(Icons.bar_chart, size: 16, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Easy',
                        style: TextStyle(color: Colors.red[400], fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  // Time
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.totalTimeMinutes} Mins',
                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height:4),
          ],
        ),
      ),
    ),
    );
  }
}


  // _formatCategory helper is not used in RecipeGridItem, so it can be removed
  // if it's not used elsewhere or was just part of an older version.
  // For now, I'll keep it as it was in your provided code.
//   String _formatCategory(String category) {
//     return category.replaceAll('-', ' ').split(' ').map((word) {
//       if (word.isEmpty) return '';
//       return '${word[0].toUpperCase()}${word.substring(1)}';
//     }).join(' ');
//   }
// }