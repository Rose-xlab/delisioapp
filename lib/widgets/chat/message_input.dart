// widgets/chat/message_input.dart
import 'package:flutter/material.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final bool isLoading;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                  },
                )
                    : null,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                // Force rebuild to show/hide clear button
                (context as Element).markNeedsBuild();
              },
              maxLines: null,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: isLoading
                  ? null
                  : (value) {
                if (value.trim().isNotEmpty) {
                  onSend(value);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          Material(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(50),
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: isLoading
                  ? null
                  : () {
                if (controller.text.trim().isNotEmpty) {
                  onSend(controller.text);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                child: isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}