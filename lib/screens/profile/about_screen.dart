// lib/screens/profile/about_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${packageInfo.version} (${packageInfo.buildNumber})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = 'Unknown';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Kitchen Assistant'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (ctx, err, _) => Icon(
                    Icons.restaurant,
                    size: 60,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Name
            Text(
              'Kitchen Assistant',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),

            // App Description
            Text(
              'Your AI-Powered Cooking Assistant',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // App Version
            Text(
              'Version $_version',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // App Description
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Kitchen Assistant combines the power of artificial intelligence with your culinary needs to create an unparalleled cooking experience. Generate custom recipes, get cooking advice, and explore new dishes tailored to your preferences.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),




            // Legal links
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              children: [
                TextButton(
                  onPressed: () => _launchUrl('https://delso.vercel.app/terms'),
                  child: const Text('Terms of Service'),
                ),
                TextButton(
                  onPressed: () => _launchUrl('https://delso.vercel.app/privacy'),
                  child: const Text('Privacy Policy'),
                ),

              ],
            ),

            const SizedBox(height: 24),

            // Copyright
            Text(
              '© ${DateTime.now().year} Kitchen Assistant. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTechLogo(String name, String assetPath, IconData fallbackIcon) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              assetPath,
              width: 40,
              height: 40,
              errorBuilder: (ctx, err, _) => Icon(
                fallbackIcon,
                size: 30,
                color: theme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}