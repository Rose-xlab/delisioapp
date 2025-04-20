// lib/screens/category_recipes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/categories.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/recipes/recipe_grid.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/error_display.dart';

class CategoryRecipesScreen extends StatefulWidget {
  final String categoryId;

  const CategoryRecipesScreen({
    Key? key,
    required this.categoryId,
  }) : super(key: key);

  @override
  _CategoryRecipesScreenState createState() => _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends State<CategoryRecipesScreen> {
  bool _isLoading = false;
  String? _error;
  List<Recipe> _recipes = [];
  int _currentPage = 0;
  bool _hasMoreRecipes = true;
  bool _isLoadingMore = false;
  String _sortOption = 'recent'; // Default sort option

  // Sorting options
  final List<Map<String, dynamic>> _sortOptions = [
    {'value': 'recent', 'label': 'Most Recent', 'icon': Icons.access_time},
    {'value': 'popular', 'label': 'Most Popular', 'icon': Icons.trending_up},
  ];

  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20; // Number of recipes per page

  @override
  void initState() {
    super.initState();
    _loadCategoryRecipes();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // User is near the end of the list, load more data
      if (!_isLoadingMore && _hasMoreRecipes && !_isLoading) {
        _loadMoreRecipes();
      }
    }
  }

  Future<void> _loadCategoryRecipes({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 0;
        _hasMoreRecipes = true;
        _recipes = [];
      }
      _error = null;
    });

    try {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get token only if user is authenticated
      final token = authProvider.isAuthenticated ? authProvider.token : null;

      final recipes = await recipeProvider.getCategoryRecipes(
        widget.categoryId,
        offset: _currentPage * _pageSize,
        limit: _pageSize,
        sort: _sortOption,
        token: token,
      );

      setState(() {
        if (refresh) {
          _recipes = recipes;
        } else {
          _recipes = [..._recipes, ...recipes];
        }
        _hasMoreRecipes = recipes.length == _pageSize; // If we got a full page, there might be more
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreRecipes() async {
    if (_isLoadingMore || !_hasMoreRecipes) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get token only if user is authenticated
      final token = authProvider.isAuthenticated ? authProvider.token : null;

      final recipes = await recipeProvider.getCategoryRecipes(
        widget.categoryId,
        offset: _currentPage * _pageSize,
        limit: _pageSize,
        sort: _sortOption,
        token: token,
      );

      setState(() {
        _recipes = [..._recipes, ...recipes];
        _hasMoreRecipes = recipes.length == _pageSize; // If we got a full page, there might be more
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        // Don't change error state to avoid disrupting UI
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more recipes: ${e.toString()}')),
      );
    }
  }

  void _changeSortOption(String newSortOption) {
    if (_sortOption != newSortOption) {
      setState(() {
        _sortOption = newSortOption;
      });
      _loadCategoryRecipes(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get category data from the constants
    final category = RecipeCategories.getCategoryById(widget.categoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        actions: [
          // Sort button
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: _changeSortOption,
            itemBuilder: (BuildContext context) {
              return _sortOptions.map((option) {
                return PopupMenuItem<String>(
                  value: option['value'],
                  child: Row(
                    children: [
                      Icon(
                        option['icon'],
                        color: _sortOption == option['value']
                            ? Theme.of(context).primaryColor
                            : null,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option['label'],
                        style: TextStyle(
                          fontWeight: _sortOption == option['value']
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortOption == option['value']
                              ? Theme.of(context).primaryColor
                              : null,
                        ),
                      ),
                      if (_sortOption == option['value'])
                        const Spacer()
                      else
                        const SizedBox.shrink(),
                      if (_sortOption == option['value'])
                        Icon(
                          Icons.check,
                          color: Theme.of(context).primaryColor,
                          size: 18,
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category header
          Container(
            padding: const EdgeInsets.all(16),
            color: category.color.withOpacity(0.1),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: category.color,
                  foregroundColor: Colors.white,
                  radius: 24,
                  child: Icon(category.icon, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Status info (e.g., number of recipes)
          if (_recipes.isNotEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_recipes.length}${_hasMoreRecipes ? '+' : ''} recipes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Sort indicator
                  Row(
                    children: [
                      Icon(
                        _sortOption == 'recent' ? Icons.access_time : Icons.trending_up,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortOption == 'recent' ? 'Most Recent' : 'Most Popular',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: _isLoading && _recipes.isEmpty
                ? const LoadingIndicator(message: 'Loading recipes...')
                : _error != null && _recipes.isEmpty
                ? ErrorDisplay(
              message: _error!,
              onRetry: () => _loadCategoryRecipes(refresh: true),
            )
                : _recipes.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: () => _loadCategoryRecipes(refresh: true),
              child: Column(
                children: [
                  Expanded(
                    child: RecipeGrid(
                      recipes: _recipes,
                      scrollController: _scrollController,
                      emptyMessage: 'No recipes found in this category',
                    ),
                  ),
                  // Loading indicator at the bottom when loading more
                  if (_isLoadingMore)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_food,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No recipes found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any recipes in this category',
            style: TextStyle(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _loadCategoryRecipes(refresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}