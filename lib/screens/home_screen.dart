// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRecipes() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    try {
      await Provider.of<RecipeProvider>(context, listen: false)
          .getUserRecipes(authProvider.token!);
    } catch (e) {
      // Handle error if needed
    }
  }

  Future<void> _generateRecipe() async {
    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a recipe to search for'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await Provider.of<RecipeProvider>(context, listen: false).generateRecipe(
        _searchController.text.trim(),
        save: authProvider.token != null, // Save if logged in
        token: authProvider.token,
      );

      // Navigate to recipe detail screen
      Navigator.of(context).pushNamed('/recipe');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating recipe: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openChat() {
    Navigator.of(context).pushNamed('/chat');
  }

  void _signOut() async {
    await Provider.of<AuthProvider>(context, listen: false).signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userRecipes = recipeProvider.userRecipes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome${authProvider.user != null ? ', ${authProvider.user!.name}' : ''}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'What would you like to cook today?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for a recipe...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _generateRecipe(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _generateRecipe,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: const CircleBorder(),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat with Cooking Assistant'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Recent Recipes Section (if logged in)
          if (authProvider.token != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Your Recent Recipes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (recipeProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (userRecipes.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No recipes yet. Try searching for a recipe or chat with the assistant!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: userRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = userRecipes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            child: ListTile(
                              title: Text(
                                recipe.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${recipe.ingredients.length} ingredients • ${recipe.steps.length} steps',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Provider.of<RecipeProvider>(context,
                                    listen: false)
                                    .getRecipeById(
                                    recipe.id!, authProvider.token!);
                                Navigator.of(context).pushNamed('/recipe');
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}