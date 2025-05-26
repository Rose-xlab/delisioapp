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
      name: 'Pro Weekly',
      description: 'Unlock all features with Pro weekly',
      price: 10.00,
      currency: 'USD',
      interval: 'week',
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
      planIdentifier: 'pro-weekly', // This should match your Stripe Price ID or equivalent
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
    SubscriptionPlan(
      tier: SubscriptionTier.pro,
      name: 'Pro Annual',
      description: 'Get the best value with Pro annually',
      price: 179.99,
      currency: 'USD',
      interval: 'year',
      features: [
        'Unlimited recipe generations',
        'HD image quality',
        'Full access to recipe library',
        'Priority chat assistance',
        'Save unlimited favorite recipes',
        'Exclusive premium recipes (now Pro)',
        'Custom recipe modifications',
        'All features unlimited',
        'Discounted annual rate (save \$60/year)',
        'Unlimited chat conversations', // Example feature
      ],
      planIdentifier: 'pro-annual', // This should match your Stripe Price ID or equivalent
    ),
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
  CustomerInfo? customerInfo; // Store it for later use

  String? _package = "free"; // Holds the current RevenueCat package identifier

  String? get package => _package;

  Future<void> revenueCatSubscriptionStatus(String token) async {
    bool previousProStatus = _isProSubscriber;
    bool currentProStatus = false;
    CustomerInfo? customerInfo;

    try {
      customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.all[MyOfferings.pro];

      debugPrint("==================================== SUB STATUS ========================");
      debugPrint(customerInfo.toString());

      // Check if the entitlement exists and then if it's active
      if (entitlement != null && entitlement.isActive == true) {
        currentProStatus = true;
        // Assign the RevenueCat package identifier
        _package = entitlement.productIdentifier; // This is the RevenueCat product/package id
        if (kDebugMode) {
          print("SubscriptionProvider: RevenueCat entitlement '${MyOfferings.pro}' is ACTIVE. Package: $_package");
        }
      } else {
        currentProStatus = false;
        _package = null; // No active package
        if (kDebugMode) {
          print("SubscriptionProvider: RevenueCat entitlement '${MyOfferings.pro}' is NOT active or does not exist.");
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint("SubscriptionProvider: Error fetching RevenueCat CustomerInfo: ${e.toString()}");
      }
      currentProStatus = false;
      _package = null;
      captureException(e, stackTrace: stackTrace, hintText: 'Error in revenueCatSubscriptionStatus (Fetch)');
      customerInfo = null;
    }


    // Only try to sync if we successfully fetched CustomerInfo
    if (customerInfo != null) {
      try {
        // --- Get User ID and Token ---
        // You NEED to implement these functions to get the
        // currently authenticated user's ID and auth token.


        if (token == null) {
          print("SubscriptionProvider: Cannot sync - Auth Token missing.");
        } else {
          final entitlement = customerInfo.entitlements.all[MyOfferings.pro];
          final bool isActive = entitlement?.isActive ?? false;

          // Map RevenueCat data to your backend's format
          final String tier = isActive ? 'pro' : 'free'; // <-- Adjust to match your backend tiers
          final String status = isActive ? 'active' : 'inactive'; // <-- Or map more finely if needed

          // Use .toIso8601String() and handle nulls.
          final String? currentPeriodStart = entitlement?.latestPurchaseDate;
          final String? currentPeriodEnd = entitlement?.expirationDate;

          // If willRenew is false, it means the user has cancelled.
          // We assume if willRenew is null or true, it's not cancelled.
          final bool cancelAtPeriodEnd = !(entitlement?.willRenew ?? true);

          if (kDebugMode) {
            print("SubscriptionProvider: Syncing to backend - Tier: $tier, Status: $status, Start: $currentPeriodStart, End: $currentPeriodEnd, Cancel?: $cancelAtPeriodEnd");
          }

          // Call the updated subscriptionSyc function

          await _subscriptionService.subscriptionSync(
            tier: tier,
            status: status,
            currentPeriodStart: currentPeriodStart,
            currentPeriodEnd: currentPeriodEnd,
            cancelAtPeriodEnd: cancelAtPeriodEnd,
            token: token,
          );

          if (kDebugMode) {
            print("SubscriptionProvider: Backend sync attempt finished.");
          }
        }
      } catch (e, stackTrace) {
        // Handle errors during the API call itself
        if (kDebugMode) {
          debugPrint("SubscriptionProvider: Error syncing subscription to backend: ${e.toString()}");
        }
        captureException(e, stackTrace: stackTrace, hintText: 'Error calling subscriptionSyc'); // MODIFIED
      }
    }
    // --- End of NEW ---

    // Only update and notify if the status has actually changed
    if (previousProStatus != currentProStatus) {
      _isProSubscriber = currentProStatus;
      notifyListeners();
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
      captureException(e, stackTrace: stackTrace, hintText: 'Error loading backend subscription status'); // MODIFIED
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
      captureException(e, stackTrace: stackTrace, hintText: 'Error subscribing to plan'); // MODIFIED
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
      captureException(e, stackTrace: stackTrace, hintText: 'Error managing subscription'); // MODIFIED
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
        await revenueCatSubscriptionStatus(token);
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
      captureException(e, stackTrace: stackTrace, hintText: 'Error cancelling subscription'); // MODIFIED
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