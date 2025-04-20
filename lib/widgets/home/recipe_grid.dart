// lib/widgets/home/recipe_grid.dart
import 'package:flutter/material.dart';
import '../../models/recipe.dart';

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
    this.childAspectRatio = 0.75,
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
        return RecipeGridItem(
          recipe: recipe,
          onTap: onRecipeTap != null ? () => onRecipeTap!(recipe) : null,
        );
      },
    );
  }

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
          // Image placeholder
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[300],
              width: double.infinity,
            ),
          ),
          // Content placeholder
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 100,
                    color: Colors.grey[300],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 12,
                        width: 40,
                        color: Colors.grey[300],
                      ),
                      Container(
                        height: 12,
                        width: 40,
                        color: Colors.grey[300],
                      ),
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
    // Get the first step image URL to use as a recipe thumbnail
    String? imageUrl;
    if (recipe.steps.isNotEmpty && recipe.steps[0].imageUrl != null) {
      imageUrl = recipe.steps[0].imageUrl;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                  )
                      : Container(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Center(
                      child: Icon(
                        Icons.restaurant,
                        size: 40,
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                  // Favorite indicator
                  if (recipe.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 18,
                        ),
                      ),
                    ),
                  // Category tag if available
                  if (recipe.category != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        color: Colors.black.withOpacity(0.6),
                        child: Text(
                          _formatCategory(recipe.category!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Recipe info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipe title
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Recipe details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Servings
                        Row(
                          children: [
                            const Icon(Icons.people, size: 16, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(
                              '${recipe.servings}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        // Time if available
                        if (recipe.totalTimeMinutes != null)
                          Row(
                            children: [
                              const Icon(Icons.timer, size: 16, color: Colors.grey),
                              const SizedBox(width: 2),
                              Text(
                                '${recipe.totalTimeMinutes}m',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
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

  // Helper to format category name
  String _formatCategory(String category) {
    return category.replaceAll('-', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }
}