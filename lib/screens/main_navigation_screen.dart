// lib/screens/main_navigation_screen.dart
import 'package:kitchenassistant/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import '../widgets/common/bottom_navigation.dart'; // Your custom bottom navigation
import 'home_screen_enhanced.dart';
import 'chat/chat_screen.dart';
import 'recipes/recipe_list_screen.dart';
import 'profile/profile_screen_enhanced.dart';
import '../providers/chat_provider.dart';
import 'package:provider/provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens; // Made non-final to allow update in initState
  String? _chatId;
  // final bool _creatingConversation = false; // This seemed unused

  @override
  void initState() {
    super.initState();
    // Initialize with placeholders or loading states if necessary
    _screens = [
      const HomeScreenEnhanced(),
      _buildChatPlaceholder(), // Initial placeholder for chat
      const RecipeListScreen(),
      const ProfileScreenEnhanced(),
    ];
    // No need to call _initializeScreens separately if it's synchronous like this
    // _initializeScreens(); // If _initializeScreens were async, you'd handle its future
  }

  // This method is no longer async as screen initialization is direct
  // void _initializeScreens() {
  //   _chatId = null; // Reset chat ID
  //   _screens = [
  //     const HomeScreenEnhanced(),
  //     _buildChatPlaceholder(),
  //     const RecipeListScreen(),
  //     const ProfileScreenEnhanced(),
  //   ];
  //   // No setState needed here if called from initState before first build
  // }

  Widget _buildChatPlaceholder() {
    return Builder(
      builder: (context) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false); // listen:false if not rebuilding on auth change here
        final user = authProvider.user;

        if (!authProvider.isAuthenticated || user == null) {
          return Scaffold(
            // appBar: AppBar(title: const Text('Chat')), // Optional: keep or remove app bar
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Please log in to Chat with AI', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Login / Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // If authenticated, show loading indicator while chat initializes via _initializeChatTab
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Opening chat..."),
            ],
          ),
        );
      },
    );
  }

  Future<void> _initializeChatTab({String? newChatPurpose}) async {
    // newChatPurpose is for when the FAB is clicked, to signal a new chat directly.
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        // This case should be handled by _buildChatPlaceholder, but as a safeguard:
        if (mounted) {
          setState(() {
            _screens[1] = _buildChatPlaceholder(); // Show login prompt
          });
        }
        return;
      }

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Show loading indicator in the chat tab position
      if (mounted && _screens[1] is! ChatScreen) { // Avoid unnecessary rebuild if already ChatScreen
        setState(() {
          _screens[1] = const Center(child: CircularProgressIndicator());
        });
      }

      String? conversationIdToUse = _chatId;

      if (newChatPurpose == 'newChatFromFab') {
        // User clicked the "+", explicitly wants a new chat.
        // We don't set _chatId here, ChatScreen will handle creation with this purpose.
        if (mounted) {
          setState(() {
            _screens[1] = ChatScreen(
              conversationId: null, // Signal ChatScreen to create new
              key: UniqueKey(), // Ensure ChatScreen rebuilds for new chat
              purpose: newChatPurpose,
            );
            _currentIndex = 1; // Switch to chat tab
          });
        }
        return;
      }


      // Standard tab selection logic: load existing or create if none
      if (conversationIdToUse == null) {
        await chatProvider.loadConversations();
        if (chatProvider.conversations.isNotEmpty) {
          conversationIdToUse = chatProvider.conversations.first.id;
        } else {
          conversationIdToUse = await chatProvider.createNewConversation();
        }
      }

      if (conversationIdToUse != null) {
        _chatId = conversationIdToUse; // Store the active/selected chat ID
        if (mounted) {
          setState(() {
            // Use a Key to ensure ChatScreen rebuilds if conversationId changes
            _screens[1] = ChatScreen(conversationId: _chatId!, key: ValueKey(_chatId));
          });
        }
      } else {
        throw Exception('Could not initialize or create a chat session.');
      }
    } catch (e) {
      debugPrint("Error initializing chat tab: $e");
      if (mounted) {
        setState(() {
          _screens[1] = Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text("Could not load chat", style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(e.toString(), style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _initializeChatTab(), // Retry initialization
                    child: const Text("Try Again"),
                  ),
                ],
              ),
            ),
          );
        });
      }
    }
  }

  void _onTabTapped(int index) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated && (index == 1 || index == 2 || index == 3)) {
      // For chat, recipes, profile - if not authenticated, show placeholder or login prompt.
      // The _buildChatPlaceholder already handles the login prompt for the chat tab.
      // For other tabs, you might want similar behavior or just prevent navigation.
      if (index == 1 && _screens[1] is! ChatScreen) { // Ensure chat placeholder is shown
        setState(() {
          _screens[1] = _buildChatPlaceholder();
          _currentIndex = index;
        });
      } else {
        setState(() {
          _currentIndex = index; // Allow navigation to other placeholders if any
        });
      }
      // Potentially show a snackbar or dialog for other protected tabs if not using placeholders
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Please log in to access this section.')),
      // );
      return;
    }


    if (index == 1) { // Chat tab
      // If chat screen is not already loaded or is just a placeholder, initialize it.
      // Check if _screens[1] is already a ChatScreen instance to avoid re-init.
      if (_screens[1] is! ChatScreen || _chatId == null) {
        await _initializeChatTab(); // This will set _screens[1] and _chatId
      }
    }

    // Set current index after async operations if any
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // This is the new method for the central "+" button
  void _navigateToNewChatScreenFromFab() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      // If user is not authenticated, redirect to login
      Navigator.of(context).pushReplacementNamed('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start a new chat.')),
      );
      return;
    }

    // User is authenticated, navigate to ChatScreen with arguments to create a new chat.
    // The ChatScreen itself will handle the creation logic based on these arguments.
    // We also switch to the chat tab.
    debugPrint("FAB tapped: Navigating to new chat.");

    // Option 1: Directly replace the chat screen content and switch tab
    // This is more aligned with how _initializeChatTab works for the FAB purpose
    _initializeChatTab(newChatPurpose: 'newChatFromFab');


    // Option 2: Navigate using pushNamed (if ChatScreen is set up for this route directly)
    // Navigator.of(context).pushNamed('/chat', arguments: {
    //   'initialQuery': null,
    //   'purpose': 'newChatFromHomeFab', // Or a more specific purpose like 'newChatFromBottomNav'
    //   'conversationId': null // Explicitly null to indicate new
    // }).then((_) {
    //   // After chat screen is popped (if it's a separate route),
    //   // you might want to refresh the chat list or current chat tab.
    //   // If ChatScreen is part of IndexedStack, this .then() might not be directly useful here.
    //   // Consider switching to the chat tab if not already on it.
    //   if (_currentIndex != 1) {
    //     _onTabTapped(1);
    //   } else {
    //     // If already on chat tab, might need to refresh its content if a new chat was created
    //     // This depends on how ChatScreen handles new chat creation via arguments.
    //     _initializeChatTab();
    //   }
    // });
  }


  @override
  Widget build(BuildContext context) {
    debugPrint("Building MainNavigationScreen, index: $_currentIndex, chatID: $_chatId");
    final authProvider = Provider.of<AuthProvider>(context); // Can listen here for overall auth state

    // Initialize chat tab if it's selected, user is authenticated, and chat isn't already loaded
    // This condition might need refinement based on when _initializeChatTab should run.
    // It's primarily handled by _onTabTapped now.
    // if (_currentIndex == 1 && authProvider.isAuthenticated && _screens[1] is! ChatScreen) {
    //   // Use a post-frame callback to avoid calling setState during build
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (mounted && _screens[1] is! ChatScreen) { // Double check condition
    //       _initializeChatTab();
    //     }
    //   });
    // }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onTabTapped, // For the actual tabs
        onFabPressed: _navigateToNewChatScreenFromFab, // For the central "+" button
      ),
    );
  }
}
