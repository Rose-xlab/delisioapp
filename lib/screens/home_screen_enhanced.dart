import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // Keep RevenueCat UI import

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
    if (mounted) {
      setState(() {
        _isLoadingTrending = true;
        _isLoadingCategories = true;
        _isLoadingRecipes = true;
      });
    }

    try {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.isAuthenticated ? authProvider.token : null;
      final userID = authProvider.isAuthenticated ? authProvider.user?.id : null;

      if (authProvider.isAuthenticated && token != null && userID != null) {

         //re initialise revenuecat with customer identifier (user app ID) when authenticated
        LogInResult result = await Purchases.logIn(userID);
        debugPrint(result.toString());


        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(token);
      }

      await recipeProvider.getTrendingRecipes(token: token);
      
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
        });
      }


      await recipeProvider.getAllCategories();
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }


      await recipeProvider.getDiscoverRecipes(
        category: _activeCategory,
        token: token,
      );
      if (mounted) {
        setState(() {
          _isLoadingRecipes = false;
        });
      }

    } catch (e) {
      print('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
          _isLoadingCategories = false;
          _isLoadingRecipes = false;
        });
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
      return;
    } catch (e) {
      print('Error refreshing data: $e');
      rethrow;
    }
  }

  void _onCategorySelected(String? categoryId) {
    if(mounted){
      setState(() {
        _activeCategory = categoryId;
        _searchController.clear();
        _searchQuery = '';
      });
    }


    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.isAuthenticated ? authProvider.token : null;

    recipeProvider.getDiscoverRecipes(
      category: categoryId,
      token: token,
    );
  }

  void _onSearch(String query) {
    if(mounted){
      setState(() {
        _searchQuery = query;
      });
    }


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
    if(mounted){
      setState(() {
        _searchController.clear();
        _searchQuery = '';
      });
    }


    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.isAuthenticated ? authProvider.token : null;

    recipeProvider.getDiscoverRecipes(
      category: _activeCategory,
      token: token,
    );
  }

  Future<void> _generateRecipeViaRecipeProvider() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a recipe name or ingredients to generate.')),
        );
      }
      return;
    }
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    if (recipeProvider.isLoading) return;
    print("Attempting to generate recipe for query (via RecipeProvider): $query");
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await recipeProvider.generateRecipe(
        query,
        save: authProvider.token != null,
        token: authProvider.token,
      );
      if (!recipeProvider.wasCancelled && recipeProvider.error == null && mounted) {
        print("Recipe generation successful (via RecipeProvider), navigating...");
        Navigator.of(context).pushNamed('/recipe');
      } else if (recipeProvider.wasCancelled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe generation cancelled'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print('Error generating recipe (via RecipeProvider): ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating recipe: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRecipeGenerationViaRecipeProvider() async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    if (recipeProvider.isLoading && !recipeProvider.isCancelling) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancelling recipe generation...'), backgroundColor: Colors.blue, duration: Duration(seconds: 1)),
        );
      }
      try {
        await recipeProvider.cancelRecipeGeneration();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe generation cancelled by user.'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        print('Error during cancellation (via RecipeProvider): $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error during cancellation: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _navigateToChatScreenWithQuery() {
    final query = _searchController.text.trim();
    Navigator.of(context).pushNamed('/chat', arguments: {
      'initialQuery': query.isNotEmpty ? query : null,
      'purpose': 'generateRecipe'
    });
  }

  void _navigateToNewChatScreen() {
    Navigator.of(context).pushNamed('/chat', arguments: {
      'initialQuery': null,
      'purpose': 'newChatFromHomeFab'
    });
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
      return const SizedBox.shrink(); // No info, show nothing
    }

    if (subscriptionInfo.tier == SubscriptionTier.pro) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pro Plan - Unlimited Recipes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            TextButton(
              // RESOLVED: "Manage" button for Pro users.
              // Reverted to navigating to your custom subscription screen.
              // Showing a paywall for "Manage" is incorrect.
              // If RevenueCat is to handle management, a different RevenueCat SDK call would be needed.
              onPressed: () => Navigator.of(context).pushNamed('/subscription'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.25),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Manage'),
            ),
          ],
        ),
      );
    } else { // Free Plan
      Color color = Colors.green;
      String tierName = 'Free';

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.7)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_florist_outlined,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$tierName Plan: ${subscriptionInfo.recipeGenerationsRemaining}/${subscriptionInfo.recipeGenerationsLimit} recipes left',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            // RESOLVED: "Upgrade" button for Free users. Uses RevenueCat paywall.
            TextButton(
              onPressed: () { // Using a block for clarity, though not strictly necessary for single call
                RevenueCatUI.presentPaywallIfNeeded("TestPro");
              },
              style: TextButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Upgrade'),
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    final categories = recipeProvider.categories;
    final trendingRecipes = recipeProvider.trendingRecipes;
    final discoverRecipes = recipeProvider.discoverRecipes;

    final bool isSearchBarLoading = recipeProvider.isLoading;
    final bool isLoadingMore = recipeProvider.isLoadingMore;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double fabSize = 56.0;
    final double fabTopPosition = (screenHeight / 2) - (fabSize / 2) - (MediaQuery.of(context).padding.top / 2);
    final double navigationBarHeight = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshData,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          'Kitchen Assistant',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
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
                  if (authProvider.isAuthenticated)
                    _buildSubscriptionBanner(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EnhancedSearchBar(
                          controller: _searchController,
                          onSubmitted: _onSearch,
                          onCancel: _onCancelSearch,
                          isLoading: isSearchBarLoading,
                          hintText: 'Search recipes or start a chat...',
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: _navigateToChatScreenWithQuery,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                              ),
                              child: const Text('Generate Recipe'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
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
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor)),
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
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor)),
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
                        _isLoadingRecipes && discoverRecipes.isEmpty
                            ? const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ))
                            : discoverRecipes.isEmpty && !_isLoadingRecipes
                            ? _buildEmptyState()
                            : RecipeGrid(
                          recipes: discoverRecipes,
                          onRecipeTap: _viewRecipe,
                          isLoading: _isLoadingRecipes && discoverRecipes.isNotEmpty,
                        ),
                        SizedBox(height: navigationBarHeight + 10),
                        if (isLoadingMore)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (authProvider.isAuthenticated)
              Positioned(
                right: 16.0,
                top: fabTopPosition,
                child: FloatingActionButton(
                  heroTag: 'homeScreenNewChatFab',
                  onPressed: _navigateToNewChatScreen,
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                  elevation: 6.0,
                  child: const Icon(Icons.add_comment_outlined),
                ),
              ),
          ],
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
            Text('Try a different search or category, or chat with our AI for new ideas!', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateRecipeViaRecipeProvider,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate This Recipe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
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