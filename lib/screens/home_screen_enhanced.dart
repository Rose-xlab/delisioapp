// lib/screens/home/home_screen_enhanced.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kitchenassistant/constants/myofferings.dart';
import 'package:kitchenassistant/widgets/home/greetings_card.dart';
import 'package:kitchenassistant/widgets/home/home_card.dart';
import 'package:kitchenassistant/widgets/home/new_search_bar.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // Keep RevenueCat UI import
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription.dart';
import '../../widgets/home/trending_recipes.dart';
import '../../widgets/home/recipe_grid.dart';
import '../../widgets/search/search_bar.dart'; // Assuming this is EnhancedSearchBar
import '../../constants/categories.dart';
import '../../models/recipe_category.dart';
import '../../models/recipe.dart';

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
  bool _isSearchUIVisible = false;

  String? _activeCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint("------------ HomeScreenEnhanced initState() ----------------");
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

  Future<void> getprofiles() async {
    try {
      final client = Supabase.instance.client;
      // Use listen: false as this method is not directly rebuilding UI based on these provider changes
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final subsProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      final userId = authProvider.isAuthenticated ? authProvider.user?.id : null;

      String? token = authProvider.token;

      if (userId == null) {
        if (kDebugMode) debugPrint("getprofiles: User not authenticated. Skipping RevenueCat login.");
        return;
      }
      String uid = userId;

      // Fetch only the user_app_id column
      final profileResponse = await client.from("profiles").select("user_app_id").eq("id", uid).single();

      // The response from Supabase is a Map<String, dynamic>
      final String? userAppId = profileResponse['user_app_id'] as String?;


      if (kDebugMode) debugPrint("================ PROFILE APP ID FROM DB: $userAppId");

      if (userAppId != null && userAppId.isNotEmpty) {
        LogInResult result = await Purchases.logIn(userAppId);
        if (kDebugMode) {
          debugPrint("================================== REVCAT LOGIN RESULT ============");
          debugPrint("CustomerInfo Original App User ID: ${result.customerInfo.originalAppUserId}");
          debugPrint("Active Entitlements: ${result.customerInfo.entitlements.active.toString()}");
          debugPrint("Login Created User: ${result.created}");
          debugPrint("================================== ============");
        }
        // After successful login, update the RevenueCat subscription status in your provider
        if(token != null){
            await subsProvider.revenueCatSubscriptionStatus(token);
        }
         // Ensure this is awaited
      } else {
           if (kDebugMode) debugPrint("getprofiles: user_app_id is null or empty from DB. Cannot log into RevenueCat.");
          // Handle case where user_app_id might be missing (e.g. older user accounts)
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error in getprofiles or RevenueCat login: ${e.toString()}");
      // Log this error to Sentry or your preferred logging service
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

      // If authenticated, perform operations that require login
      if (authProvider.isAuthenticated && token != null) {
        await getprofiles(); // Call getprofiles to log into RevenueCat and update status
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(token); // Your backend subscription status
      }

      // These can load even for non-authenticated users, if your backend allows
      await recipeProvider.getTrendingRecipes(token: token);
      if (mounted) setState(() => _isLoadingTrending = false);

      await recipeProvider.getAllCategories();
      if (mounted) setState(() => _isLoadingCategories = false);

      await recipeProvider.getDiscoverRecipes(
        category: _activeCategory,
        token: token,
      );
      if (mounted) setState(() => _isLoadingRecipes = false);

    } catch (e) {
      if (kDebugMode) debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
          _isLoadingCategories = false;
          _isLoadingRecipes = false;
        });
        if (context.mounted) { // Check if context is still valid
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading recipes: $e')),
          );
        }
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
      if (kDebugMode) debugPrint('Error loading more recipes: $e');
      if (mounted) {
        if (context.mounted) { // Check if context is still valid
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading more recipes: $e')),
          );
        }
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.isAuthenticated ? authProvider.token : null;

      if (authProvider.isAuthenticated && token != null) {
        // Refresh RevenueCat status and backend status on pull-to-refresh
        await getprofiles();
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(token);
      }

      String? currentQuery = _isSearchUIVisible && _searchQuery.isNotEmpty ? _searchQuery : null;

      await recipeProvider.resetAndReloadDiscoverRecipes(
        category: _activeCategory,
        token: token,
        query: currentQuery ?? _searchQuery,
      );
      await recipeProvider.getTrendingRecipes(token: token);
      // No explicit return needed for Future<void>
    } catch (e) {
      if (kDebugMode) debugPrint('Error refreshing data: $e');
      rethrow; // Rethrow to allow RefreshIndicator to handle it
    }
  }

  void _onCategorySelected(String? categoryId) {
    if (mounted) {
      setState(() {
        _activeCategory = categoryId;
        _searchController.clear();
        _searchQuery = '';
        if (_isSearchUIVisible) {
          _isSearchUIVisible = false;
        }
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
    if (mounted) {
      setState(() {
        _searchQuery = query;
        _activeCategory = null; // Clear category when searching
      });
    }

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.isAuthenticated ? authProvider.token : null;

    recipeProvider.getDiscoverRecipes(
      query: query,
      token: token,
    );
  }

  void _onCancelSearch() {
    if (mounted) {
      setState(() {
        _searchController.clear();
        _searchQuery = '';
        _isSearchUIVisible = false;
      });
    }

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.isAuthenticated ? authProvider.token : null;

    // Reload discover recipes, potentially with the last active category or default
    recipeProvider.getDiscoverRecipes(
      category: _activeCategory,
      token: token,
    );
  }

  Future<void> _generateRecipeViaRecipeProvider() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a recipe name or ingredients to generate.')),
        );
      }
      return;
    }
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    if (recipeProvider.isLoading) return; // Prevent multiple generation attempts

    if (kDebugMode) debugPrint("Attempting to generate recipe for query (via RecipeProvider): $query");
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // The generateRecipe method in RecipeProvider now handles the subscription check and dialog
      final Recipe? generatedRecipe = await recipeProvider.generateRecipe(
        query,
        save: authProvider.token != null, // Save if logged in
        token: authProvider.token,
      );

      // Navigate only if a recipe was actually generated (not cancelled, no limit dialog shown)
      if (generatedRecipe != null && !recipeProvider.wasCancelled && recipeProvider.error == null && mounted && context.mounted) {
        if (kDebugMode) debugPrint("Recipe generation successful (via RecipeProvider), navigating...");
        Navigator.of(context).pushNamed('/recipe');
      } else if (recipeProvider.wasCancelled && mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe generation cancelled'), backgroundColor: Colors.orange),
        );
      }
      // If generatedRecipe is null due to limit dialog, no further action here as dialog handles it.
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating recipe (via RecipeProvider): ${e.toString()}');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating recipe: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRecipeGenerationViaRecipeProvider() async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    if (recipeProvider.isLoading && !recipeProvider.isCancelling) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancelling recipe generation...'), backgroundColor: Colors.blue, duration: Duration(seconds: 1)),
        );
      }
      try {
        await recipeProvider.cancelRecipeGeneration();
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe generation cancelled by user.'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error during cancellation (via RecipeProvider): $e');
        if (mounted && context.mounted) {
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
      'purpose': 'generateRecipe' // Or another purpose if this button's function changes
    });
  }

  void _viewRecipe(Recipe recipe) {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    recipeProvider.setCurrentRecipe(recipe);
    Navigator.of(context).pushNamed('/recipe');
  }

  void _viewCategory(String categoryId) {
    // This navigation seems to be for a dedicated category screen.
    // Ensure '/category/$categoryId' route exists and handles this.
    Navigator.of(context).pushNamed('/category/$categoryId');
  }

  Widget _buildSubscriptionBanner(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    // Use isProSubscriber from RevenueCat for the banner logic primarily
    final bool isPro = subscriptionProvider.isProSubscriber;
    final subscriptionInfo = subscriptionProvider.subscriptionInfo; // Backend info for limits

    if (isPro) { // User is Pro according to RevenueCat
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
    } else { // User is Free (or status unknown, defaulting to free view)
      Color color = Colors.green;
      String tierName = 'Free';
      String generationsText = 'Upgrade for more'; // Default text

      if (subscriptionInfo != null) { // If backend info is available
        generationsText = '${subscriptionInfo.recipeGenerationsRemaining}/${subscriptionInfo.recipeGenerationsLimit} recipes left';
      } else if (subscriptionProvider.isLoading) {
        generationsText = 'Loading status...';
      }


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
                    '$tierName Plan: $generationsText',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // Ensure "TestPro" is your Offering Identifier in RevenueCat
                RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro.identifier);
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

  Widget _buildTopBarWidget(BuildContext context, bool isSearchBarLoading) {
    final theme = Theme.of(context);
    if (!_isSearchUIVisible) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search Recipes',
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _isSearchUIVisible = true;
                  });
                }
              },
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: EnhancedSearchBar(
          controller: _searchController,
          onSubmitted: (query) {
            _onSearch(query);
          },
          onCancel: _onCancelSearch,
          isLoading: isSearchBarLoading, // Pass the loading state for the search bar
          hintText: 'Search recipes...',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context); // For UI updates
    final theme = Theme.of(context);

    final categories = recipeProvider.categories;
    final trendingRecipes = recipeProvider.trendingRecipes;
    final discoverRecipes = recipeProvider.discoverRecipes;

    final colorScheme = theme.colorScheme;

    // isLoading for the search bar should reflect recipeProvider.isLoading when a search is active
    final bool isSearchBarLoading = recipeProvider.isLoading && _searchQuery.isNotEmpty;
    final bool isLoadingMore = recipeProvider.isLoadingMore;

    final double navigationBarHeight = MediaQuery.of(context).padding.bottom;

    if (kDebugMode) {
      debugPrint("========================= HomeScreen BUILD - Subscription Status (RevenueCat) ================");
      debugPrint("isProSubscriber: ${subscriptionProvider.isProSubscriber}");
      if (subscriptionProvider.subscriptionInfo != null) {
        debugPrint("Backend Tier: ${subscriptionProvider.subscriptionInfo!.tier}");
        debugPrint("Backend Gens Remaining: ${subscriptionProvider.subscriptionInfo!.recipeGenerationsRemaining}");
      } else {
        debugPrint("Backend Tier: (No info)");
      }
      debugPrint("==========================================================================");
    }

   // getprofiles(); //call is now in _loadInitialData and _refreshData

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  if (authProvider.isAuthenticated) GreetingCard(),
                  const SizedBox(height: 20),
                  NewSearchBar(
                    hintText: 'What recipe are you looking for ?',
                    onSearch: (query) {
                      print('User is searching for: $query');
                    },
                  ),
                  const SizedBox(height: 20),
                  HomeCard(
                    onGenerateNow: () {
                      print('Generate Now button was tapped!');
                      //navigate to the chat screen with the query
                      _navigateToChatScreenWithQuery();
                    },
                  ),
                  if (authProvider.isAuthenticated && !subscriptionProvider.isProSubscriber)
                    _buildSubscriptionBanner(context),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_isLoadingCategories)
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 110,
                    child: _isLoadingCategories
                        ? _buildCategoriesLoadingList()
                        : _buildCategoriesList(categories, _activeCategory, colorScheme),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trending Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_isLoadingTrending)
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 220,
                    child: TrendingRecipes(
                      recipes: trendingRecipes,
                      onRecipeTap: _viewRecipe,
                      isLoading: _isLoadingTrending,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Search Results for "$_searchQuery"'
                              : (_activeCategory == null ? 'Discover Recipes' : _getCategoryTitle(_activeCategory!)),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_activeCategory != null && _searchQuery.isEmpty)
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
                  if (_isLoadingRecipes && discoverRecipes.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    )),
                  if (discoverRecipes.isEmpty && !_isLoadingRecipes)
                    _buildEmptyState(),
                  if (discoverRecipes.isNotEmpty)
                    RecipeGrid(
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
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(List<RecipeCategory> categories, String? activeCategory, ColorScheme colorScheme) {
    if (categories.isEmpty && !_isLoadingCategories) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No categories available'),
      ));
    }
    // Create a new list with "All" category prepended
    final allDisplayCategories = [
      RecipeCategory(id: 'all', name: 'All', description: 'All recipes', icon: Icons.apps, color: Colors.blueGrey[700]!), // Ensure color is not null
      ...categories,
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: allDisplayCategories.length,
      itemBuilder: (context, index) {
        final category = allDisplayCategories[index];
        // 'isActive' logic: if activeCategory is null, "All" is active. Otherwise, match ID.
        final isActive = (activeCategory == null && category.id == 'all') || (activeCategory == category.id);
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
                    color: isActive ? colorScheme.primary : Colors.white,
                    shape: BoxShape.rectangle,
                    border: Border.all(color: Colors.grey[200] ?? Colors.grey, width: 2),
                  ),
                  child: Icon(category.icon, color: isActive ? Colors.white : colorScheme.primary, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color:Colors.grey[800] ,
                  ),
                  overflow: TextOverflow.ellipsis,
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
      itemCount: 5, // Placeholder count
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
              const SizedBox(height: 8),
              Container(width: 50, height: 12, color: Colors.grey[300], margin: const EdgeInsets.only(top: 4)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message = 'No recipes found.';
    String subMessage = 'Try a different search or category. You can also start a new chat for recipe ideas using the "+" button in the navigation bar!';

    if (_searchQuery.isNotEmpty) {
      message = 'No recipes found for "$_searchQuery"';
      subMessage = 'Try a different search term or use the "Generate This Recipe" button below.';
    } else if (_activeCategory != null) {
      final categoryName = _getCategoryTitle(_activeCategory!);
      message = 'No recipes found in $categoryName.';
      subMessage = 'Explore other categories or start a new chat for recipe ideas using the "+" button in the navigation bar!';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateRecipeViaRecipeProvider, // This uses _searchController.text
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
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
    try {
      // Assuming RecipeCategories.getCategoryById is a static method or you have an instance
      final category = RecipeCategories.getCategoryById(categoryId);
      return category.name;
    } catch (e) {
      if (kDebugMode) debugPrint("Error getting category title for ID $categoryId: $e");
      return "Category"; // Fallback title
    }
  }
}