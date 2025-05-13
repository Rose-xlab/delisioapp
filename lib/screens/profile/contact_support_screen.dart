// lib/screens/profile/contact_support_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for Clipboard
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import FontAwesome
import '../../providers/auth_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({Key? key}) : super(key: key);

  @override
  _ContactSupportScreenState createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  String _appVersion = 'Loading...';
  // Note: Getting actual device info requires 'device_info_plus' package
  // Keeping the structure but with a placeholder for now.
  final String _deviceInfo = 'Device Info Unavailable'; // Placeholder or implement device_info_plus

  // --- Removed Form related variables ---
  // final _formKey = GlobalKey<FormState>();
  // final _subjectController = TextEditingController();
  // final _messageController = TextEditingController();
  // bool _isLoading = false;
  // final List<String> _supportCategories = [...];
  // String _selectedCategory = 'Technical Issue';
  // --- End Removed ---

  final String supportEmail = 'support@kitchenassistant.com';
  final String facebookUrl = 'https://facebook.com/yourpage'; // TODO: Replace with your actual URL
  final String instagramUrl = 'https://instagram.com/yourprofile'; // TODO: Replace with your actual URL
  final String tiktokUrl = 'https://tiktok.com/@youraccount'; // TODO: Replace with your actual URL


  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    // Optionally load device info here if using device_info_plus
  }

  @override
  void dispose() {
    // --- Removed Controller disposals ---
    // _subjectController.dispose();
    // _messageController.dispose();
    // --- End Removed ---
    super.dispose();
  }

  Future<void> _loadAppInfo() async {
    if (!mounted) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      print('Error loading app info: $e');
      if (mounted) {
        setState(() {
          _appVersion = 'Error loading version';
        });
      }
    }
  }

  // Helper function to launch URLs safely
  Future<void> _launchSocialUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Optionally show an error message if launch fails
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
      print('Could not launch $urlString');
    }
  }

  // --- Removed _launchEmail, _showManualEmailInstructions, _submitForm ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false); // Get auth provider
    final user = authProvider.user; // Get user info
    final userEmail = user?.email ?? 'Not logged in'; // Get user email if available
    final userInfo = user != null ? 'User ID: ${user.id}' : 'User: Not logged in'; // Get user ID if available

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20), // Increased padding slightly
        child: Column( // Removed Form widget
          crossAxisAlignment: CrossAxisAlignment.center, // Center content
          children: [
            Icon(
              Icons.support_agent, // Or Icons.contact_support
              size: 60,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Get in Touch',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Have questions or need help? Reach out to us!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32), // Spacing before email

            // --- Email Section ---
            const Text(
              'Contact Us Via Email:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: supportEmail),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email address copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email_outlined, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      supportEmail,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        // decoration: TextDecoration.underline, // Optional underline
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40), // Spacing before social icons

            // --- Social Media Section ---
            const Text(
              'Follow Us:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(
                  icon: FontAwesomeIcons.facebook,
                  url: facebookUrl,
                  color: const Color(0xFF1877F2), // Facebook blue
                ),
                const SizedBox(width: 24),
                _buildSocialButton(
                  icon: FontAwesomeIcons.instagram,
                  url: instagramUrl,
                  color: const Color(0xFFE4405F), // Instagram pink/purple
                ),
                const SizedBox(width: 24),
                _buildSocialButton(
                  icon: FontAwesomeIcons.tiktok,
                  url: tiktokUrl,
                  color: Colors.black, // TikTok black (or add alternating colors)
                ),
              ],
            ),
            const SizedBox(height: 40), // Spacing before app info

            // --- Device & App Info ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                // border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Diagnostic Information',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('App Version:', _appVersion),
                  _buildInfoRow('Device:', _deviceInfo), // Add actual device info if needed
                  _buildInfoRow('User Info:', userInfo),
                  _buildInfoRow('User Email:', userEmail),
                  const SizedBox(height: 4),
                  Text(
                    '(This info helps us diagnose issues faster)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Padding at the bottom
          ],
        ),
      ),
    );
  }

  // Helper Widget for Social Media Icons
  Widget _buildSocialButton({required IconData icon, required String url, required Color color}) {
    return IconButton(
      icon: FaIcon(icon), // Use FaIcon for FontAwesome icons
      iconSize: 30,
      color: color,
      tooltip: 'Visit our ${icon.toString().split('.').last} page', // Basic tooltip
      onPressed: () => _launchSocialUrl(url),
    );
    // Alternative using InkWell for custom shape/background:
    // return InkWell(
    //   onTap: () => _launchSocialUrl(url),
    //   borderRadius: BorderRadius.circular(50), // Make it circular
    //   child: Padding(
    //     padding: const EdgeInsets.all(12.0),
    //     child: FaIcon(icon, size: 30, color: color),
    //   ),
    // );
  }

  // Helper Widget for info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}