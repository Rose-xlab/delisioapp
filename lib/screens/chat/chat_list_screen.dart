// lib/screens/chat/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/conversation.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_display.dart';

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

    // Show loading overlay
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Creating new chat..."),
                ],
              ),
            ),
          );
        }
    );

    try {
      final newConversationId = await chatProvider.createNewConversation();

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to chat screen with the new ID
      if (newConversationId != null && context.mounted) {
        Navigator.of(context).pushNamed('/chat', arguments: newConversationId);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not start new chat.'),
                backgroundColor: Colors.red
            )
        );
      }
    } catch (e) {
      // Close loading dialog in case of error
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error creating chat: ${e.toString()}'),
                backgroundColor: Colors.red
            )
        );
      }
    }
  }

  Future<void> _refreshConversations() async {
    await Provider.of<ChatProvider>(context, listen: false).loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Conversationsv'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshConversations,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshConversations,
        child: _buildBody(chatProvider, theme),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        tooltip: 'New Chat',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(ChatProvider chatProvider, ThemeData theme) {
    if (chatProvider.isLoadingConversations) {
      return const Center(child: LoadingIndicator(message: 'Loading conversations...'));
    }

    if (chatProvider.conversationsError != null) {
      return ErrorDisplay(
        message: chatProvider.conversationsError!,
        onRetry: _refreshConversations,
      );
    }

    if (chatProvider.conversations.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Display list of conversations
    return _buildConversationsList(chatProvider, theme);
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new chat to begin cooking conversations',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startNewChat,
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(ChatProvider chatProvider, ThemeData theme) {
    final conversations = chatProvider.conversations;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: conversations.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final conversation = conversations[index];

        // Format the date as relative time
        final now = DateTime.now();
        final difference = now.difference(conversation.updatedAt);
        String timeText;

        if (difference.inMinutes < 1) {
          timeText = 'Just now';
        } else if (difference.inHours < 1) {
          timeText = '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24) {
          timeText = '${difference.inHours}h ago';
        } else if (difference.inDays < 2) {
          timeText = 'Yesterday';
        } else if (difference.inDays < 7) {
          timeText = '${difference.inDays}d ago';
        } else {
          // Format date as "Month Day, Year" for older conversations
          final DateFormat formatter = DateFormat('MMM d, yyyy');
          timeText = formatter.format(conversation.updatedAt);
        }

        return Dismissible(
          key: Key(conversation.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Delete Conversation?"),
                  content: const Text(
                      "This will permanently delete this conversation history."
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("CANCEL"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        "DELETE",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            ) ?? false;
          },
          onDismissed: (direction) {
            chatProvider.deleteConversation(conversation.id);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation deleted'))
            );
          },
          child: ConversationCard(
            conversation: conversation,
            timeText: timeText,
            onTap: () {
              // Navigate to chat screen with this conversation ID
              Navigator.of(context).pushNamed(
                  '/chat',
                  arguments: conversation.id
              );
            },
            onRename: () async {
              // Placeholder for rename functionality
              // TODO: Implement conversation renaming
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rename functionality not yet implemented'))
              );
            },
            onDelete: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Delete Conversation?"),
                    content: const Text(
                        "This will permanently delete this conversation history."
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("CANCEL"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          "DELETE",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              ) ?? false;

              if (confirmed) {
                await chatProvider.deleteConversation(conversation.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conversation deleted'))
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}

class ConversationCard extends StatelessWidget {
  final Conversation conversation;
  final String timeText;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const ConversationCard({
    Key? key,
    required this.conversation,
    required this.timeText,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Conversation icon
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColorLight,
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ),

              const SizedBox(width: 16),

              // Conversation title and time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title ?? 'New Conversation',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Action menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'rename') {
                    onRename();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}