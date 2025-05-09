// lib/screens/main_navigation_screen.dart
import 'package:kitchenassistant/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import '../widgets/common/bottom_navigation.dart';
import 'home_screen_enhanced.dart'; // Use new enhanced home screen
import 'chat/chat_screen.dart';
import 'recipes/recipe_list_screen.dart';
import 'profile/profile_screen_enhanced.dart'; // Use enhanced profile screen
import '../providers/chat_provider.dart';
import 'package:provider/provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  String? _chatId; // Store active chat ID
  final bool _creatingConversation = false;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
  }

  Future<void> _initializeScreens() async {
    // Create initial chat on app start (if needed)
    try {
      // This will be called when the Chat tab is selected the first time
      _chatId = null;

      // Initialize the screens list with the new HomeScreenEnhanced
      _screens = [
        const HomeScreenEnhanced(), // Use the enhanced home screen
        _buildChatPlaceholder(), // Placeholder that will trigger chat creation
        const RecipeListScreen(),
        const ProfileScreenEnhanced(), // Use enhanced profile screen
      ];
      setState(() {}); // Refresh with initial screens
    } catch (e) {
      debugPrint("Error initializing screens: $e");
    }
  }

  // This placeholder widget handles creating a new chat when the Chat tab is selected
  Widget _buildChatPlaceholder() {
    return Builder(
      builder: (context) {

         final authProvider = Provider.of<AuthProvider>(context);

            // User object from AuthProvider
         final user = authProvider.user;

         //////////////////////////////////////////////
         if (!authProvider.isAuthenticated || user == null) { // Also check if user object is null
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(
          child: Padding(
            
            padding: const EdgeInsets.all(15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Please log in to Chat with AI'),
                const SizedBox(height: 16),
                ElevatedButton(
                  // Use pushReplacementNamed for login to replace the current screen
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                  child: const Text('Login / Sign Up'), // More inviting text
                ),
              ],
            ),
          ),
        ),
      );
    }












         //////////////////////////////////////////////////////
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

  // Start a new chat if needed or navigate to existing chat
  Future<void> _initializeChatTab() async {
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Show loading first
      setState(() {
        _screens[1] = _buildChatPlaceholder();
      });

      // If we don't have a chat ID or the current one is invalid, create a new one
      if (_chatId == null) {
        // Try to load existing conversations first
        await chatProvider.loadConversations();

        String? conversationId;

        // If there are existing conversations, use the most recent one
        if (chatProvider.conversations.isNotEmpty) {
          conversationId = chatProvider.conversations.first.id;
        } else {
          // Otherwise create a new conversation
          conversationId = await chatProvider.createNewConversation();
        }

        if (conversationId != null) {
          _chatId = conversationId;
        } else {
          // Handle error - couldn't get a valid chat ID
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not initialize chat. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Update the chat screen with the valid chat ID
      if (mounted && _chatId != null) {
        setState(() {
          _screens[1] = ChatScreen(conversationId: _chatId!);
        });
      }
    } catch (e) {
      debugPrint("Error initializing chat tab: $e");
      if (mounted) {
        // Show error state in the chat tab
        setState(() {
          _screens[1] = Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text("Could not load chat", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(e.toString(), style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeChatTab,
                  child: const Text("Try Again"),
                ),
              ],
            ),
          );
        });
      }
    }
  }

  // Tab change handler
  void _onTabTapped(int index) async {
    if (index == 1) {
      // If switching to Chat tab, ensure chat is initialized
      if (_chatId == null ) {
        await _initializeChatTab();
      }
    }

    setState(() {
      _currentIndex = index;
    });
  }

  dynamic _unAuthTapped(int index) {

        if (index == 1) {
      // If switching to Chat tab, ensure chat is initialized
      if (_chatId == null ) {
        // await _initializeChatTab();
      }
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {

    debugPrint("Building MainNavigationScreen, index: $_currentIndex");
    final authProvider = Provider.of<AuthProvider>(context);

    // If we're showing the chat tab for the first time, initialize it
    if (_currentIndex == 1 && _chatId == null && authProvider.isAuthenticated) {
      _initializeChatTab();
    }

    return Scaffold(
      // Use IndexedStack to keep the state of each screen when switching tabs
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Your custom bottom navigation bar widget
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap:authProvider.isAuthenticated ? _onTabTapped : _unAuthTapped,
      ),
    );
  }
}