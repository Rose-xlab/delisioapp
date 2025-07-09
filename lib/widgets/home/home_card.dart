import 'package:flutter/material.dart';

class HomeCard extends StatelessWidget {
  final VoidCallback onGenerateNow;

  const HomeCard({
    super.key,
    required this.onGenerateNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF23B5A),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        children: [
          //
          const Text(
            'Generate your favourite recipe',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          //
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'With the help of our AI backed system; generate any recipe in seconds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.0,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: Image.asset(
                  'assets/fryingpan.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      color: Colors.white.withOpacity(0.2),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          //

          // The "Generate Now" button.
          ElevatedButton.icon(
            onPressed: onGenerateNow,
            icon: const Icon(
              Icons.auto_awesome, // Sparkle icon.
              color: Color(0xFFF23B5A),
            ),
            label: const Text(
              'Generate Now',
              style: TextStyle(
                color: Color(0xFFF23B5A),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, // White button background.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
