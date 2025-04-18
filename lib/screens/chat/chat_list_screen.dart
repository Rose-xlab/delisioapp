// lib/screens/chat/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/conversation.dart';
import '../../widgets/common/loading_indicator.dart'; // Assuming you have these
import '../../widgets/common/error_display.dart'; // Assuming you have these

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    // Load conversations when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).loadConversations();
    });
  }

  Future<void> _startNewChat() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // Show loading indicator maybe?
    final newConversationId = await chatProvider.createNewConversation();
    if (newConversationId != null && mounted) {
      // Navigate to the ChatScreen with the new ID
      Navigator.of(context).pushNamed('/chat', arguments: newConversationId);
    } else {
      // Handle error creating conversation (provider should set error state)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not start new chat.'), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _openConversation(String conversationId) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // Select conversation in provider (which also loads messages)
    chatProvider.selectConversation(conversationId);
    // Navigate to chat screen with the ID
    Navigator.of(context).pushNamed('/chat', arguments: conversationId);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the provider for updates
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Chats'),
        // Optional: Add refresh button
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: () => chatProvider.loadConversations(),
        //     tooltip: 'Refresh Chats',
        //   )
        // ],
      ),
      body: _buildBody(chatProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewChat,
        icon: const Icon(Icons.add),
        label: const Text('New Chat'),
      ),
    );
  }

  Widget _buildBody(ChatProvider chatProvider) {
    if (chatProvider.isLoadingConversations) {
      return const LoadingIndicator(message: 'Loading chats...');
    }

    if (chatProvider.conversationsError != null) {
      return ErrorDisplay(
        message: chatProvider.conversationsError!,
        onRetry: () => chatProvider.loadConversations(), // Add retry
      );
    }

    if (chatProvider.conversations.isEmpty) {
      return const Center(
        child: Text(
          'No chats yet. Start a new one!',
          style: TextStyle(fontSize: 18, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Display list of conversations
    return ListView.builder(
      itemCount: chatProvider.conversations.length,
      itemBuilder: (context, index) {
        final conversation = chatProvider.conversations[index];
        return ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: Text(conversation.title ?? 'Chat ${conversation.id.substring(0, 6)}'), // Use generated title
          subtitle: Text('Last active: ${DateFormat.yMd().add_jm().format(conversation.updatedAt.toLocal())}'), // Format date
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openConversation(conversation.id),
          // Optional: Add swipe-to-delete or long-press menu for deleting
          // onLongPress: () => _showDeleteDialog(conversation.id),
        );
      },
    );
  }

// --- Optional: Delete confirmation ---
// void _showDeleteDialog(String conversationId) {
//   showDialog(
//     context: context,
//     builder: (ctx) => AlertDialog(
//       title: const Text('Delete Chat?'),
//       content: const Text('Are you sure you want to delete this chat history permanently?'),
//       actions: [
//         TextButton(
//           child: const Text('Cancel'),
//           onPressed: () => Navigator.of(ctx).pop(),
//         ),
//         TextButton(
//           child: const Text('Delete', style: TextStyle(color: Colors.red)),
//           onPressed: () {
//              Provider.of<ChatProvider>(context, listen: false).deleteConversation(conversationId);
//              Navigator.of(ctx).pop();
//           },
//         ),
//       ],
//     ),
//   );
// }


}