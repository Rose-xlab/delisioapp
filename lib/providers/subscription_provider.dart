// lib/providers/subscription_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';

// Corrected relative import paths assuming 'delisio' project structure for providers
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../config/sentry_config.dart';
import '../constants/myofferings.dart';

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();

  SubscriptionInfo? _subscriptionInfo;
  bool _isLoading = false;
  String? _error;
  CustomerInfo? _customerInfo;

  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      tier: SubscriptionTier.free,
      name: 'Free',
      description: 'Basic access to Kitchen Assistant',
      price: 0, currency: 'USD', interval: 'month',
      features: [
        'Limited recipe generations (e.g., 1/month)',
        'Limited AI chat replies (e.g., 3/month)',
        'Standard image quality', 'Access to a selection of recipes', 'Basic chat assistance',
      ],
      planIdentifier: 'free',
    ),
    SubscriptionPlan(
      tier: SubscriptionTier.pro, name: 'Pro Weekly', description: 'Unlock all features with Pro weekly',
      price: 10.00, currency: 'USD', interval: 'week',
      features: [
        'Unlimited recipe generations', 'Unlimited AI chat replies', 'HD image quality',
        'Full access to recipe library', 'Priority chat assistance', 'Save unlimited favorite recipes',
        'Exclusive premium recipes', 'Custom recipe modifications',
      ],
      planIdentifier: 'week:r-weekly',
    ),
    SubscriptionPlan(
      tier: SubscriptionTier.pro, name: 'Pro Monthly', description: 'Unlock all features with Pro monthly',
      price: 20.00, currency: 'USD', interval: 'month',
      features: [
        'Unlimited recipe generations', 'Unlimited AI chat replies', 'HD image quality',
        'Full access to recipe library', 'Priority chat assistance', 'Save unlimited favorite recipes',
        'Exclusive premium recipes', 'Custom recipe modifications',
      ],
      planIdentifier: 'rc_pro:rc',
    ),
    SubscriptionPlan(
      tier: SubscriptionTier.pro, name: 'Pro Annual', description: 'Get the best value with Pro annually',
      price: 179.99, currency: 'USD', interval: 'year',
      features: [
        'Unlimited recipe generations', 'Unlimited AI chat replies', 'HD image quality',
        'Full access to recipe library', 'Priority chat assistance', 'Save unlimited favorite recipes',
        'Exclusive premium recipes', 'Custom recipe modifications', 'Discounted annual rate (Best Value!)',
      ],
      planIdentifier: 'rc_annualy:annually',
    ),
  ];

  SubscriptionInfo? get subscriptionInfo => _subscriptionInfo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SubscriptionPlan> get plans => _plans;
  bool get isProSubscriber => _customerInfo?.entitlements.active.containsKey(MyOfferingsExtension.proEntitlement) ?? false;
  CustomerInfo? get customerInfo => _customerInfo;
  String? get package {
    if (_customerInfo != null && isProSubscriber) {
      final entitlement = _customerInfo!.entitlements.all[MyOfferingsExtension.proEntitlement];
      return entitlement?.productIdentifier;
    }
    return null;
  }

  void updateLocalRevenueCatStatus(CustomerInfo customerInfo) {
    _customerInfo = customerInfo;
    debugPrint("SubscriptionProvider: Local RevenueCat CustomerInfo updated. isPro: $isProSubscriber, activeEntitlements: ${customerInfo.entitlements.active.keys.join(',')}, productID: ${customerInfo.entitlements.all[MyOfferingsExtension.proEntitlement]?.productIdentifier}");
    addBreadcrumb( message: 'Local RevenueCat CustomerInfo updated', category: 'subscription_rc_local', data: {'isPro': isProSubscriber, 'activeEntitlements': customerInfo.entitlements.active.keys.join(',')}, level: SentryLevel.info);
    notifyListeners();
  }

  Future<void> revenueCatSubscriptionStatus(String token) async {
    // Check if already loading to prevent concurrent operations
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners(); // Notify loading start

    addBreadcrumb(message: 'Fetching RevenueCat subscription status and syncing', category: 'subscription_rc_sync', level: SentryLevel.info);

    try {
      _customerInfo = await Purchases.getCustomerInfo();
      // Update _isProSubscriber based on the fetched info *before* using it in breadcrumb or sync
      // (The getter already does this, so this is fine)
      notifyListeners(); // Notify that _customerInfo (and thus isProSubscriber) might have changed

      addBreadcrumb(message: 'RevenueCat CustomerInfo fetched', category: 'subscription_rc_sync', data: {'isPro': isProSubscriber, 'activeEntitlements': _customerInfo?.entitlements.active.keys.join(',')}, level: SentryLevel.debug);

      final entitlement = _customerInfo?.entitlements.all[MyOfferingsExtension.proEntitlement];
      final bool isActiveFromRC = entitlement?.isActive ?? false;

      final String tierForBackend = isActiveFromRC ? 'pro' : 'free';
      String statusForBackend = 'inactive';
      if (isActiveFromRC) {
        statusForBackend = entitlement?.periodType == PeriodType.trial ? 'trialing' : 'active';
      }

      final String? currentPeriodStartForBackend = entitlement?.latestPurchaseDate;
      final String? currentPeriodEndForBackend = entitlement?.expirationDate;
      final bool cancelAtPeriodEndForBackend = !(entitlement?.willRenew ?? true);

      debugPrint("SubscriptionProvider: Syncing to backend - Tier: $tierForBackend, Status: $statusForBackend, Start: $currentPeriodStartForBackend, End: $currentPeriodEndForBackend, Cancel@End: $cancelAtPeriodEndForBackend");

      await _subscriptionService.subscriptionSync(
        tier: tierForBackend, status: statusForBackend,
        currentPeriodStart: currentPeriodStartForBackend, currentPeriodEnd: currentPeriodEndForBackend,
        cancelAtPeriodEnd: cancelAtPeriodEndForBackend, token: token,
      );
      addBreadcrumb(message: 'Backend sync with RC data finished', category: 'subscription_rc_sync', level: SentryLevel.info);
      debugPrint("SubscriptionProvider: Backend sync call completed.");

    } catch (e, stackTrace) {
      _error = "Failed to update subscription from source: ${e.toString()}";
      if (kDebugMode) print('SubscriptionProvider: Error in revenueCatSubscriptionStatus (Fetch/Sync): $_error');
      captureException(e, stackTrace: stackTrace, hintText: 'Error in revenueCatSubscriptionStatus (Fetch/Sync)');
      // No notifyListeners here, finally block will handle it
    } finally {
      // Always reload from our backend after attempting a sync or fetching RC info
      // This ensures _subscriptionInfo reflects the canonical state from our DB
      // The loadSubscriptionStatus method will set _isLoading = false and notifyListeners.
      await loadSubscriptionStatus(token);
    }
  }

  Future<void> loadSubscriptionStatus(String token) async {
    _isLoading = true;
    _error = null;
    // Do not notify here if part of a larger flow like revenueCatSubscriptionStatus
    // unless this is the only indicator of loading for this specific operation.
    // For standalone calls, a notifyListeners() here might be ok.
    // However, the finally block will notify.

    addBreadcrumb(message: 'Loading subscription status (backend)', category: 'subscription_backend', level: SentryLevel.info);
    try {
      final info = await _subscriptionService.getSubscriptionStatus(token);
      _subscriptionInfo = info;
      if (info != null) {
        addBreadcrumb(message: 'Backend subscription status loaded', category: 'subscription_backend', data: {'tier': info.tier.toString(), 'status': info.status.toString()}, level: SentryLevel.info);
        debugPrint("SubscriptionProvider: Backend subscription status loaded - Tier: ${info.tier}, Status: ${info.status}, Recipe Rem: ${info.recipeGenerationsRemaining}");
      } else {
        addBreadcrumb(message: 'Backend subscription status returned null', category: 'subscription_backend', level: SentryLevel.warning);
        debugPrint("SubscriptionProvider: Backend subscription status returned null.");
      }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hintText: 'Error loading backend subscription status');
      _subscriptionInfo = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> subscribeToPlan(String token, SubscriptionPlan selectedDisplayPlan) async {
    if (selectedDisplayPlan.planIdentifier == null || selectedDisplayPlan.planIdentifier == 'free') {
      _error = 'This plan cannot be purchased directly.';
      notifyListeners();
      return false;
    }

    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Attempting to subscribe to RevenueCat package', category: 'subscription_rc_purchase', data: {'planIdentifier': selectedDisplayPlan.planIdentifier!});

    try {
      Offerings offerings = await Purchases.getOfferings();
      Package? packageToPurchase;
      Offering? currentOffering = offerings.all[MyOfferings.pro.identifier];

      if (currentOffering != null) {
        packageToPurchase = currentOffering.availablePackages.firstWhereOrNull(
              (pkg) => pkg.storeProduct.identifier == selectedDisplayPlan.planIdentifier,
        );
      } else {
        _error = "No active RevenueCat offering found (ID: ${MyOfferings.pro.identifier}). Please check configuration.";
        debugPrint("SubscriptionProvider: No RC offering found with ID: ${MyOfferings.pro.identifier}");
      }

      if (packageToPurchase == null) {
        _error = "Selected plan ('${selectedDisplayPlan.name}' with product ID '${selectedDisplayPlan.planIdentifier}') not found in the current RevenueCat offering ('${currentOffering?.identifier}'). Check planIdentifiers.";
        if(kDebugMode && currentOffering != null) { currentOffering.availablePackages.forEach((pkg) => print("Available RC Pkg in '${currentOffering?.identifier}': RC Pkg ID: ${pkg.identifier}, StoreProduct ID: ${pkg.storeProduct.identifier}, Type: ${pkg.packageType}")); }
        // No direct notifyListeners here, finally block will handle it.
        return false;
      }
      debugPrint("Attempting to purchase RevenueCat Package: ${packageToPurchase.identifier} (StoreProduct ID: ${packageToPurchase.storeProduct.identifier})");
      CustomerInfo customerInfo = await Purchases.purchasePackage(packageToPurchase);
      _customerInfo = customerInfo; // Update local immediately
      // After purchase, refresh ALL data from backend, which is now the source of truth for SubscriptionInfo
      await revenueCatSubscriptionStatus(token); // This also calls loadSubscriptionStatus

      addBreadcrumb(message: 'RevenueCat package purchase flow completed', category: 'subscription_rc_purchase', data: {'packageId': packageToPurchase.identifier, 'isPro': isProSubscriber});
      return _customerInfo?.entitlements.active.containsKey(MyOfferingsExtension.proEntitlement) ?? false;

    } on PlatformException catch (e) {
      if (e.code == "1") { _error = "Purchase cancelled by user."; addBreadcrumb(message: 'RevenueCat package purchase cancelled by user', category: 'subscription_rc_purchase');
      } else { _error = "Purchase failed: ${e.message ?? 'Unknown error'} (Code: ${e.code})"; captureException(e, stackTrace: StackTrace.current, hintText: 'Error subscribing to RC package - PlatformException ${e.code}');}
      return false;
    } catch (e, stackTrace) { _error = "Purchase error: ${e.toString()}"; captureException(e, stackTrace: stackTrace, hintText: 'Error subscribing to RC package'); return false;
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<bool> manageSubscription(String token) async {
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Opening Stripe customer portal', category: 'subscription_stripe', level: SentryLevel.info);
    try {
      final returnUrl = 'https://delisio.app/subscription/return'; // Ensure this is your actual URL
      final portalUrl = await _subscriptionService.createCustomerPortalSession(token, returnUrl);
      final url = Uri.parse(portalUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else { throw Exception('Could not launch customer portal URL: $portalUrl'); }
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hintText: 'Error managing subscription (Stripe)');
      return false;
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<bool> cancelSubscription(String token) async {
    _isLoading = true; _error = null; notifyListeners();
    addBreadcrumb(message: 'Attempting to cancel subscription (backend)', category: 'subscription_backend_cancel', level: SentryLevel.info);
    try {
      final success = await _subscriptionService.cancelSubscription(token);
      if (success) { await revenueCatSubscriptionStatus(token); }
      return success;
    } catch (e, stackTrace) {
      _error = e.toString().replaceFirst("Exception: ", "");
      captureException(e, stackTrace: stackTrace, hintText: 'Error cancelling subscription (backend)');
      return false;
    } finally { _isLoading = false; notifyListeners(); }
  }

  void resetError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}