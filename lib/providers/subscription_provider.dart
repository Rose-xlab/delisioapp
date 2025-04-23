// lib/providers/subscription_provider.dart
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../config/sentry_config.dart'; // Import the Sentry config

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();

  SubscriptionInfo? _subscriptionInfo;
  bool _isLoading = false;
  String? _error;

  // Predefined subscription plans
  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      tier: SubscriptionTier.free,
      name: 'Free',
      description: 'Basic access to Delisio',
      price: 0,
      currency: 'USD',
      interval: 'month',
      features: [
        '1 recipe generation per month',
        'Standard image quality',
        'Access to recipe library',
        'Basic chat assistance',
      ],
    ),
    SubscriptionPlan(
      tier: SubscriptionTier.basic,
      name: 'Basic',
      description: 'Enhanced cooking experience',
      price: 4.99,
      currency: 'USD',
      interval: 'month',
      features: [
        '5 recipe generations per month',
        'HD image quality',
        'Full access to recipe library',
        'Priority chat assistance',
        'Save unlimited favorite recipes',
      ],
    ),
    SubscriptionPlan(
      tier: SubscriptionTier.premium,
      name: 'Premium',
      description: 'Ultimate culinary companion',
      price: 9.99,
      currency: 'USD',
      interval: 'month',
      features: [
        'Unlimited recipe generations',
        'HD image quality',
        'Full access to recipe library',
        'Priority chat assistance',
        'Save unlimited favorite recipes',
        'Exclusive premium recipes',
        'Custom recipe modifications',
      ],
    ),
  ];

  // Getters
  SubscriptionInfo? get subscriptionInfo => _subscriptionInfo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SubscriptionPlan> get plans => _plans;

  // Check if user is on free plan
  bool get isFreeTier => _subscriptionInfo?.tier == SubscriptionTier.free;

  // Check if user is on paid plan
  bool get isPaidTier => _subscriptionInfo?.tier == SubscriptionTier.basic ||
      _subscriptionInfo?.tier == SubscriptionTier.premium;

  // Load subscription status
  Future<void> loadSubscriptionStatus(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add breadcrumb for loading subscription status
    addBreadcrumb(
      message: 'Loading subscription status',
      category: 'subscription',
    );

    try {
      final info = await _subscriptionService.getSubscriptionStatus(token);
      _subscriptionInfo = info;

      // Add breadcrumb with subscription details
      addBreadcrumb(
        message: 'Subscription status loaded',
        category: 'subscription',
        data: {
          'tier': info.tier.toString(),
          'status': info.status.toString(),
          'recipeGenerationsRemaining': info.recipeGenerationsRemaining,
        },
      );
    } catch (e) {
      _error = e.toString();
      print('Error loading subscription: $_error');

      // Log to Sentry
      captureException(e,
          stackTrace: StackTrace.current,
          hint: 'Error loading subscription status'
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Subscribe to a plan
  Future<bool> subscribeToPlan(String token, SubscriptionTier tier) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add breadcrumb for subscription attempt
    addBreadcrumb(
      message: 'Subscribing to plan',
      category: 'subscription',
      data: {'tier': tier.toString()},
    );

    try {
      // Create dynamic success and cancel URLs
      // In a real app, you might want to handle these with deep links
      final successUrl = 'https://delisio.app/subscription/success';
      final cancelUrl = 'https://delisio.app/subscription/cancel';

      final checkoutUrl = await _subscriptionService.createCheckoutSession(
        token,
        tier,
        successUrl,
        cancelUrl,
      );

      // Launch URL in browser
      final url = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        // Add breadcrumb for successful checkout launch
        addBreadcrumb(
          message: 'Launched checkout URL',
          category: 'subscription',
          data: {'tier': tier.toString()},
        );

        return true;
      } else {
        throw Exception('Could not launch checkout URL');
      }
    } catch (e) {
      _error = e.toString();
      print('Error subscribing to plan: $_error');

      // Log to Sentry
      captureException(e,
          stackTrace: StackTrace.current,
          hint: 'Error subscribing to plan'
      );

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Manage subscription
  Future<bool> manageSubscription(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add breadcrumb for managing subscription
    addBreadcrumb(
      message: 'Opening subscription management portal',
      category: 'subscription',
    );

    try {
      final returnUrl = 'https://delisio.app/subscription/return';

      final portalUrl = await _subscriptionService.createCustomerPortalSession(
        token,
        returnUrl,
      );

      // Launch URL in browser
      final url = Uri.parse(portalUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        // Add breadcrumb for successful portal launch
        addBreadcrumb(
          message: 'Launched customer portal',
          category: 'subscription',
        );

        return true;
      } else {
        throw Exception('Could not launch customer portal URL');
      }
    } catch (e) {
      _error = e.toString();
      print('Error managing subscription: $_error');

      // Log to Sentry
      captureException(e,
          stackTrace: StackTrace.current,
          hint: 'Error managing subscription'
      );

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cancel subscription
  Future<bool> cancelSubscription(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Add breadcrumb for cancellation attempt
    addBreadcrumb(
      message: 'Cancelling subscription',
      category: 'subscription',
    );

    try {
      final success = await _subscriptionService.cancelSubscription(token);

      if (success && _subscriptionInfo != null) {
        // Update local subscription info to reflect cancellation
        _subscriptionInfo = SubscriptionInfo(
          tier: _subscriptionInfo!.tier,
          status: _subscriptionInfo!.status, // Status might not change immediately
          currentPeriodEnd: _subscriptionInfo!.currentPeriodEnd,
          recipeGenerationsLimit: _subscriptionInfo!.recipeGenerationsLimit,
          recipeGenerationsUsed: _subscriptionInfo!.recipeGenerationsUsed,
          recipeGenerationsRemaining: _subscriptionInfo!.recipeGenerationsRemaining,
          cancelAtPeriodEnd: true, // Set this to true
        );

        // Add breadcrumb for successful cancellation
        addBreadcrumb(
          message: 'Subscription cancelled successfully',
          category: 'subscription',
          data: {'tier': _subscriptionInfo!.tier.toString()},
        );
      }

      return success;
    } catch (e) {
      _error = e.toString();
      print('Error canceling subscription: $_error');

      // Log to Sentry
      captureException(e,
          stackTrace: StackTrace.current,
          hint: 'Error cancelling subscription'
      );

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset error
  void resetError() {
    _error = null;
    notifyListeners();
  }
}