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
    _updateHasText(); // Initialize _hasText based on controller's initial value
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
    final chatProvider = Provider.of<ChatProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    bool userCanChat;
    final subInfo = subscriptionProvider.subscriptionInfo;

    if (subscriptionProvider.isProSubscriber) {
      userCanChat = true;
    } else if (subInfo != null) {
      userCanChat = subInfo.aiChatRepliesLimit == -1 || subInfo.aiChatRepliesRemaining > 0;
    } else {
      userCanChat = chatProvider.conversations.length < 3;
      if (chatProvider.conversations.length >= 3) {
        debugPrint("MessageInput: User has ${chatProvider.conversations.length} conversations, fallback limit reached.");
      }
    }

    // Define the border color from the image, which appears light pink/rose.
    final Color inputBorderColor = Colors.pink.shade100;
    // Define the send button background color.
    final Color sendButtonColor = Colors.grey.shade300; // Light grey for the send button background

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Adjust padding
      decoration: BoxDecoration(
        color: Colors.white, // The background of the entire input area is white
        borderRadius: BorderRadius.circular(8.0), // Rounded corners for the container
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(
          color: inputBorderColor, // Border around the entire container
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically in the center
        children: [
          // Icon on the left side
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.auto_awesome_rounded, // A star icon, or you can find a more specific one
              color: Colors.pinkAccent, // A pink color
              size: 24,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              decoration: InputDecoration(
                fillColor: Colors.white,
                hintText: widget.hintText,
                hintStyle: TextStyle(color: theme.hintColor),
                border:InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none, // No border for the TextField itself
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0, // No horizontal padding here, handled by row
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
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 1,
              maxLines: 5,
              enabled: !widget.isLoading && userCanChat,
            ),
          ),
          const SizedBox(width: 8),
          if (userCanChat)
            Material(
              color: _hasText ? colorScheme.primary : sendButtonColor, // Light grey background for the send button
              borderRadius: BorderRadius.circular(24), // Circular shape
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: (_hasText && !widget.isLoading)
                    ? () {
                  if (widget.controller.text.trim().isNotEmpty) {
                    widget.onSend(widget.controller.text);
                  }
                }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: widget.isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Icon(
                    Icons.send_rounded,
                    color: _hasText && !widget.isLoading ? Colors.white : Colors.white, // Darker grey when enabled
                    size: 24,
                  ),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              label: const Text('Upgrade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () {
                RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro.identifier);
              },
            ),
        ],
      ),
    );
  }
}