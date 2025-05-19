// lib/widgets/common/upgrade_prompt_dialog.dart
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // For RevenueCat Paywall
import 'package:kitchenassistant/constants/myofferings.dart'; // Import MyOfferings

class UpgradePromptDialog extends StatelessWidget {
  final String titleText;
  final String messageText;
  final List<String> proFeatures;

  const UpgradePromptDialog({
    Key? key,
    this.titleText = 'Unlock Pro Features!',
    required this.messageText,
    this.proFeatures = const [
      'Unlimited recipe generations',
      'Unlimited AI chat replies',
      'Enhanced HD image quality',
      'Full access to recipe library',
      'Priority chat assistance',
      'All current & future features unlocked',
    ],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final onSurfaceVariantColor = theme.colorScheme.onSurfaceVariant;
    final successColor = Colors.green.shade600;

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      elevation: isDarkMode ? 4.0 : 8.0,
      titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      actionsPadding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
      // Use a Stack to allow positioning the close button on top
      content: Stack(
        clipBehavior: Clip.none, // Allow close button to be slightly outside if needed
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rocket_launch_outlined,
                    color: primaryColor,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      titleText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // We will place the close button outside this Row, using the Stack
                ],
              ),
              const SizedBox(height: 8), // Reduced space as title is now part of content Stack
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55, // Adjusted max height
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        messageText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          color: onSurfaceColor.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Upgrade to Pro to enjoy:',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onSurfaceColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...proFeatures.map((feature) =>
                          _buildFeatureRow(Icons.check_circle, feature, theme, successColor))
                          .toList(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Positioned Close Button
          Positioned(
            top: -12.0, // Adjust to position correctly relative to the new content structure
            right: -12.0, // Adjust to position correctly
            child: Material( // Adding Material for InkWell splash effect
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18), // Make the tap area a bit larger and circular
                onTap: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Container(
                  padding: const EdgeInsets.all(6), // Padding around the icon
                  decoration: BoxDecoration(
                    // Optional: add a subtle background if needed for better visibility
                    // color: surfaceColor.withOpacity(isDarkMode ? 0.5 : 0.1),
                    // borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.close,
                    color: onSurfaceVariantColor.withOpacity(0.7),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Nullify the title here as it's now part of the content Stack for positioning the close button
      title: null,
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.workspace_premium_outlined, size: 20),
              label: const Text('View Pro Plans'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: onPrimaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                elevation: 2.0,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                RevenueCatUI.presentPaywallIfNeeded(MyOfferings.pro);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  color: onSurfaceVariantColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, ThemeData theme, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}