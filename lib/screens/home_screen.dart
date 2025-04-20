// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/chat_provider.dart'; // Import ChatProvider to potentially start new chat

// Ensure Recipe model is imported if used directly (it's used by RecipeProvider)
// import '../models/recipe.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false; // For the generate recipe button state

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid calling provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only load if mounted and context is available
      if(mounted) {
        _loadUserRecipes();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRecipes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        await Provider.of<RecipeProvider>(context, listen: false)
            .getUserRecipes(authProvider.token!);
        print("User recipes loaded or updated.");
      }
    } catch (e) {
      print('Error loading recipes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load your recipes: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

    if (mounted) setState(() => _isLoading = true);
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
        print("Recipe generation successful (likely), navigating...");
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Added: Cancel recipe generation
  void _cancelRecipeGeneration() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    if (recipeProvider.isLoading) {
      recipeProvider.cancelRecipeGeneration();
      // Show cancelling state in UI, the provider will update when cancellation is complete
      setState(() => _isLoading = true);
    }
  }

  // --- MODIFIED: Navigate to Chat List Screen ---
  void _openChatList() {
    print("Navigating to /chatList");
    Navigator.of(context).pushNamed('/chatList');
  }

  // --- Optional: Start New Chat Directly ---
  // void _startNewChatDirectly() async {
  //    print("Starting new chat directly...");
  //    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
  //    // Show loading indicator maybe?
  //    final newConversationId = await chatProvider.createNewConversation();
  //    if (newConversationId != null && mounted) {
  //       Navigator.of(context).pushNamed('/chat', arguments: newConversationId);
  //    } else if (mounted) {
  //        ScaffoldMessenger.of(context).showSnackBar(
  //          const SnackBar(content: Text('Could not start new chat.'), backgroundColor: Colors.red)
  //        );
  //    }
  // }

  void _signOut() async {
    // ... (sign out logic remains the same) ...
    print("Signing out...");
    if(!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.signOut();
      print("Sign out successful, navigating to login.");
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print("Error signing out: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: ${e.toString()}'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userRecipes = recipeProvider.userRecipes;
    final bool isGenerating = recipeProvider.isLoading;
    final bool isCancelling = recipeProvider.isCancelling;

    print("Building HomeScreen. Logged in: ${authProvider.token != null}");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking Assistant'),
        actions: [
          if (authProvider.token != null)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Sign Out',
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
                // ... (Welcome Text, Instruction Text remain the same) ...
                Text(
                  'Welcome${authProvider.user?.name != null ? ', ${authProvider.user!.name}' : ''}!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'What would you like to cook today?',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  // ... (TextField and Search Icon Button remain the same) ...
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for ingredients or dish...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => isGenerating ? null : _generateRecipe(),
                        enabled: !isGenerating, // Disable text field while generating
                      ),
                    ),
                    const SizedBox(width: 8),
                    // MODIFIED: Add conditional rendering for generate/cancel buttons
                    isGenerating
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cancel button shown during generation
                        SizedBox(
                          width: 56, height: 56,
                          child: ElevatedButton(
                            onPressed: isCancelling ? null : _cancelRecipeGeneration,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              shape: const CircleBorder(),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero,
                              backgroundColor: Colors.red[400],
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: isCancelling
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.close, size: 24),
                          ),
                        ),
                        // Generation indicator adjacent to cancel button
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 56, height: 56,
                          child: Center(
                            child: SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        : SizedBox(
                      width: 56, height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _generateRecipe,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: const CircleBorder(),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                          disabledForegroundColor: Colors.white54,
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                            : const Icon(Icons.search, size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // --- MODIFIED: Chat Button Navigates to List ---
                ElevatedButton.icon(
                  onPressed: _openChatList, // Changed target function
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('View Chats / Ask Ideas'), // Updated text
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                // --- End of Modification ---
              ],
            ),
          ),

          // Recent Recipes Section (remains the same logic)
          if (authProvider.token != null)
            Expanded(
              child: Column(
                // ... (Existing recipe list logic) ...
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('Your Saved Recipes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  if (recipeProvider.isLoading && userRecipes.isEmpty)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (userRecipes.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text( 'No recipes saved yet...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        itemCount: userRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = userRecipes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: ListTile(
                              title: Text( recipe.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${recipe.ingredients.length} ingredients • ${recipe.steps.length} steps', maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                // ... (Existing onTap logic) ...
                                print("Tapped on recipe: ${recipe.title}");
                                try {
                                  if (!mounted) return;
                                  await Provider.of<RecipeProvider>(context, listen: false).getRecipeById(recipe.id!, authProvider.token!);
                                  print("Recipe details fetched, navigating...");
                                  if(mounted) Navigator.of(context).pushNamed('/recipe');
                                } catch(e) {
                                  print("Error loading recipe details: $e");
                                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load recipe details: ${e.toString()}')));
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          // Login/Signup Prompt (remains the same)
          if (authProvider.token == null)
            Expanded(
              child: Padding(
                // ... (Existing login prompt) ...
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 50, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("Sign in to save your recipes!", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                        child: const Text("Sign In / Sign Up"),
                      )
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}