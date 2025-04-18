// screens/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_message.dart';
import '../../widgets/chat/chat_bubble.dart';
import '../../widgets/chat/message_input.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      await Provider.of<ChatProvider>(context, listen: false).sendMessage(message);
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  void _generateRecipe() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final recipeQuery = chatProvider.suggestedRecipe;

    if (recipeQuery == null || recipeQuery.isEmpty) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await Provider.of<RecipeProvider>(context, listen: false).generateRecipe(
        recipeQuery,
        save: authProvider.token != null,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final messages = chatProvider.messages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              chatProvider.clearMessages();
            },
            tooltip: 'New Conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome message
          if (messages.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/chat_icon.png',
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chat with your Cooking Assistant',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Ask for recipe ideas, cooking tips, or help with ingredients',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return ChatBubble(
                    message: message,
                    onGenerateRecipe: message.type == MessageType.ai &&
                        message.canGenerateRecipe
                        ? _generateRecipe
                        : null,
                  );
                },
              ),
            ),

          // AI is typing indicator
          if (_isTyping || chatProvider.isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Typing...'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Recipe suggestion
          if (chatProvider.canGenerateRecipe && chatProvider.suggestedRecipe != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Would you like to see a recipe for "${chatProvider.suggestedRecipe}"?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _generateRecipe,
                    child: const Text('Generate'),
                  ),
                ],
              ),
            ),

          // Message input
          MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            isLoading: _isTyping || chatProvider.isLoading,
          ),
        ],
      ),
    );
  }
}