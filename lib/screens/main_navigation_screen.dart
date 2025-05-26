// lib/screens/main_navigation_screen.dart

import 'package:kitchenassistant/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <<< ADDED THIS IMPORT
import 'package:intl/intl.dart';       // <<< ADDED THIS IMPORT
import '../widgets/common/bottom_navigation.dart';
import 'home_screen_enhanced.dart';
import 'chat/chat_screen.dart';
// Ensure this path is correct for your project structure
import 'chat/conversation_list_host_screen.dart'; // Import for ConversationListHostScreen
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
  String? _currentlyDisplayedChatIdInTab;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreenEnhanced(),
      _buildInitialChatTabContent(),
      const RecipeListScreen(),
      const ProfileScreenEnhanced(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        Provider.of<ChatProvider>(context, listen: false).loadConversations();
      }
    });
  }

  Widget _buildInitialChatTabContent() {
    return _buildChatAuthPlaceholder();
  }

  Widget _buildChatAuthPlaceholder() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Please log in to access Chats', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
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

  void _showConversationList() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      setState(() {
        _screens[1] = _buildChatAuthPlaceholder();
        _currentlyDisplayedChatIdInTab = null;
      });
      return;
    }

    debugPrint("MainNavigationScreen: Showing ConversationListHostScreen.");
    Provider.of<ChatProvider>(context, listen: false).loadConversations();
    setState(() {
      _screens[1] = ConversationListHostScreen(
        key: const ValueKey("ConversationListHostScreen"),
        onConversationSelected: _openChatScreen,
        onStartNewChat: _startNewChatFromListScreen,
      );
      _currentlyDisplayedChatIdInTab = null;
    });
  }

  void _openChatScreen(String conversationId) {
    if (!mounted) return;
    debugPrint("MainNavigationScreen: Opening ChatScreen for $conversationId");
    setState(() {
      _currentlyDisplayedChatIdInTab = conversationId;
      _screens[1] = ChatScreen(
        key: ValueKey(conversationId),
        conversationId: conversationId,
      );
      _currentIndex = 1;
    });
  }

  void _startNewChatFromListScreen() {
    _navigateToNewChatScreenFromFab();
  }

  void _onTabTapped(int index) async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated && (index == 1 || index == 2 || index == 3)) {
      if (index == 1) {
        bool isAlreadyPlaceholder = false;
        if (_screens[1] is Scaffold) {
          final scaffoldBody = (_screens[1] as Scaffold).body;
          if (scaffoldBody is Center && scaffoldBody.child is Padding) {
            isAlreadyPlaceholder = true;
          }
        }
        if(!isAlreadyPlaceholder) {
          setState(() { _screens[1] = _buildChatAuthPlaceholder(); });
        }
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
      if (_screens[1] is ChatScreen && _currentlyDisplayedChatIdInTab != null) {
        // If already viewing a specific chat, tapping "Chats" again shows the list.
        _showConversationList();
      } else {
        // Otherwise (coming from another tab, or if list was already showing, or new FAB chat was just shown)
        // ensure the conversation list is shown.
        _showConversationList();
      }
    }
  }

  void _navigateToNewChatScreenFromFab() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start a new chat.')),
      );
      return;
    }
    debugPrint("MainNavigationScreen: FAB tapped, setting up for new ChatScreen.");
    setState(() {
      _currentlyDisplayedChatIdInTab = null;
      _screens[1] = ChatScreen(
        key: UniqueKey(),
        conversationId: null,
        purpose: 'newChatFromFab',
      );
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("MainNavigationScreen: Building. CurrentIndex: $_currentIndex. DisplayedChatId: $_currentlyDisplayedChatIdInTab. ScreenType[1]: ${_screens[1].runtimeType}");

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