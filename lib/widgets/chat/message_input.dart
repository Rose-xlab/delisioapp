// lib/widgets/chat/message_input.dart
import 'package:flutter/material.dart';
import 'package:kitchenassistant/constants/myofferings.dart';
import 'package:kitchenassistant/providers/chat_provider.dart';
import 'package:kitchenassistant/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

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
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateHasText);
    super.dispose();
  }

  void _updateHasText() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chatProvider = Provider.of<ChatProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    debugPrint("================= CONVASATION  LENGTH: ${chatProvider.conversations.length.toString()}  ===========");

    final canChat = subscriptionProvider.isProSubscriber == false && chatProvider.conversations.length <= 3 ? true : subscriptionProvider.isProSubscriber ? true : false ; 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Message input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  // Only show the clear button if there's text
                  suffixIcon: _hasText
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                    },
                  )
                      : null,
                ),
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 5,
                // Allow multi-line input
                enabled: !widget.isLoading,
                onSubmitted: (value) {
                  if (value
                      .trim()
                      .isNotEmpty && !widget.isLoading) {
                    widget.onSend(value);
                  }
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
        canChat ?  Material(
            color: _hasText ? colorScheme.primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(50),
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: (_hasText && !widget.isLoading)
                  ? () {
                if (widget.controller.text
                    .trim()
                    .isNotEmpty) {
                  widget.onSend(widget.controller.text);
                }
              }
                  : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: widget.isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Icon(
                  Icons.send,
                  color: _hasText ? Colors.white : Colors.grey.shade400,
                  size: 24,
                ),
              ),
            ),
          ) : TextButton(
              onPressed: () {
                // Ensure "TestPro" is your Offering Identifier in RevenueCat
                RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro);
              },
              style: TextButton.styleFrom(
                backgroundColor:Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Upgrade'),
            ),
        ],
      ),
    );
  }
}