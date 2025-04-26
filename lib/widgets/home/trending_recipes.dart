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
      height: 230, // Adjust height as needed
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          // Use the updated TrendingRecipeItem
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


// *** MODIFIED TrendingRecipeItem ***
class TrendingRecipeItem extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const TrendingRecipeItem({
    Key? key,
    required this.recipe,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- USE THUMBNAIL URL ---
    final String? thumbnailUrl = recipe.thumbnailUrl; // Get the correct URL
    final bool hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    // --- END USE THUMBNAIL URL ---

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200, // Width of the trending card
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand, // Make stack fill the container
              children: [
                // Background image - USE THUMBNAIL URL
                Positioned.fill(
                    child: Container( // Container for placeholder background
                      color: Colors.grey[100],
                      child: hasThumbnail
                          ? CachedNetworkImage( // Use CachedNetworkImage
                        imageUrl: thumbnailUrl!, // Use the correct URL
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) {
                          print("Error loading trending image: $url, Error: $error");
                          return Center( // Error placeholder
                            child: Icon(
                              Icons.restaurant_menu,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                          );
                        },
                      )
                          : Center( // Placeholder icon if no thumbnail URL
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 40,
                          color: Theme.of(context).primaryColor.withOpacity(0.5),
                        ),
                      ),
                    )
                ),
                // Gradient overlay (Unchanged from your original)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [ Colors.transparent, Colors.black.withOpacity(0.7)],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Content (Unchanged from your original)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          recipe.title,
                          style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16,
                            shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! > 0) ...[
                              const Icon(Icons.timer, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text('${recipe.totalTimeMinutes} min', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(width: 8),
                            ],
                            if (recipe.category != null) ...[
                              const Icon(Icons.restaurant_menu, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatCategory(recipe.category!),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Trending indicator (Unchanged from your original)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Trending', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                // Favorite indicator (Unchanged from your original)
                if (recipe.isFavorite)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
                      child: const Icon(Icons.favorite, color: Colors.red, size: 16),
                    ),
                  ),
              ],
            ),
          ),
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