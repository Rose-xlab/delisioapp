import 'package:flutter/material.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: Row(
      children: [
        // Left line
        Expanded(
          child: Divider(
            color: Colors.grey[300],
            thickness: 1,
            endIndent: 8,
          ),
        ),
        // "OR" Text
        Text(
          'OR',
          style: TextStyle(
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        // Right line
        Expanded(
          child: Divider(
            color: Colors.grey[300],
            thickness: 1,
            indent: 8,
          ),
        ),
      ],
    ),
    );
  }
}
