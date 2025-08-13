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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Cook Something Amazing!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          // Subtitle and Image
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    'Let our AI craft delicious recipes for you in seconds!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 13.0,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: Image.asset(
                  'assets/fryingpan.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // The "Generate Now" button - centered
          Center(
            child: ElevatedButton.icon(
              onPressed: onGenerateNow,
              icon: const Icon(
                Icons.auto_awesome, // Sparkle icon.
                color: Color(0xFFF23B5A),
                size: 20,
              ),
              label: const Text(
                'Create Recipe',
                style: TextStyle(
                  color: Color(0xFFF23B5A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // White button background.
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}