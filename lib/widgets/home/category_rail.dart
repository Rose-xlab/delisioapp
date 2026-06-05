// lib/widgets/home/category_rail.dart
//
// A single category section for the home feed: a header (category name + "See all")
// above a horizontal-scrolling rail of recipe cards. It fetches its own recipes and
// hides itself entirely if the category turns out to be empty. Mirrors the web rails.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/auth_provider.dart';
import 'trending_recipes.dart';

class CategoryRail extends StatefulWidget {
  final String categoryId;
  final String categoryTitle;
  final void Function(Recipe) onRecipeTap;
  final VoidCallback onSeeAll;

  const CategoryRail({
    Key? key,
    required this.categoryId,
    required this.categoryTitle,
    required this.onRecipeTap,
    required this.onSeeAll,
  }) : super(key: key);

  @override
  State<CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<CategoryRail> {
  List<Recipe> _recipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final recipes = await recipeProvider.getCategoryRecipes(
        widget.categoryId,
        sort: 'popular',
        limit: 10,
        token: authProvider.token,
      );
      if (mounted) {
        setState(() {
          _recipes = recipes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide categories that have no recipes.
    if (!_loading && _recipes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.categoryTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: widget.onSeeAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 230,
          child: TrendingRecipes(
            recipes: _recipes,
            onRecipeTap: widget.onRecipeTap,
            isLoading: _loading,
          ),
        ),
      ],
    );
  }
}
