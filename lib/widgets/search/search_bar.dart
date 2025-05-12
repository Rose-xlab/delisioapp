// lib/widgets/search/search_bar.dart
import 'package:flutter/material.dart';

class EnhancedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final Function(String)? onChanged;
  final Function()? onClear;
  final Function()? onCancel;
  final String hintText;
  final bool isLoading;
  final FocusNode? focusNode;
  final bool showCancelButton;
  final bool autofocus;

  const EnhancedSearchBar({
    Key? key,
    required this.controller,
    required this.onSubmitted,
    this.onChanged,
    this.onClear,
    this.onCancel,
    this.hintText = 'Search for recipes...',
    this.isLoading = false,
    this.focusNode,
    this.showCancelButton = true,
    this.autofocus = false,
  }) : super(key: key);

  @override
  _EnhancedSearchBarState createState() => _EnhancedSearchBarState();
}

class _EnhancedSearchBarState extends State<EnhancedSearchBar> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    if (widget.autofocus) {
      // Schedule focus request for after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: Row(
        children: [
          // Main search field
          Expanded(
            child: Container(
              height:54,
              padding:const EdgeInsets.all(2.0),

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                border: Border.all(
                  color: _isFocused
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300]!,
                  width: 1.5,
                ),
                boxShadow: _isFocused
                    ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
                    : null,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  // Leading icon
                  InkWell(
                    onTap: (){
                       if (widget.controller.text.isNotEmpty) {
                          widget.onSubmitted(widget.controller.text);
                        }
                    },
                    child: Icon(
                      Icons.search,
                      color: _isFocused
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                    ),
                  ),
                  // const SizedBox(width: 8),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,

                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          widget.onSubmitted(value);
                        }
                      },

                      onChanged: widget.onChanged,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        border: InputBorder.none,
                        enabledBorder:InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  // Clear or loading indicator
                  if (widget.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    )
                  else if (widget.controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      iconSize: 20,
                      splashRadius: 20,
                      color: Colors.grey[600],
                      onPressed: () {
                        widget.controller.clear();
                        if (widget.onClear != null) {
                          widget.onClear!();
                        }
                      },
                    ),
                ],
              ),
            ),
          ),

          // Cancel button
          if (widget.showCancelButton && _isFocused)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                onPressed: () {
                  _focusNode.unfocus();
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(10, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Cancel'),
              ),
            ),
        ],
      ),
    );
  }
}