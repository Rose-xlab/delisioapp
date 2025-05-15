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

  ////////// revenuecat subscription status ///////////////////////////////////////
  bool _isProSubscriber = false;

  // Predefined subscription plans
  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      tier: SubscriptionTier.free,
      name: 'Free',
      description: 'Basic access to Delisio',
      price: 0,
      currency: 'USD',
      interval: 'month', // Or appropriate interval for free if it matters
      features: [
        '1 recipe generation per month',
        'Standard image quality',
        'Access to recipe library',
        'Basic chat assistance',
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
      ],
      planIdentifier: 'pro-monthly',
    ),
    SubscriptionPlan(
      tier: SubscriptionTier.pro,
      name: 'Pro Annual',
      description: 'Get the best value with Pro annually',
      price: 180.00, // MODIFIED: Annual price updated from $200 to $180
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
        'Discounted annual rate (save \$60/year)', // Updated feature to reflect new savings
      ],
      planIdentifier: 'pro-annual',
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
  bool get isPaidTier => _subscriptionInfo?.tier == SubscriptionTier.pro;




  //////////////////////////////// REVENUECAT //////////////////////////////////////
    //when using revenuecat
  bool get isProSubscriber => _isProSubscriber;

  Future<void> revenueCatSubscriptionStatus() async {
      try{

        

      }
      catch(e){
         debugPrint(e.toString());
      }
  }

  // Load subscription status
  Future<void> loadSubscriptionStatus(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    addBreadcrumb(
      message: 'Loading subscription status',
      category: 'subscription',
    );

    try {
      final info = await _subscriptionService.getSubscriptionStatus(token);
      _subscriptionInfo = info;

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
      captureException(e,
          stackTrace: StackTrace.current,
          hint: 'Error loading subscription status');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      message: 'Subscribing to plan',
      category: 'subscription',
      data: {'planIdentifier': plan.planIdentifier!},
    );

    try {
      final successUrl = 'https://delisio.app/subscription/success';
      final cancelUrl = 'https://delisio.app/subscription/cancel';

      final checkoutUrl = await _subscriptionService.createCheckoutSession(
        token,
        plan.planIdentifier!,
        successUrl,
        cancelUrl,
      );

      final url = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        addBreadcrumb(
          message: 'Launched checkout URL',
          category: 'subscription',
          data: {'planIdentifier': plan.planIdentifier!},
        );
        return true;
      } else {
        throw Exception('Could not launch checkout URL');
      }
    } catch (e) {
      _error = e.toString();
      print('Error subscribing to plan: $_error');
      captureException(e,
          stackTrace: StackTrace.current, hint: 'Error subscribing to plan');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> manageSubscription(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    addBreadcrumb(
      message: 'Opening subscription management portal',
      category: 'subscription',
    );

    try {
      final returnUrl = 'https://delisio.app/subscription/return';
      final portalUrl =
      await _subscriptionService.createCustomerPortalSession(
        token,
        returnUrl,
      );

      final url = Uri.parse(portalUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
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
      captureException(e,
          stackTrace: StackTrace.current, hint: 'Error managing subscription');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelSubscription(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    addBreadcrumb(
      message: 'Cancelling subscription',
      category: 'subscription',
    );

    try {
      final success = await _subscriptionService.cancelSubscription(token);

      if (success && _subscriptionInfo != null) {
        _subscriptionInfo = SubscriptionInfo(
          tier: _subscriptionInfo!.tier,
          status: _subscriptionInfo!.status,
          currentPeriodEnd: _subscriptionInfo!.currentPeriodEnd,
          recipeGenerationsLimit: _subscriptionInfo!.recipeGenerationsLimit,
          recipeGenerationsUsed: _subscriptionInfo!.recipeGenerationsUsed,
          recipeGenerationsRemaining: _subscriptionInfo!.recipeGenerationsRemaining,
          cancelAtPeriodEnd: true,
        );
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
      captureException(e,
          stackTrace: StackTrace.current,
          hint: 'Error cancelling subscription');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetError() {
    _error = null;
    notifyListeners();
  }
}