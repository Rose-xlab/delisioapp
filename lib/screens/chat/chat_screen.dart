// lib/screens/chat/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_message.dart'; // Uses updated model
import '../../widgets/chat/chat_bubble.dart'; // Uses updated widget
import '../../widgets/chat/message_input.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;

  const ChatScreen({
    required this.conversationId,
    Key? key,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    print("ChatScreen: Initializing for conversation ID: ${widget.conversationId}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) {
        Provider.of<ChatProvider>(context, listen: false).selectConversation(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    final text = message.trim();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (text.isEmpty || chatProvider.isSendingMessage) return;
    _messageController.clear();
    await chatProvider.sendMessage(text);
    _scrollToBottom();
  }

  // --- FIX: Add handler for suggestion selection ---
  void _onSuggestionSelected(String suggestion) {
    print("Suggestion selected in ChatScreen: $suggestion");
    // Trigger recipe generation for the specific suggestion
    _generateRecipeFromChat(suggestion);
  }
  // --- End of FIX ---


  // Generate Recipe logic remains largely the same, now triggered by _onSuggestionSelected
  Future<void> _generateRecipeFromChat(String? suggestedQuery) async {
    // ... (Keep the existing _generateRecipeFromChat logic from response #46) ...
    // It should already work correctly as it takes the specific query string
    if (_isGenerating) return;
    print("Generate Recipe triggered from chat suggestion: $suggestedQuery");
    final String recipeQuery = suggestedQuery ?? "";
    if (recipeQuery.isEmpty) {
      print("Error: Cannot generate recipe. No valid query context found from suggestion.");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Could not determine which recipe to generate.'), backgroundColor: Colors.orange) ); }
      return;
    }
    if (mounted) setState(() => _isGenerating = true);
    print("Attempting to generate recipe for: $recipeQuery from chat context.");
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      await recipeProvider.generateRecipe( recipeQuery, save: authProvider.isAuthenticated, token: authProvider.token, ); // Use isAuthenticated
      print("Recipe generation initiated via RecipeProvider..."); // Log initiation
      // IMPORTANT: We should check RecipeProvider's state *before* navigating
      // This assumes RecipeProvider sets its state correctly upon success/failure
      // We might need to listen to RecipeProvider or check its state after await
      // For now, let's keep the navigation optimistic but add a check *if* provider throws

      // Let RecipeProvider handle state, navigation might happen via listener elsewhere or checking state
      // For simplicity, let's assume successful call means navigation is intended (could be improved)
      if (mounted && recipeProvider.error == null) { // Check for error before navigating
        print("RecipeProvider has no error, navigating to /recipe");
        Navigator.of(context).pushNamed('/recipe');
      } else if (mounted && recipeProvider.error != null) {
        print("RecipeProvider has error, showing Snackbar instead of navigating.");
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error generating recipe: ${recipeProvider.error}'), backgroundColor: Colors.red) );
      }

    } catch (e) { // Catch errors re-thrown by RecipeProvider maybe
      print("Error caught in _generateRecipeFromChat: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error generating recipe: ${e.toString()}'), backgroundColor: Colors.red) ); }
    } finally {
      if (mounted) { setState(() => _isGenerating = false); }
    }
  }


  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final bool isActiveConversation = chatProvider.activeConversationId == widget.conversationId;
    final messages = isActiveConversation ? chatProvider.activeMessages : <ChatMessage>[];
    final isLoadingMessages = isActiveConversation ? chatProvider.isLoadingMessages : false;
    final isSendingMessage = chatProvider.isSendingMessage;
    final error = isActiveConversation ? chatProvider.messagesError ?? chatProvider.sendMessageError : null;

    if (isActiveConversation && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted) _scrollToBottom(); });
    }

    print("Building ChatScreen for ${widget.conversationId}. IsActive: $isActiveConversation. Messages: ${messages.length}");

    return Scaffold(
      appBar: AppBar( title: const Text('Chat Assistant'), ),
      body: Column(
        children: [
          // Loading / Error / Welcome messages (remain the same)
          if (isLoadingMessages && messages.isEmpty)
            const Expanded(child: LoadingIndicator(message: 'Loading messages...'))
          else if (error != null && messages.isEmpty)
            Expanded(child: ErrorDisplay(message: "Error loading chat: $error"))
          else if (messages.isEmpty && !isSendingMessage)
              Expanded( child: Center( /* ... Welcome message content ... */
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset('assets/chat_icon.png', width: 100, height: 100, errorBuilder: (ctx, err, stack) => const Icon(Icons.chat_bubble_outline, size: 100, color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Text('Chat with your Cooking Assistant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('Ask for recipe ideas, cooking tips, or help with ingredients', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey))),
                  ],),),),)
            // Chat messages list
            else
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    // Removed: canThisMessageGenerate logic
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ChatBubble(
                        message: message,
                        // FIX: Pass the new suggestion selection callback
                        onSuggestionSelected: _onSuggestionSelected,
                      ),
                    );
                  },
                ),
              ),

          // Indicators (remain the same)
          if (isSendingMessage) Padding( /* ... Assistant thinking indicator ... */
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row( mainAxisAlignment: MainAxisAlignment.start, children: [ Container( padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)), child: const Row( mainAxisSize: MainAxisSize.min, children: [ SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)), SizedBox(width: 8), Text('Assistant is thinking...', style: TextStyle(color: Colors.black54)), ], ), ), ], ), ),
          if (_isGenerating) Container( /* ... Generating recipe indicator ... */
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Theme.of(context).primaryColorLight.withOpacity(0.2), child: const Row( mainAxisAlignment: MainAxisAlignment.center, children: [ SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Text('Generating your recipe...', style: TextStyle(fontWeight: FontWeight.bold)), ], ), ),

          // Message Input (remain the same)
          if (chatProvider.sendMessageError != null && isActiveConversation) Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), child: Text(chatProvider.sendMessageError!, style: TextStyle(color: Theme.of(context).colorScheme.error)), ),
          MessageInput( controller: _messageController, onSend: _sendMessage, isLoading: isSendingMessage || _isGenerating, ),
        ],
      ),
    );
  }
}