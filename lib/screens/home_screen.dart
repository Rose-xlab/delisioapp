// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/subscription_provider.dart'; // Import subscription provider
import '../../models/subscription.dart'; // Import subscription model

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false; // For the generate recipe button state
  bool _isGenerating = false; // Track recipe generation state

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid calling provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only load if mounted and context is available
      if (mounted) {
        _loadUserData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        // Load recipes
        await Provider.of<RecipeProvider>(context, listen: false)
            .getUserRecipes(authProvider.token!);

        // Load subscription status
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(authProvider.token!);

        print("User data and subscription info loaded or updated.");
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load your data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) { // Ensure widget is still mounted before calling setState
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Build the usage indicator widget based on subscription info
  Widget _buildUsageIndicator(SubscriptionInfo subscriptionInfo) {
    // MODIFIED: Updated for Pro and Free tiers
    if (subscriptionInfo.tier == SubscriptionTier.pro) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.1), // Color for Pro
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepPurple), // Color for Pro
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.all_inclusive, // Icon for unlimited
              color: Colors.deepPurple, // Color for Pro
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'Unlimited Recipes (Pro)', // Text for Pro
              style: TextStyle(
                color: Colors.deepPurple, // Color for Pro
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      // Free plan (as basic is removed and default is free)
      Color color = Colors.green; // Color for Free

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(
              Icons.restaurant_menu,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              '${subscriptionInfo.recipeGenerationsRemaining}/${subscriptionInfo.recipeGenerationsLimit} recipes left',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/subscription'),
              child: Text(
                'Upgrade to Pro', // Updated text
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _generateRecipe() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter a recipe name or ingredients')),
        );
      }
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // If we're already loading, don't start another generation
    if (recipeProvider.isLoading) return;

    // Check if queue is active before starting
    await recipeProvider.checkQueueStatus();

    if (mounted) { // Ensure widget is still mounted
      setState(() {
        _isGenerating = true;
        _isLoading = true;
      });
    }


    try {
      // If authenticated, save to user's recipes
      final bool shouldSave = authProvider.isAuthenticated;

      // Start recipe generation with the appropriate save option
      await recipeProvider.generateRecipe(
        query,
        save: shouldSave,
        token: authProvider.token,
      );

      // Only navigate if generation was successful and not cancelled
      if (!recipeProvider.wasCancelled && recipeProvider.error == null &&
          mounted) {
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
          SnackBar(content: Text('Error generating recipe: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _isLoading = false;
        });
      }
    }
  }

  // Improved: Cancel recipe generation with better feedback
  Future<void> _cancelRecipeGeneration() async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    if (recipeProvider.isLoading && !recipeProvider.isCancelling) {
      // Show cancellation in progress
      if (mounted) { // Ensure widget is still mounted
        setState(() => _isLoading = true);
      }


      // Display cancellation feedback
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancelling recipe generation...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1), // Short duration for "in progress"
          ),
        );
      }


      // Call the cancellation method WITH await
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
      // isLoading state will be reset in _generateRecipe's finally block or when recipeProvider.isLoading changes via Provider
    }
  }

  // --- MODIFIED: Navigate to Chat List Screen ---
  void _openChatList() {
    print("Navigating to /chatList");
    Navigator.of(context).pushNamed('/chatList');
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final userRecipes = recipeProvider.userRecipes;
    final bool isGenerating = recipeProvider.isLoading; // Use provider's isLoading
    final bool isCancelling = recipeProvider.isCancelling;
    final double progress = recipeProvider.generationProgress;
    final partialRecipe = recipeProvider.partialRecipe;
    final subscriptionInfo = subscriptionProvider.subscriptionInfo;

    print("Building HomeScreen. Logged in: ${authProvider.token != null}");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking Assistant'),
        // Removed sign out button - it's now in the profile tab
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
                  'Welcome${authProvider.user?.name != null ? ', ${authProvider
                      .user!.name}' : ''}!',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'What would you like to cook today?',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),

                // Show subscription status indicator if logged in and info available
                if (authProvider.isAuthenticated && subscriptionInfo != null) ...[
                  const SizedBox(height: 12),
                  _buildUsageIndicator(subscriptionInfo),
                ],

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
                        onSubmitted: (_) =>
                        isGenerating // Use provider's isLoading
                            ? null
                            : _generateRecipe(),
                        enabled: !isGenerating, // Disable text field while generating
                      ),
                    ),
                    const SizedBox(width: 8),
                    // IMPROVED: Better UI for cancellation button with clearer states
                    isGenerating // Use provider's isLoading
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cancel button shown during generation
                        SizedBox(
                          width: 56, height: 56,
                          child: ElevatedButton(
                            onPressed: isCancelling
                                ? null
                                : _cancelRecipeGeneration,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              shape: const CircleBorder(),
                              backgroundColor: Colors.red[400],
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: isCancelling
                                ? const SizedBox(width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.close, size: 24),
                          ),
                        ),
                        // Generation indicator adjacent to cancel button
                        const SizedBox(width: 8),
                        SizedBox( // This acts as a visual cue that something is happening
                          width: 56, height: 56,
                          child: Center(
                            child: SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Theme
                                    .of(context)
                                    .primaryColor),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        : SizedBox( // Generate Button
                      width: 56, height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _generateRecipe, // Uses local _isLoading for generate button enable/disable
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: const CircleBorder(),
                          disabledForegroundColor: Colors.white54,
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: _isLoading // Uses local _isLoading for button's progress indicator
                            ? const SizedBox(
                            width: 24, height: 24, child: Center(
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)))
                            : const Icon(Icons.search, size: 24),
                      ),
                    ),
                  ],
                ),

                // Progress indicator for recipe generation
                if (isGenerating && recipeProvider.isQueueActive) // Use provider's isLoading
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Theme
                            .of(context)
                            .primaryColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}% complete',
                        style: TextStyle(color: Theme
                            .of(context)
                            .primaryColor),
                      ),
                      if (partialRecipe != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Generating "${partialRecipe.title}"...',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
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
                    child: Text('Your Saved Recipes', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  if (recipeProvider.isLoading && userRecipes.isEmpty && // Use provider's isLoading
                      partialRecipe == null)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else
                    if (userRecipes.isEmpty && !isGenerating) // Use provider's isLoading
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                                'No recipes saved yet...', textAlign: TextAlign
                                .center, style: TextStyle(
                                color: Colors.grey[600], fontSize: 16)),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          itemCount: userRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = userRecipes[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 8),
                              child: ListTile(
                                title: Text(recipe.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text('${recipe.ingredients
                                    .length} ingredients • ${recipe.steps
                                    .length} steps', maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  // ... (Existing onTap logic) ...
                                  print("Tapped on recipe: ${recipe.title}");
                                  try {
                                    if (!mounted) return;
                                    await Provider.of<RecipeProvider>(
                                        context, listen: false).getRecipeById(
                                        recipe.id!, authProvider.token!);
                                    print(
                                        "Recipe details fetched, navigating...");
                                    if (mounted) {
                                      Navigator
                                          .of(context)
                                          .pushNamed('/recipe');
                                    }
                                  } catch (e) {
                                    print("Error loading recipe details: $e");
                                    if (mounted) {
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(SnackBar(content: Text(
                                          'Could not load recipe details: ${e
                                              .toString()}')));
                                    }
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
                      Icon(Icons.lock_outline, size: 50,
                          color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("Sign in to save your recipes!", style: Theme
                          .of(context)
                          .textTheme
                          .titleMedium),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pushReplacementNamed(
                                '/login'),
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