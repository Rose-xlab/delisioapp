import 'package:kitchenassistant/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import '../widgets/common/bottom_navigation.dart'; // Your custom bottom navigation
import 'home_screen_enhanced.dart';
import 'chat/chat_screen.dart';
import 'recipes/recipe_list_screen.dart';
import 'profile/profile_screen_enhanced.dart';
import '../providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  String? _chatId; // Stores the ID of the currently active/last viewed chat in the tab

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreenEnhanced(),
      _buildChatPlaceholder(), // Initial placeholder for chat
      const RecipeListScreen(),
      const ProfileScreenEnhanced(),
    ];
  }

  Widget _buildChatPlaceholder() {
    return Builder(
      builder: (context) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        // final user = authProvider.user; // user variable not used

        if (!authProvider.isAuthenticated) {
          return Scaffold(
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
        // If authenticated, but chat not yet initialized by a tap
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Initializing chat..."), // This matches the structure we check for
            ],
          ),
        );
      },
    );
  }

  Future<void> _initializeChatTab({String? newChatPurpose}) async {
    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        if (mounted) {
          setState(() {
            _screens[1] = _buildChatPlaceholder();
          });
        }
        return;
      }

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      if (newChatPurpose == 'newChatFromFab') {
        if (mounted) {
          debugPrint("MainNavigationScreen (FAB): Initializing a new ChatScreen instance.");
          _chatId = null;

          setState(() {
            _screens[1] = ChatScreen(
              key: UniqueKey(),
              conversationId: null,
              purpose: newChatPurpose,
            );
            _currentIndex = 1;
          });
        }
        return;
      }

      // Safer check for existing loading indicator
      bool alreadyLoading = false;
      if (_screens[1] is Center) {
        final centerWidget = _screens[1] as Center;
        if (centerWidget.child is Column) {
          final columnWidget = centerWidget.child as Column;
          if (columnWidget.children.isNotEmpty && columnWidget.children.first is CircularProgressIndicator) {
            alreadyLoading = true;
          }
        }
      }

      if (mounted && _screens[1] is! ChatScreen && !alreadyLoading) {
        setState(() {
          _screens[1] = const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [CircularProgressIndicator(), SizedBox(height:10), Text("Loading chat...")],
          ));
        });
      }

      String? conversationIdToUse = _chatId;

      if (conversationIdToUse == null) {
        debugPrint("MainNavigationScreen (TabTap): No active _chatId. Loading existing or creating new.");
        if (chatProvider.conversations.isEmpty && !chatProvider.isLoadingConversations) {
          await chatProvider.loadConversations();
        }

        if (chatProvider.conversations.isNotEmpty) {
          conversationIdToUse = chatProvider.conversations.first.id;
        } else {
          conversationIdToUse = await chatProvider.createNewConversation();
        }
      }

      if (conversationIdToUse != null) {
        _chatId = conversationIdToUse;
        if (mounted) {
          bool needsScreenUpdate = true;
          if (_screens[1] is ChatScreen) {
            final currentChatScreen = _screens[1] as ChatScreen;
            // Check key and conversationId to avoid unnecessary rebuilds
            if (currentChatScreen.key == ValueKey(_chatId) && currentChatScreen.conversationId == _chatId) {
              needsScreenUpdate = false;
            }
          }

          if (needsScreenUpdate) {
            debugPrint("MainNavigationScreen (TabTap): Setting/Updating ChatScreen for conversationId: $_chatId");
            setState(() {
              _screens[1] = ChatScreen(conversationId: _chatId!, key: ValueKey(_chatId));
            });
          } else {
            debugPrint("MainNavigationScreen (TabTap): ChatScreen for $_chatId already displayed and keyed correctly.");
          }
        }
      } else {
        throw Exception('MainNavigationScreen: Could not initialize or establish a chat session.');
      }
    } catch (e) {
      debugPrint("MainNavigationScreen: Error initializing chat tab: $e");
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
                  Text(e.toString().length > 100 ? "${e.toString().substring(0,100)}..." : e.toString(), style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _initializeChatTab(newChatPurpose: newChatPurpose),
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
      bool isChatPlaceholderLogin = false;
      if (_screens[1] is Scaffold) {
        final scaffoldBody = (_screens[1] as Scaffold).body;
        if (scaffoldBody is Center && scaffoldBody.child is Padding) {
          isChatPlaceholderLogin = true; // Heuristic for your login prompt placeholder
        }
      }
      if (index == 1 && !isChatPlaceholderLogin) {
        setState(() { _screens[1] = _buildChatPlaceholder(); });
      }
      setState(() { _currentIndex = index; });
      return;
    }

    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }

    if (index == 1) {
      await _initializeChatTab();
      // Ensure _currentIndex is still 1 after await, in case of rapid taps
      if (mounted && _currentIndex != 1) {
        setState(() { _currentIndex = 1; });
      }
    }
  }

  void _navigateToNewChatScreenFromFab() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start a new chat.')),
      );
      return;
    }
    debugPrint("MainNavigationScreen: FAB tapped, initiating new chat flow via _initializeChatTab.");
    _initializeChatTab(newChatPurpose: 'newChatFromFab');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("MainNavigationScreen: Building MainNavigationScreen, index: $_currentIndex, _chatId: $_chatId");

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        onFabPressed: _navigateToNewChatScreenFromFab,
      ),
    );
  }
}