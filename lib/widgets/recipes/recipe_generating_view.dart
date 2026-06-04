// lib/widgets/recipes/recipe_generating_view.dart
//
// A polished, engaging full-screen "your recipe is cooking" experience shown
// while a recipe is being generated. It is purely presentational and driven by
// the real backend progress (0..1) and the partial recipe title (revealed as
// soon as it is known), so it reflects genuine progress rather than a fake spinner.
import 'dart:async';
import 'package:flutter/material.dart';

class RecipeGeneratingView extends StatefulWidget {
  /// Real generation progress in the range 0.0 .. 1.0.
  final double progress;

  /// The recipe title, revealed as soon as the backend knows it (may be null early).
  final String? recipeTitle;

  /// Whether a cancellation is currently in flight.
  final bool isCancelling;

  /// Called when the user taps "Cancel". If null, no cancel affordance is shown.
  final VoidCallback? onCancel;

  const RecipeGeneratingView({
    Key? key,
    required this.progress,
    this.recipeTitle,
    this.isCancelling = false,
    this.onCancel,
  }) : super(key: key);

  @override
  State<RecipeGeneratingView> createState() => _RecipeGeneratingViewState();
}

class _RecipeGeneratingViewState extends State<RecipeGeneratingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _tipTimer;
  int _tipIndex = 0;

  static const List<String> _tips = [
    'Tip: Salt your pasta water until it tastes like the sea. 🌊',
    'Tip: Let meat rest after cooking so the juices stay in. 🥩',
    'Did you know? Resting dough makes it far easier to roll. 🍞',
    'Tip: Toast whole spices to wake up their aroma. 🌶️',
    'Tip: A squeeze of lemon brightens almost any dish. 🍋',
    'Tip: Prep your mise en place — cooking gets calmer. 🔪',
    'Tip: Pat proteins dry for a deeper, crispier sear. 🔥',
    'Tip: Taste as you go and adjust seasoning at the end. 🧂',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _tipTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (!mounted) return;
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  String _stageLabel(double p) {
    if (p < 0.15) return 'Warming up the kitchen…';
    if (p < 0.35) return 'Crafting your recipe…';
    if (p < 0.60) return 'Writing the steps…';
    if (p < 0.90) return 'Plating the photos…';
    if (p < 1.0) return 'Adding the final touches…';
    return 'Ready!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final double clamped = widget.progress.clamp(0.0, 1.0);
    final String stage = _stageLabel(clamped);
    final bool hasTitle = widget.recipeTitle != null &&
        widget.recipeTitle!.trim().isNotEmpty &&
        widget.recipeTitle!.trim().toLowerCase() != 'this recipe';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withOpacity(0.10),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // --- Animated progress ring with pulsing icon + live % ---
              SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 168,
                      height: 168,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: clamped),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (_, value, __) => CircularProgressIndicator(
                          // Indeterminate spin until the first real progress arrives.
                          value: value <= 0 ? null : value,
                          strokeWidth: 9,
                          backgroundColor: primary.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(primary),
                        ),
                      ),
                    ),
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.08).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant_menu_rounded, size: 34, color: primary),
                          const SizedBox(height: 2),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: clamped),
                            duration: const Duration(milliseconds: 600),
                            builder: (_, value, __) => Text(
                              '${(value * 100).round()}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- Stage label (changes with progress) ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  stage,
                  key: ValueKey<String>(stage),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),

              // --- Title reveal (as soon as it's known) ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: hasTitle
                    ? Container(
                        key: ValueKey<String>(widget.recipeTitle!),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 16, color: primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                widget.recipeTitle!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        'Hang tight — your recipe is on its way',
                        key: const ValueKey<String>('placeholder'),
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
              ),

              const Spacer(flex: 3),

              // --- Rotating cooking tip ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: Container(
                  key: ValueKey<int>(_tipIndex),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tips[_tipIndex],
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // --- Cancel affordance ---
              if (widget.onCancel != null)
                widget.isCancelling
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text('Cancelling…', style: TextStyle(color: Colors.grey[600])),
                        ],
                      )
                    : TextButton.icon(
                        onPressed: widget.onCancel,
                        icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[600]),
                        label: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                      ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
