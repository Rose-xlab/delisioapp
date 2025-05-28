// lib/widgets/chat/message_input.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

// Corrected to relative import paths
import '../../../constants/myofferings.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/subscription_provider.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final bool isLoading;
  final String hintText;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
    this.hintText = 'Type a message...',
  }) : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateHasText);
    // Initialize _hasText based on controller's initial value
    _updateHasText();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateHasText);
    super.dispose();
  }

  void _updateHasText() {
    final currentHasText = widget.controller.text.isNotEmpty;
    if (mounted && currentHasText != _hasText) {
      setState(() {
        _hasText = currentHasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Listen to false here if only using for one-off checks/actions,
    // but if UI should rebuild when these providers change, listen: true (default) is fine.
    final chatProvider = Provider.of<ChatProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    // Determine if the user can send a message or needs to upgrade.
    // This logic prioritizes the backend's view of subscription limits if available.
    bool userCanChat;
    final subInfo = subscriptionProvider.subscriptionInfo;

    if (subscriptionProvider.isProSubscriber) { // Pro users can always chat
      userCanChat = true;
    } else if (subInfo != null) { // Free user, check backend limits
      // Using -1 as convention for unlimited
      userCanChat = subInfo.aiChatRepliesLimit == -1 || subInfo.aiChatRepliesRemaining > 0;
    } else {
      // Fallback if backend subscriptionInfo is not available (e.g., loading or error)
      // This uses your original logic of limiting free users by conversation count as a fallback.
      // Consider showing a loading/error state if subInfo is null and expected.
      userCanChat = chatProvider.conversations.length < 3; // Max 3 conversations for free if no specific reply limit info
      if (chatProvider.conversations.length >= 3) {
        debugPrint("MessageInput: User has ${chatProvider.conversations.length} conversations, fallback limit reached.");
      }
    }

    // For debugging the canChat logic
    // debugPrint("MessageInput: isProSubscriber: ${subscriptionProvider.isProSubscriber}");
    // if(subInfo != null) {
    //   debugPrint("MessageInput: subInfo - Tier: ${subInfo.tier}, Replies Limit: ${subInfo.aiChatRepliesLimit}, Replies Rem: ${subInfo.aiChatRepliesRemaining}");
    // } else {
    //   debugPrint("MessageInput: subInfo is null. Conversation count: ${chatProvider.conversations.length}");
    // }
    // debugPrint("MessageInput: Calculated userCanChat: $userCanChat");


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: theme.cardColor, // Use theme's card color for better theme adaptability
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // Softer shadow
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor, // Or a slightly different shade
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: theme.hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12, // Adjust for better vertical centering
                  ),
                  suffixIcon: _hasText
                      ? IconButton(
                    icon: Icon(Icons.clear, size: 20, color: theme.iconTheme.color?.withOpacity(0.7)),
                    onPressed: () {
                      widget.controller.clear();
                    },
                  )
                      : null,
                ),
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline, // Allow multiline
                textInputAction: TextInputAction.newline, // For multiline, send is usually manual
                minLines: 1,
                maxLines: 5,
                enabled: !widget.isLoading && userCanChat, // Disable if loading or cannot chat
                onSubmitted: (value) {
                  // For multiline, onSubmitted might not be the primary send trigger.
                  // The send button is more common.
                  // if (userCanChat && value.trim().isNotEmpty && !widget.isLoading) {
                  //   widget.onSend(value);
                  // }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (userCanChat)
            Material(
              color: _hasText && !widget.isLoading ? colorScheme.primary : theme.disabledColor,
              borderRadius: BorderRadius.circular(24), // Match TextField border radius
              elevation: _hasText && !widget.isLoading ? 2 : 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: (_hasText && !widget.isLoading)
                    ? () {
                  if (widget.controller.text.trim().isNotEmpty) {
                    widget.onSend(widget.controller.text);
                  }
                }
                    : null,
                child: Padding( // Use Padding for consistent tap area
                  padding: const EdgeInsets.all(12.0),
                  child: widget.isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white, // Or colorScheme.onPrimary
                      strokeWidth: 2.5,
                    ),
                  )
                      : Icon(
                    Icons.send_rounded,
                    color: _hasText && !widget.isLoading ? colorScheme.onPrimary : theme.iconTheme.color?.withOpacity(0.5),
                    size: 24,
                  ),
                ),
              ),
            )
          else // Show Upgrade Button if userCanChat is false
            ElevatedButton.icon(
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              label: const Text('Upgrade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600, // Or theme.colorScheme.secondary
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () {
                // Use the .identifier from your MyOfferings enum
                RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro.identifier);
              },
            ),
        ],
      ),
    );
  }
}