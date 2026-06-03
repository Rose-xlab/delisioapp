import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../constants/myofferings.dart';

class LockedRecipeOverlay extends StatelessWidget {
  final Widget child;
  final bool isLocked;

  const LockedRecipeOverlay({
    Key? key,
    required this.child,
    required this.isLocked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    final theme = Theme.of(context);

    return Stack(
      children: [
        // The actual content (blurred)
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: child,
        ),

        // Darkened overlay to make text pop
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.1),
          ),
        ),

        // Paywall Content
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unlock Full Recipe',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your custom recipe is ready! Upgrade to Pro to unlock ingredients, step-by-step instructions, and unlimited cooking.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('Go Pro & Unlock'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro.identifier);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
