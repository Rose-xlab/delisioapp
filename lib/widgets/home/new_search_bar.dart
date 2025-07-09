import 'package:flutter/material.dart';

/// A custom search bar widget that matches the provided image.
class NewSearchBar extends StatefulWidget {
  /// The placeholder text to display when the search bar is empty.
  final String hintText;

  /// A callback function that is triggered when the user submits a search.
  /// The current text in the search bar is passed as an argument.
  final ValueChanged<String> onSearch;

  const NewSearchBar({
    super.key,
    required this.hintText,
    required this.onSearch,
  });

  @override
  State<NewSearchBar> createState() => _NewSearchBarState();
}

class _NewSearchBarState extends State<NewSearchBar> {
  // Controller to manage the text being entered in the search field.
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the widget tree.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(),
      child: TextField(
        controller: _controller,
        onSubmitted: widget.onSearch,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.grey[600]),
          // The search icon on the left.
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFFF23B5A),
            size: 28,
          ),
          // Add some padding to align the content nicely.
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
        ),
      ),
    );
  }
}
