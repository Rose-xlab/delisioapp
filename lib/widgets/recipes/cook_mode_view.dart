import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/recipe_step.dart';
// Assuming your AppTheme is in a standard location.
// We'll use its color constants directly if they are static.
import '../../theme/app_theme_updated.dart'; // Or app_theme.dart if that's the one you use

class CookModeView extends StatefulWidget {
  final List<RecipeStep> steps;
  final VoidCallback onExitCookMode;

  const CookModeView({
    Key? key,
    required this.steps,
    required this.onExitCookMode,
  }) : super(key: key);

  @override
  State<CookModeView> createState() => _CookModeViewState();
}

class _CookModeViewState extends State<CookModeView> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isFullscreenUIHidden = true;

  // New state for Cook Mode theme
  bool _isCookModeLight = true; // Default to light theme for cook mode

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _setSystemUIForCookMode(_isFullscreenUIHidden);
    _startHideControlsTimer();
  }

  void _setSystemUIForCookMode(bool hideSystemUI) {
    if (hideSystemUI) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideControlsTimer();
      } else {
        _hideControlsTimer?.cancel();
      }
    });
  }

  void _toggleSystemFullscreen() {
    setState(() {
      _isFullscreenUIHidden = !_isFullscreenUIHidden;
    });
    _setSystemUIForCookMode(_isFullscreenUIHidden);
    if (!_showControls) {
      _toggleControlsVisibility();
    } else {
      _startHideControlsTimer();
    }
  }

  // Method to toggle Cook Mode theme
  void _toggleCookModeTheme() {
    setState(() {
      _isCookModeLight = !_isCookModeLight;
    });
    // Keep controls visible briefly after theme change
    if (!_showControls) {
      _showControls = true;
    }
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the app's theme for fallback, but override with _isCookModeLight
    final appTheme = Theme.of(context);

    // Define colors based on _isCookModeLight state
    final Color currentScaffoldBackgroundColor = _isCookModeLight ? AppTheme.lightBackground : AppTheme.darkBackground;
    final Color currentOverlayControlsColor = _isCookModeLight ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.8);
    final Color currentOverlayTextColor = _isCookModeLight ? Colors.black87 : Colors.white;
    final Color currentOverlayBackgroundColor = _isCookModeLight
        ? AppTheme.lightSurface.withOpacity(0.85)
        : Colors.black.withOpacity(0.7);
    final Color currentDotIndicatorActiveColor = _isCookModeLight ? appTheme.colorScheme.secondary : AppTheme.darkSecondaryColor; // Or a specific light/dark secondary
    final Color currentDotIndicatorInactiveColor = _isCookModeLight ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.4);

    return Scaffold(
      backgroundColor: currentScaffoldBackgroundColor,
      body: GestureDetector(
        onTap: _toggleControlsVisibility,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.steps.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                if (_showControls) _startHideControlsTimer();
              },
              itemBuilder: (context, index) {
                // Pass the current cook mode theme preference to the step page
                return _buildStepPage(widget.steps[index], index + 1, _isCookModeLight);
              },
            ),

            // Top control bar
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    color: currentOverlayBackgroundColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new, color: currentOverlayControlsColor, size: 20),
                            tooltip: "Exit Cook Mode",
                            onPressed: widget.onExitCookMode,
                          ),
                          Text(
                            'Step ${_currentPage + 1}/${widget.steps.length}',
                            style: TextStyle(color: currentOverlayTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              // Theme Toggle Button
                              IconButton(
                                icon: Icon(
                                  _isCookModeLight ? Icons.brightness_4_outlined : Icons.brightness_7_outlined, // Moon for dark, Sun for light
                                  color: currentOverlayControlsColor, size: 24,
                                ),
                                tooltip: _isCookModeLight ? "Switch to Dark Mode" : "Switch to Light Mode",
                                onPressed: _toggleCookModeTheme,
                              ),
                              IconButton(
                                icon: Icon(
                                  _isFullscreenUIHidden ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: currentOverlayControlsColor, size: 24,
                                ),
                                tooltip: _isFullscreenUIHidden ? "Show System UI" : "Hide System UI",
                                onPressed: _toggleSystemFullscreen,
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: currentOverlayControlsColor, size: 24),
                                tooltip: "Exit Cook Mode",
                                onPressed: widget.onExitCookMode,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom navigation indicators (Dots)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    color: currentOverlayBackgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.steps.length,
                              (index) => GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: _currentPage == index ? 20 : 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? currentDotIndicatorActiveColor
                                    : currentDotIndicatorInactiveColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Left/Right navigation arrows
            if (widget.steps.length > 1)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Positioned.fill(
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentPage > 0)
                            IconButton(
                              icon: Icon(Icons.arrow_back_ios_rounded, color: currentOverlayControlsColor, size: 36),
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                _startHideControlsTimer();
                              },
                            )
                          else
                            const SizedBox(width: 50),

                          if (_currentPage < widget.steps.length - 1)
                            IconButton(
                              icon: Icon(Icons.arrow_forward_ios_rounded, color: currentOverlayControlsColor, size: 36),
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                _startHideControlsTimer();
                              },
                            )
                          else
                            const SizedBox(width: 50),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPage(RecipeStep step, int stepNumber, bool useLightTheme) {
    final hasImage = step.imageUrl != null && step.imageUrl!.isNotEmpty;

    // Debugging
    if (kDebugMode) {
      print("CookMode: Rendering step $stepNumber. HasImage: $hasImage. Text length: ${step.text.length}");
      if (step.text.isEmpty) print("WARNING: Step $stepNumber has EMPTY text!");
    }

    // Use AppTheme constants directly for clarity
    final Color pageBackgroundColor = useLightTheme ? AppTheme.lightBackground : AppTheme.darkBackground;
    final Color cardBackgroundColor = useLightTheme ? AppTheme.lightSurface : AppTheme.darkSurface;
    final Color cardTextColor = useLightTheme ? AppTheme.lightOnSurface : AppTheme.darkOnSurface;
    final Color stepNumberColor = useLightTheme ? Theme.of(context).colorScheme.primary : AppTheme.darkPrimaryColor;
    final Color imagePlaceholderColor = useLightTheme ? Colors.grey[200]! : Colors.grey[900]!;
    final Color imageErrorIconColor = Colors.grey[500]!;

    return Container(
      color: pageBackgroundColor,
      padding: EdgeInsets.only(
          top: _showControls ? 60 : 16,
          bottom: _showControls ? 60 : 16,
          left: 24,
          right: 24
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'STEP $stepNumber',
                style: TextStyle(
                  color: stepNumberColor.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: hasImage
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.network(
                              step.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: imagePlaceholderColor,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.broken_image, size: 50, color: imageErrorIconColor),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildTextContainer(step.text, cardBackgroundColor, cardTextColor, useLightTheme),
                      ),
                    ],
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildTextContainer(step.text, cardBackgroundColor, cardTextColor, useLightTheme),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContainer(String text, Color bgColor, Color textColor, bool useLightTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: useLightTheme ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: SingleChildScrollView(
        child: Text(
          text.isEmpty ? "No instructions provided for this step." : text,
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            height: 1.6,
          ),
          textAlign: text.isEmpty ? TextAlign.center : TextAlign.start,
        ),
      ),
    );
  }
}
