// screens/recipes/recipe_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../models/recipe.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({Key? key}) : super(key: key);

  @override
  _RecipeListScreenState createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // Default filter
  final List<String> _filterOptions = ['All', 'Quick (<30min)', 'Favorites', 'Recently Added'];

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid setState during build error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        // Load both user recipes and favorites
        await Provider.of<RecipeProvider>(context, listen: false)
            .getUserRecipes(authProvider.token!);
        await Provider.of<RecipeProvider>(context, listen: false)
            .getFavoriteRecipes(authProvider.token!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading recipes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Recipe> _getFilteredRecipes(List<Recipe> recipes) {
    // First apply search filter
    List<Recipe> filteredRecipes = recipes.where((recipe) {
      final title = recipe.title.toLowerCase();
      final query = _searchQuery.toLowerCase();
      final ingredients = recipe.ingredients.join(' ').toLowerCase();

      return title.contains(query) || ingredients.contains(query);
    }).toList();

    // Then apply category filter
    switch (_selectedFilter) {
      case 'Quick (<30min)':
        return filteredRecipes.where((recipe) =>
        recipe.totalTimeMinutes != null && recipe.totalTimeMinutes! < 30
        ).toList();
      case 'Favorites':
        return filteredRecipes.where((recipe) => recipe.isFavorite).toList();
      case 'Recently Added':
      // Sort by creation date (most recent first) and take first 10
        filteredRecipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return filteredRecipes.take(10).toList();
      case 'All':
      default:
        return filteredRecipes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final recipes = recipeProvider.userRecipes;
    final filteredRecipes = _getFilteredRecipes(recipes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecipes,
            tooltip: 'Refresh recipes',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          _buildSearchAndFilterBar(context),

          // Results count
          if (!_isLoading && recipes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Found ${filteredRecipes.length} recipe${filteredRecipes.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Recipe grid or empty state
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : recipes.isEmpty
                ? _buildEmptyState()
                : filteredRecipes.isEmpty
                ? _buildNoResultsState()
                : _buildRecipeGrid(filteredRecipes, context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by recipe name or ingredient...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300]!,
                      ),
                    ),
                  ),
                );
              }).toList(),
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
          Image.asset(
            'assets/empty_recipes.png',
            width: 150,
            height: 150,
            errorBuilder: (ctx, error, _) => Icon(
              Icons.no_food,
              size: 150,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No recipes saved yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your saved recipes will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
            icon: const Icon(Icons.search),
            label: const Text('Find Recipes'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No matching recipes found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term or filter',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedFilter = 'All';
              });
            },
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeGrid(List<Recipe> recipes, BuildContext context) {

    double screenWidth = MediaQuery.sizeOf(context).width;

    return RefreshIndicator(
      onRefresh: _loadRecipes,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: screenWidth > 600 ? 4 : 2, // Two recipes per row
          childAspectRatio: 0.75, // Card aspect ratio (width/height)
          crossAxisSpacing: 16, // Horizontal space between items
          mainAxisSpacing: 16, // Vertical space between items
        ),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return RecipeCard(
            recipe: recipe,
            onTap: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              if (recipe.id != null && authProvider.token != null) {
                await Provider.of<RecipeProvider>(context, listen: false)
                    .getRecipeById(recipe.id!, authProvider.token!);
                if (context.mounted) {
                  Navigator.of(context).pushNamed('/recipe');
                }
              }
            },
          );
        },
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({
    Key? key,
    required this.recipe,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the first step image URL to use as a recipe thumbnail, if available
    String? imageUrl;
    if (recipe.steps.isNotEmpty && recipe.steps[0].imageUrl != null) {
      imageUrl = recipe.steps[0].imageUrl;
    }

    return Card(
      clipBehavior: Clip.antiAlias, // For clean rounded corners on the image
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
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.25, // Image takes up most of the card
                  child: imageUrl != null
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
              ],
            ),

            // Recipe info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
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
}