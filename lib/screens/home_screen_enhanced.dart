// lib/screens/home_screen_enhanced.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription.dart';
import '../widgets/home/trending_recipes.dart';
import '../widgets/home/recipe_grid.dart';
import '../widgets/search/search_bar.dart';
import '../constants/categories.dart';
import '../models/recipe_category.dart';
import '../models/recipe.dart';

class HomeScreenEnhanced extends StatefulWidget {
  const HomeScreenEnhanced({Key? key}) : super(key: key);

  @override
  _HomeScreenEnhancedState createState() => _HomeScreenEnhancedState();
}

class _HomeScreenEnhancedState extends State<HomeScreenEnhanced> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingTrending = false;
  bool _isLoadingRecipes = false;
  bool _isLoadingCategories = false;
  bool _isGenerating = false;
  String? _activeCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      if (!recipeProvider.isLoadingMore && recipeProvider.hasMoreRecipes) {
        _loadMoreRecipes();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingTrending = true;
      _isLoadingCategories = true;
      _isLoadingRecipes = true;
    });

    try {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.isAuthenticated ? authProvider.token : null;

      // Load subscription status if user is authenticated
      if (authProvider.isAuthenticated && token != null) {
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(token);
      }

      // Load trending recipes
      await recipeProvider.getTrendingRecipes(token: token);
      setState(() {
        _isLoadingTrending = false;
      });

      // Load recipe categories
      await recipeProvider.getAllCategories();
      setState(() {
        _isLoadingCategories = false;
      });

      // Load discover recipes (all categories initially)
      await recipeProvider.getDiscoverRecipes(
        category: _activeCategory,
        token: token,
      );
      setState(() {
        _isLoadingRecipes = false;
      });
    } catch (e) {
      print('Error loading initial data: $e');
      setState(() {
        _isLoadingTrending = false;
        _isLoadingCategories = false;
        _isLoadingRecipes = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recipes: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreRecipes() async {
    try {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.isAuthenticated ? authProvider.token : null;

      await recipeProvider.loadMoreDiscoverRecipes(
        category: _activeCategory,
        token: token,
        query: _searchQuery,
      );
    } catch (e) {
      print('Error loading more recipes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more recipes: $e')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.isAuthenticated ? authProvider.token : null;

      // Also refresh subscription data
      if (authProvider.isAuthenticated && token != null) {
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(token);
      }

      await recipeProvider.resetAndReloadDiscoverRecipes(
        category: _activeCategory,
        token: token,
        query: _searchQuery,
      );
      await recipeProvider.getTrendingRecipes(token: token);
      return; // Explicitly return to match Future<void>
    } catch (e) {
      print('Error refreshing data: $e');
      rethrow;
    }
  }

  void _onCategorySelected(String? categoryId) {
    setState(() {
      _activeCategory = categoryId;
      _searchController.clear();
      _searchQuery = '';
    });

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.isAuthenticated ? authProvider.token : null;

    recipeProvider.getDiscoverRecipes(
      category: categoryId,
      token: token,
    );
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.isAuthenticated ? authProvider.token : null;

    recipeProvider.getDiscoverRecipes(
      category: _activeCategory,
      query: query,
      token: token,
    );
  }

  void _onCancelSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.isAuthenticated ? authProvider.token : null;

    recipeProvider.getDiscoverRecipes(
      category: _activeCategory,
      token: token,
    );
  }

  Future<void> _generateRecipe() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a recipe name or ingredients')),
        );
      }
      return;
    }

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    // If we're already loading, don't start another generation
    if (recipeProvider.isLoading) return;

    setState(() => _isGenerating = true);
    print("Attempting to generate recipe for query: $query");
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await recipeProvider.generateRecipe(
        query,
        save: authProvider.token != null,
        token: authProvider.token,
      );

      // Only navigate if generation was successful and not cancelled
      if (!recipeProvider.wasCancelled && recipeProvider.error == null && mounted) {
        print("Recipe generation successful, navigating...");
        Navigator.of(context).pushNamed('/recipe');
      } else if (recipeProvider.wasCancelled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe generation cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error generating recipe: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating recipe: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _cancelRecipeGeneration() async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    if (recipeProvider.isLoading && !recipeProvider.isCancelling) {
      // Show cancellation in progress
      setState(() => _isGenerating = true); // _isGenerating should reflect recipeProvider.isLoading usually

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancelling recipe generation...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1), // Short duration for quick feedback
        ),
      );

      try {
        await recipeProvider.cancelRecipeGeneration();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe generation cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        print('Error during cancellation: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during cancellation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      // _isGenerating should be updated based on recipeProvider.isLoading in the build method
      // or explicitly set to false here if appropriate after cancellation.
      // However, the main build method already uses recipeProvider.isLoading for "isGenerating"
    }
  }

  void _viewRecipe(Recipe recipe) {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    recipeProvider.setCurrentRecipe(recipe);
    Navigator.of(context).pushNamed('/recipe');
  }

  void _viewCategory(String categoryId) {
    Navigator.of(context).pushNamed('/category/$categoryId');
  }

  Widget _buildSubscriptionBanner(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final subscriptionInfo = subscriptionProvider.subscriptionInfo;

    if (subscriptionInfo == null) {
      return const SizedBox.shrink();
    }

    if (subscriptionInfo.tier == SubscriptionTier.premium) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade700, Colors.purple.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.star, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Premium Plan - Unlimited Recipes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/subscription'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Manage'),
            ),
          ],
        ),
      );
    }

    Color color = subscriptionInfo.tier == SubscriptionTier.basic ? Colors.blue : Colors.green;
    String tierName = subscriptionInfo.tier == SubscriptionTier.basic ? 'Basic' : 'Free';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(
            subscriptionInfo.tier == SubscriptionTier.basic ? Icons.verified_user : Icons.restaurant_menu,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tierName Plan - ${subscriptionInfo.recipeGenerationsRemaining}/${subscriptionInfo.recipeGenerationsLimit} recipes left',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                if (subscriptionInfo.cancelAtPeriodEnd)
                  Text(
                    'Will cancel on ${_formatDate(subscriptionInfo.currentPeriodEnd)}',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/subscription'),
            style: TextButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(subscriptionInfo.tier == SubscriptionTier.basic ? 'Manage' : 'Upgrade'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    // final subscriptionProvider = Provider.of<SubscriptionProvider>(context); // Already available via _buildSubscriptionBanner
    final theme = Theme.of(context);

    final categories = recipeProvider.categories;
    final trendingRecipes = recipeProvider.trendingRecipes;
    final discoverRecipes = recipeProvider.discoverRecipes;

    // Use recipeProvider.isLoading for generate button state, as it's more specific
    final bool isGeneratingRecipe = recipeProvider.isLoading; // More accurate name
    final bool isCancelling = recipeProvider.isCancelling;
    final bool isLoadingMore = recipeProvider.isLoadingMore;

    final double navigationBarHeight = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: Column( // Main Column for the screen
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // This Column contains elements that should always be visible at the top
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Kitchen Assistant',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {
                        // Navigate to notifications
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EnhancedSearchBar(
                      controller: _searchController,
                      onSubmitted: _onSearch,
                      onCancel: _onCancelSearch,
                      isLoading: isGeneratingRecipe, // Use specific loading state
                      hintText: 'Search or generate recipes...',
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                          const Text(
                            'Generate a new recipe:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          isGeneratingRecipe // Use specific loading state
                              ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: isCancelling ? null : _cancelRecipeGeneration,
                                icon: isCancelling
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.close, size: 16),
                                label: const Text('Cancel'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          )
                              : FittedBox(
                            child: TextButton.icon(
                              onPressed: _generateRecipe,
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Generate Recipe'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (authProvider.isAuthenticated)
                _buildSubscriptionBanner(context),

              // This Expanded widget will contain the scrollable content
              Expanded(
                child: ListView( // This is the main scrollable list
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_isLoadingCategories)
                            SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 110,
                      child: _isLoadingCategories
                          ? _buildCategoriesLoadingList()
                          : _buildCategoriesList(categories, _activeCategory),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Trending Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_isLoadingTrending)
                            SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                            ),
                        ],
                      ),
                    ),
                    TrendingRecipes(
                      recipes: trendingRecipes,
                      onRecipeTap: _viewRecipe,
                      isLoading: _isLoadingTrending,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _activeCategory == null ? 'Discover Recipes' : _getCategoryTitle(_activeCategory!),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (_activeCategory != null)
                            TextButton(
                              onPressed: () => _onCategorySelected(null),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('See All'),
                            ),
                        ],
                      ),
                    ),

                    // --- MODIFICATION HERE ---
                    // Remove the SizedBox with fixed height around RecipeGrid.
                    // Pass the correct _isLoadingRecipes state.
                    _isLoadingRecipes && discoverRecipes.isEmpty // Show main loading only if recipes are empty
                        ? const Center(child: Padding(
                      padding: EdgeInsets.all(16.0), // Added padding
                      child: CircularProgressIndicator(),
                    ))
                        : discoverRecipes.isEmpty && !_isLoadingRecipes // Show empty state only if not loading and recipes are empty
                        ? _buildEmptyState()
                        : RecipeGrid(
                      recipes: discoverRecipes,
                      onRecipeTap: _viewRecipe,
                      // isLoading should be used by RecipeGrid for its internal shimmer/placeholders
                      // However, the parent now handles the main loading indicator / empty state.
                      // If RecipeGrid's isLoading is purely for shimmer, pass false or a different flag.
                      // For now, passing _isLoadingRecipes to be consistent with its prop.
                      isLoading: _isLoadingRecipes && discoverRecipes.isNotEmpty, // Show shimmer if loading more but some recipes exist
                    ),
                    // --- END OF MODIFICATION ---

                    SizedBox(height: navigationBarHeight + 10),
                    if (isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(List<RecipeCategory> categories, String? activeCategory) {
    if (categories.isEmpty) {
      return const Center(child: Text('No categories available'));
    }
    final allCategories = [
      RecipeCategory(id: 'all', name: 'All', description: 'All recipes', icon: Icons.apps, color: Colors.blueGrey),
      ...categories,
    ];
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: allCategories.length,
      itemBuilder: (context, index) {
        final category = allCategories[index];
        final isActive = (activeCategory == category.id) || (activeCategory == null && category.id == 'all');
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => _onCategorySelected(category.id == 'all' ? null : category.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isActive ? category.color : category.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: isActive ? Border.all(color: category.color, width: 2) : null,
                    boxShadow: isActive
                        ? [BoxShadow(color: category.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Icon(category.icon, color: isActive ? Colors.white : category.color, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? category.color : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesLoadingList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
              const SizedBox(height: 8),
              Container(width: 60, height: 12, color: Colors.grey[300]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message = 'No recipes found';
    if (_searchQuery.isNotEmpty) {
      message = 'No recipes found for "$_searchQuery"';
    } else if (_activeCategory != null) {
      message = 'No recipes found in ${_getCategoryTitle(_activeCategory!)}';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Try a different search or category', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _generateRecipe,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                child: const Text('Generate This Recipe'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getCategoryTitle(String categoryId) {
    final category = RecipeCategories.getCategoryById(categoryId);
    return category.name;
  }
}