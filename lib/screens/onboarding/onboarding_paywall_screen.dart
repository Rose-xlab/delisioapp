// lib/screens/onboarding/onboarding_paywall_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // <<< ADDED THIS IMPORT

// Assuming relative paths from lib/screens/onboarding/
import '../../constants/myofferings.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/subscription.dart';
import '../../widgets/profile/subscription_plan_card.dart';
import '../../config/sentry_config.dart';

class OnboardingPaywallScreen extends StatefulWidget {
  const OnboardingPaywallScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingPaywallScreen> createState() => _OnboardingPaywallScreenState();
}

class _OnboardingPaywallScreenState extends State<OnboardingPaywallScreen> {
  bool _isLoading = false;

  Future<void> _completeOnboardingAndNavigate() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    addBreadcrumb(message: 'User completing onboarding from paywall screen.', category: 'onboarding');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.token != null) {
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .revenueCatSubscriptionStatus(authProvider.token!);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/app');
      }
    } catch (e) {
      addBreadcrumb(message: 'Error completing onboarding: ${e.toString()}', category: 'onboarding', level: SentryLevel.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving onboarding status: $e')),
        );
        Navigator.of(context).pushReplacementNamed('/app');
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _presentRevenueCatPaywall() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    addBreadcrumb(message: 'User presenting RevenueCat paywall from onboarding.', category: 'onboarding_paywall_action');

    try {
      final PaywallResult result = await RevenueCatUI.presentPaywallIfNeeded(
        MyOfferings.pro.identifier,
        displayCloseButton: true,
      );
      addBreadcrumb(message: 'RevenueCatUI.presentPaywallIfNeeded result: ${result.name}', category: 'onboarding_paywall_action');
      debugPrint('Onboarding Paywall result from RevenueCatUI: ${result.name}');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

      if (authProvider.isAuthenticated && authProvider.token != null) {
        await subscriptionProvider.revenueCatSubscriptionStatus(authProvider.token!);
      } else {
        try {
          // This line was causing the error if 'purchases_flutter' was not imported
          final customerInfo = await Purchases.getCustomerInfo();
          subscriptionProvider.updateLocalRevenueCatStatus(customerInfo);
        } catch (e) {
          debugPrint("Error fetching CustomerInfo for anonymous user after paywall: $e");
        }
      }

      await _completeOnboardingAndNavigate();

    } catch (e) {
      addBreadcrumb(message: 'Error presenting RevenueCat paywall: ${e.toString()}', category: 'onboarding_paywall_action', level: SentryLevel.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not display subscription options: ${e.toString()}')),
        );
      }
      await _completeOnboardingAndNavigate();
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

    final List<SubscriptionPlan> proPlansToShow = subscriptionProvider.plans
        .where((plan) => plan.tier == SubscriptionTier.pro)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock Pro'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Icon(
                  Icons.rocket_launch_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Go Pro!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Unlock all premium features and supercharge your cooking experience with one of our Pro plans.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.75),
                    height: 1.4
                ),
              ),
              const SizedBox(height: 28),

              if (proPlansToShow.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Pro plan details are currently unavailable. You can skip for now.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: proPlansToShow.length,
                  itemBuilder: (context, index) {
                    final plan = proPlansToShow[index];
                    return SubscriptionPlanCard(
                      plan: plan,
                      isCurrentPlan: false,
                      buttonText: 'Choose ${plan.name}',
                      onSubscribe: (selectedPlan) {
                        _presentRevenueCatPaywall();
                      },
                    );
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                ),

              const SizedBox(height: 28),

              if (proPlansToShow.isNotEmpty)
                ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart_checkout_rounded),
                  label: const Text('View Purchase Options'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _presentRevenueCatPaywall,
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _completeOnboardingAndNavigate,
                child: Text(
                  'Skip for Now & Continue to App',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}