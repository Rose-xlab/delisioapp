// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import '../widgets/common/bottom_navigation.dart';
import 'home_screen.dart';
import 'chat/chat_screen.dart'; // We still need this for direct chat opening
import 'recipes/recipe_list_screen.dart';
import 'profile/profile_screen.dart';
import '../providers/chat_provider.dart'; // For starting a new chat
import 'package:provider/provider.dart'; // For Provider.of

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  String? _chatId; // Store active chat ID

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

      // Initialize the screens list
      _screens = [
        const HomeScreen(),
        _buildChatPlaceholder(), // Placeholder that will trigger chat creation
        const RecipeListScreen(),
        const ProfileScreen(),
      ];
      setState(() {}); // Refresh with initial screens
    } catch (e) {
      print("Error initializing screens: $e");
    }
  }

  // This placeholder widget handles creating a new chat when the Chat tab is selected
  Widget _buildChatPlaceholder() {
    return Builder(
      builder: (context) {
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
      print("Error initializing chat tab: $e");
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
      if (_chatId == null) {
        await _initializeChatTab();
      }
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Building MainNavigationScreen, index: $_currentIndex");

    // If we're showing the chat tab for the first time, initialize it
    if (_currentIndex == 1 && _chatId == null) {
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
        onTap: _onTabTapped,
      ),
    );
  }
}