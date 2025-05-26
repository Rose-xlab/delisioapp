import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <<< ADDED THIS IMPORT
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

import '../../providers/chat_provider.dart';
import '../../models/conversation.dart';
// Assuming your AppTheme is in a standard location, adjust if necessary
// import '../../theme/app_theme_updated.dart'; // If you need specific theme colors not covered by Theme.of(context)

class ConversationListHostScreen extends StatelessWidget {
  final Function(String conversationId) onConversationSelected;
  final VoidCallback onStartNewChat;

  const ConversationListHostScreen({
    Key? key,
    required this.onConversationSelected,
    required this.onStartNewChat,
  }) : super(key: key);

  Widget _buildEmptyConversationsState(ThemeData theme, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text('No conversations yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Start a new chat to ask about recipes or cooking tips!',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text("Start Your First Chat"),
                onPressed: onStartNewChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(
      BuildContext context,
      List<Conversation> conversations,
      ChatProvider chatProvider,
      ) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor.withOpacity(0.5)),
      itemBuilder: (context, index) {
        final conversation = conversations[index];

        final now = DateTime.now();
        final difference = now.difference(conversation.updatedAt.toLocal());
        String timeText;

        if (difference.inSeconds < 60) {
          timeText = 'Just now';
        } else if (difference.inMinutes < 60) {
          timeText = '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24 && now.day == conversation.updatedAt.toLocal().day) {
          timeText = DateFormat.jm().format(conversation.updatedAt.toLocal());
        } else if (difference.inDays < 1 && now.day -1 == conversation.updatedAt.toLocal().day) {
          timeText = 'Yesterday';
        } else if (difference.inDays < 7) {
          timeText = DateFormat('EEE').format(conversation.updatedAt.toLocal());
        } else if (now.year == conversation.updatedAt.toLocal().year) {
          timeText = DateFormat('MMM d').format(conversation.updatedAt.toLocal());
        } else {
          timeText = DateFormat('MMM d, yy').format(conversation.updatedAt.toLocal());
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.7),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          title: Text(
            conversation.title ?? 'Chat - ${conversation.id.substring(0, 6)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            timeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          trailing: Icon(Icons.chevron_right, color: theme.hintColor.withOpacity(0.7)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: () {
            if (kDebugMode) {
              print("ConversationListHostScreen: Tapped on conversation ${conversation.id}");
            }
            onConversationSelected(conversation.id);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final conversations = chatProvider.conversations;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Your Conversations"),
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0.5,
            shape: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.5),
                width: 0.5,
              ),
            ),
            systemOverlayStyle: SystemUiOverlayStyle( // Now defined
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'Start New Chat',
                onPressed: onStartNewChat,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: chatProvider.isLoadingConversations && conversations.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : conversations.isEmpty
                    ? _buildEmptyConversationsState(theme, context)
                    : _buildConversationsList(context, conversations, chatProvider),
              ),
            ],
          ),
        );
      },
    );
  }
}
