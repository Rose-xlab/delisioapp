//C:\Users\mukas\StudioProjects\delisio\lib\providers\subscription_provider.dart

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/subscription.dart'; // Assuming this correctly defines SubscriptionInfo, SubscriptionTier, SubscriptionPlan
import '../services/subscription_service.dart';
import '../config/sentry_config.dart'; // Import the Sentry config
import '../constants/myofferings.dart'; // Import MyOfferings

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();

  SubscriptionInfo? _subscriptionInfo;
  bool _isLoading = false;
  String? _error;

  // RevenueCat subscription status
  bool _isProSubscriber = false; // Default to false

  // Predefined subscription plans
  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      tier: SubscriptionTier.free,
      name: 'Free',
      description: 'Basic access to Kitchen Assistant',
      price: 0,
      currency: 'USD',
      interval: 'month', // Or appropriate interval for free if it matters
      features: [
        '1 recipe generation per month', // This should ideally come from backend config
        'Standard image quality',
        'Access to recipe library',
        'Basic chat assistance',
        // 'Limited to 3 active chat conversations', // Example, if you want to list it
      ],
      planIdentifier: 'free', // Or null if not needed for checkout
    ),
    SubscriptionPlan(
      tier: SubscriptionTier.pro,
      name: 'Pro Monthly',
      description: 'Unlock all features with Pro monthly',
      price: 20.00,
      currency: 'USD',
      interval: 'month',
      features: [
        'Unlimited recipe generations',
        'HD image quality',
        'Full access to recipe library',
        'Priority chat assistance',
        'Save unlimited favorite recipes',
        'Exclusive premium recipes (now Pro)',
        'Custom recipe modifications',
        'All features unlimited',
        'Unlimited chat conversations', // Example feature
      ],
      planIdentifier: 'pro-monthly', // This should match your Stripe Price ID or equivalent
    ),
    // SubscriptionPlan(
    //   tier: SubscriptionTier.pro,
    //   name: 'Pro Annual',
    //   description: 'Get the best value with Pro annually',
    //   price: 180.00,
    //   currency: 'USD',
    //   interval: 'year',
    //   features: [
    //     'Unlimited recipe generations',
    //     'HD image quality',
    //     'Full access to recipe library',
    //     'Priority chat assistance',
    //     'Save unlimited favorite recipes',
    //     'Exclusive premium recipes (now Pro)',
    //     'Custom recipe modifications',
    //     'All features unlimited',
    //     'Discounted annual rate (save \$60/year)',
    //     'Unlimited chat conversations', // Example feature
    //   ],
    //   planIdentifier: 'pro-annual', // This should match your Stripe Price ID or equivalent
    // ),
  ];

  // Getters
  SubscriptionInfo? get subscriptionInfo => _subscriptionInfo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SubscriptionPlan> get plans => _plans;

  // Check if user is on free plan (based on backend info)
  bool get isFreeTier => _subscriptionInfo?.tier == SubscriptionTier.free;

  // Check if user is on paid plan (based on backend info)
  bool get isPaidTier => _subscriptionInfo?.tier == SubscriptionTier.pro;

  // RevenueCat specific getter
  bool get isProSubscriber => _isProSubscriber;

  // Method to check RevenueCat subscription status
  Future<void> revenueCatSubscriptionStatus() async {
    bool previousProStatus = _isProSubscriber; // Store previous status
    bool currentProStatus = false;           // Assume false until proven otherwise

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // Check if the entitlement (e.g., "TestPro") exists and then if it's active
      if (customerInfo.entitlements.all[MyOfferings.pro] != null &&
          customerInfo.entitlements.all[MyOfferings.pro]!.isActive == true) {
        currentProStatus = true;
        if (kDebugMode) {
          print("SubscriptionProvider: RevenueCat entitlement '${MyOfferings.pro}' is ACTIVE.");
        }
      } else {
        currentProStatus = false; // User is not pro or entitlement is not active
        if (kDebugMode) {
          print("SubscriptionProvider: RevenueCat entitlement '${MyOfferings.pro}' is NOT active or does not exist.");
          print("  All entitlements: ${customerInfo.entitlements.all.keys.join(', ')}");
          if (customerInfo.entitlements.all[MyOfferings.pro] != null) {
            print("  '${MyOfferings.pro}' isActive: ${customerInfo.entitlements.all[MyOfferings.pro]!.isActive}");
          }
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint("SubscriptionProvider: Error fetching RevenueCat CustomerInfo: ${e.toString()}");
      }
      currentProStatus = false; // Default to false on any error
      captureException(e, stackTrace: stackTrace, hint: 'Error in revenueCatSubscriptionStatus');
    }

    // Only update and notify if the status has actually changed
    if (previousProStatus != currentProStatus) {
      _isProSubscriber = currentProStatus;
      if (kDebugMode) {
        print("SubscriptionProvider: isProSubscriber status changed to $_isProSubscriber. Notifying listeners.");
      }
      notifyListeners(); // CRITICAL: Notify listeners of the change
    } else {
      if (kDebugMode) {
        print("SubscriptionProvider: isProSubscriber status ($_isProSubscriber) did not change. No notification needed.");
      }
    }
  }

  // Load subscription status from your backend
  Future<void> loadSubscriptionStatus(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify for loading start

    addBreadcrumb(
      message: 'Loading subscription status (backend)',
      category: 'subscription',
    );

    try {
      final info = await _subscriptionService.getSubscriptionStatus(token);
      _subscriptionInfo = info;
      if (kDebugMode) {
        print("SubscriptionProvider: Backend subscription status loaded - Tier: ${info.tier}, Gens Remaining: ${info.recipeGenerationsRemaining}");
      }
      addBreadcrumb(
        message: 'Backend subscription status loaded',
        category: 'subscription',
        data: {
          'tier': info.tier.toString(),
          'status': info.status.toString(),
          'recipeGenerationsRemaining': info.recipeGenerationsRemaining,
        },
      );
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      if (kDebugMode) {
        print('SubscriptionProvider: Error loading backend subscription: $_error');
      }
      captureException(e, stackTrace: stackTrace, hint: 'Error loading backend subscription status');
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify for loading end and data update (or error)
    }
  }

  // Subscribe to a plan (via Stripe Checkout)
  Future<bool> subscribeToPlan(String token, SubscriptionPlan plan) async {
    if (plan.planIdentifier == null || plan.planIdentifier == 'free') {
      _error = 'Cannot subscribe to this plan type via checkout.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    addBreadcrumb(
      message: 'Attempting to subscribe to plan',
      category: 'subscription',
      data: {'planIdentifier': plan.planIdentifier!},
    );

    try {
      // These URLs should be configured in your environment variables or a config file
      final successUrl = 'https://delisio.app/subscription/success'; // Replace with your actual success URL
      final cancelUrl = 'https://delisio.app/subscription/cancel';   // Replace with your actual cancel URL

      final checkoutUrl = await _subscriptionService.createCheckoutSession(
        token,
        plan.planIdentifier!, // This should be the Stripe Price ID
        successUrl,
        cancelUrl,
      );

      final url = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        addBreadcrumb(
          message: 'Launched Stripe checkout URL',
          category: 'subscription',
          data: {'planIdentifier': plan.planIdentifier!},
        );
        return true;
      } else {
        throw Exception('Could not launch checkout URL: $checkoutUrl');
      }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      if (kDebugMode) {
        print('SubscriptionProvider: Error subscribing to plan: $_error');
      }
      captureException(e, stackTrace: stackTrace, hint: 'Error subscribing to plan');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Manage subscription (via Stripe Customer Portal)
  Future<bool> manageSubscription(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    addBreadcrumb(
      message: 'Opening Stripe customer portal',
      category: 'subscription',
    );

    try {
      // This URL should be configured in your environment variables or a config file
      final returnUrl = 'https://delisio.app/subscription/return'; // Replace with your actual return URL

      final portalUrl =
      await _subscriptionService.createCustomerPortalSession(
        token,
        returnUrl,
      );

      final url = Uri.parse(portalUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        addBreadcrumb(
          message: 'Launched Stripe customer portal',
          category: 'subscription',
        );
        return true;
      } else {
        throw Exception('Could not launch customer portal URL: $portalUrl');
      }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      if (kDebugMode) {
        print('SubscriptionProvider: Error managing subscription: $_error');
      }
      captureException(e, stackTrace: stackTrace, hint: 'Error managing subscription');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cancel subscription (via your backend)
  Future<bool> cancelSubscription(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    addBreadcrumb(
      message: 'Attempting to cancel subscription (backend)',
      category: 'subscription',
    );

    try {
      final success = await _subscriptionService.cancelSubscription(token);

      if (success) {
        // Reload subscription status from backend to get updated info
        await loadSubscriptionStatus(token);
        // Also refresh RevenueCat status, as backend cancellation might affect entitlements
        await revenueCatSubscriptionStatus();
        addBreadcrumb(
          message: 'Subscription cancelled successfully (backend)',
          category: 'subscription',
          data: {'newBackendTier': _subscriptionInfo?.tier.toString(), 'newRCProStatus': _isProSubscriber.toString()},
        );
      }
      return success;
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      if (kDebugMode) {
        print('SubscriptionProvider: Error canceling subscription: $_error');
      }
      captureException(e, stackTrace: stackTrace, hint: 'Error cancelling subscription');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset error message
  void resetError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}