// lib/screens/profile/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Assuming relative paths from lib/screens/profile/
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription.dart';
import '../../widgets/profile/subscription_plan_card.dart';
import '../../widgets/profile/usage_progress_bar.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isScreenLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSubscriptionData(showLoadingIndicator: true);
      }
    });
  }

  Future<void> _loadSubscriptionData({bool showLoadingIndicator = false}) async {
    if (showLoadingIndicator && mounted) {
      setState(() {
        _isScreenLoading = true;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null && authProvider.isAuthenticated) {
        final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        await subProvider.revenueCatSubscriptionStatus(authProvider.token!);
        // loadSubscriptionStatus is typically called within revenueCatSubscriptionStatus by design.
      } else {
        if (mounted) {
          Provider.of<SubscriptionProvider>(context, listen: false).resetError();
        }
      }
    } catch (e) {
      print('Error loading subscription data in SubscriptionScreen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh subscription data: ${e.toString().split(':').last.trim()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScreenLoading = false;
        });
      }
    }
  }

  Widget _buildFeatureRow(IconData icon, String text, ThemeData theme, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final isProRC = subscriptionProvider.isProSubscriber;
    final subInfo = subscriptionProvider.subscriptionInfo;
    final currentRcPackageId = subscriptionProvider.package;

    SubscriptionPlan currentPlanDetails;
    String planDisplayName;
    Color planColor;
    List<String> currentFeatures;

    final freePlanFromProvider = subscriptionProvider.plans.firstWhere(
            (p) => p.tier == SubscriptionTier.free,
        orElse: () => SubscriptionPlan(tier: SubscriptionTier.free, name: "Free", description: "Basic access", price: 0, currency: "USD", interval: "", features: ["Basic features"], planIdentifier: "free")
    );

    if (isProRC) {
      planColor = Colors.deepPurple;
      if (currentRcPackageId != null) {
        currentPlanDetails = subscriptionProvider.plans.firstWhere(
                (p) => p.planIdentifier == currentRcPackageId,
            orElse: () => subscriptionProvider.plans.firstWhere(
                    (p) => p.tier == SubscriptionTier.pro, // Fallback to any pro plan
                orElse: () => SubscriptionPlan(tier: SubscriptionTier.pro, name: "Pro Plan", description: "Current premium access", price: 0, currency: "USD", interval: "", features: ["All Pro features"], planIdentifier: "unknown-pro")
            )
        );
      } else {
        currentPlanDetails = subscriptionProvider.plans.firstWhere(
                (p) => p.tier == SubscriptionTier.pro,
            orElse: () => SubscriptionPlan(tier: SubscriptionTier.pro, name: "Pro Plan", description: "Current premium access", price: 0, currency: "USD", interval: "", features: ["All Pro features"], planIdentifier: "unknown-pro")
        );
      }
      planDisplayName = currentPlanDetails.name;
      currentFeatures = currentPlanDetails.features;
    } else { // Free plan
      currentPlanDetails = freePlanFromProvider;
      planDisplayName = currentPlanDetails.name;
      planColor = Colors.green.shade600;
      currentFeatures = currentPlanDetails.features;
    }

    final isActiveBackend = subInfo?.status == SubscriptionStatus.active || subInfo?.status == SubscriptionStatus.trialing;
    final willCancelBackend = subInfo?.cancelAtPeriodEnd ?? false;
    final periodEndBackend = subInfo?.currentPeriodEnd;

    return Card(
      elevation: 4, margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: planColor.withOpacity(0.7), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isProRC ? Icons.workspace_premium : Icons.local_florist_outlined, color: planColor, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text( planDisplayName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: planColor))),
                // Show "Active" badge for Free plan, or actual status from backend for Pro
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isActiveBackend || !isProRC) // Free is always "active" in this display sense
                        ? Colors.green.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    !isProRC ? 'Active' : (toBeginningOfSentenceCase(subInfo?.status.toString().split('.').last.replaceAll('_', ' ')) ?? 'Unknown'),
                    style: TextStyle(
                        color: (isActiveBackend || !isProRC)
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentFeatures.isNotEmpty) ...[
              Text('Current Plan Features:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...currentFeatures.map((feature) => _buildFeatureRow(Icons.check_circle_outline_rounded, feature, theme, planColor )).toList(),
              const SizedBox(height: 16),
            ],
            const Divider(),
            const SizedBox(height: 16),
            if (subInfo != null) ...[
              Text('Monthly Usage:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('Recipe Generations:', style: theme.textTheme.titleSmall),
              UsageProgressBar(used: subInfo.recipeGenerationsUsed, total: subInfo.recipeGenerationsLimit, color: planColor),
              if (subInfo.recipeGenerationsLimit != -1) Padding( padding: const EdgeInsets.only(top: 4.0), child: Text("${subInfo.recipeGenerationsRemaining} of ${subInfo.recipeGenerationsLimit} remaining", style: theme.textTheme.bodySmall)),
              const SizedBox(height: 16),
              Text('AI Chat Replies:', style: theme.textTheme.titleSmall),
              UsageProgressBar(used: subInfo.aiChatRepliesUsed, total: subInfo.aiChatRepliesLimit, color: planColor),
              if (subInfo.aiChatRepliesLimit != -1) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text("${subInfo.aiChatRepliesRemaining} of ${subInfo.aiChatRepliesLimit} remaining", style: theme.textTheme.bodySmall)),
              const SizedBox(height: 20),
            ] else if (!isProRC) ...[
              Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text("You are on the Free plan. Usage details will appear here.", style: theme.textTheme.bodyMedium)),
              const SizedBox(height: 20),
            ],
            if (isProRC && periodEndBackend != null)
              Row(children: [ Icon(Icons.calendar_today, size: 16, color: theme.textTheme.bodySmall?.color), const SizedBox(width: 8), Text( '${isActiveBackend && !willCancelBackend ? "Renews" : "Ends"}: ${_formatDate(periodEndBackend)}', style: theme.textTheme.bodySmall)]),
            if (isProRC && willCancelBackend)
              Padding( padding: const EdgeInsets.only(top: 8.0), child: Row( children: [ Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700), const SizedBox(width: 8), Text( 'Set to cancel at period end', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold))])),
            const SizedBox(height: 24),
            if (isProRC)
              SizedBox( width: double.infinity, child: ElevatedButton.icon( icon: const Icon(Icons.manage_accounts_outlined), label: const Text('Manage Subscription'), onPressed: _isScreenLoading ? null : _manageSubscription, style: ElevatedButton.styleFrom( backgroundColor: theme.colorScheme.secondary, foregroundColor: theme.colorScheme.onSecondary))),
            if (isProRC && isActiveBackend && !willCancelBackend)
              Padding( padding: const EdgeInsets.only(top: 10.0), child: SizedBox( width: double.infinity, child: OutlinedButton.icon( icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel Subscription'), onPressed: _isScreenLoading ? null : _confirmCancelSubscription, style: OutlinedButton.styleFrom( foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade300))))),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlansList() {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    List<SubscriptionPlan> plansToShow;

    if (!subscriptionProvider.isProSubscriber) {
      // If user is Free, only show Pro plans as upgrade options
      plansToShow = subscriptionProvider.plans
          .where((plan) => plan.tier == SubscriptionTier.pro)
          .toList();
    } else {
      // If user is Pro, show other Pro plans (e.g., switch monthly to annual).
      // We are still excluding the Free plan card from this "upgrade/switch" list for Pro users.
      plansToShow = subscriptionProvider.plans
          .where((plan) => plan.tier == SubscriptionTier.pro)
          .toList();
    }

    String listTitle = "Upgrade to Pro";
    if (subscriptionProvider.isProSubscriber) {
      // If there are other pro plans to switch to (i.e., plansToShow is not empty and contains plans different from current)
      if (plansToShow.isNotEmpty && plansToShow.any((plan) => plan.planIdentifier != subscriptionProvider.package)) {
        listTitle = "Switch Plan";
      } else if (plansToShow.isNotEmpty) { // Only their current Pro plan is shown
        listTitle = "Your Pro Plan";
      } else { // No pro plans defined at all (shouldn't happen if app has pro plans)
        listTitle = "Pro Plans";
      }
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
          child: Text(
            listTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (plansToShow.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              subscriptionProvider.isProSubscriber
                  ? "Details of your current Pro plan are shown above."
                  : "No upgrade plans available at the moment.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: plansToShow.length,
            itemBuilder: (context, index) {
              final plan = plansToShow[index];
              final isProFromRC = subscriptionProvider.isProSubscriber;
              final currentRcPackageId = subscriptionProvider.package;

              // This card is only for a Pro plan (because plansToShow is filtered for Pro)
              // So, isThisPlanCurrentlyActive means: is this specific Pro plan the user's current Pro plan?
              bool isThisPlanCurrentlyActive = isProFromRC && plan.planIdentifier == currentRcPackageId;

              String buttonText;
              ValueChanged<SubscriptionPlan>? onSubscribeAction;

              if (isThisPlanCurrentlyActive) {
                buttonText = "Current Pro Plan";
                onSubscribeAction = null;
              } else { // It's a Pro plan, but not their current one
                buttonText = isProFromRC ? "Switch to ${plan.name}" : "Upgrade to ${plan.name}";
                onSubscribeAction = (selectedPlan) => _subscribeToPlan(selectedPlan);
              }

              return SubscriptionPlanCard(
                plan: plan,
                isCurrentPlan: isThisPlanCurrentlyActive,
                onSubscribe: onSubscribeAction,
                buttonText: buttonText,
              );
            },
          ),
      ],
    );
  }

  Future<void> _subscribeToPlan(SubscriptionPlan plan) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to subscribe')));
      return;
    }
    if (plan.planIdentifier == null || plan.planIdentifier == 'free') {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This plan cannot be purchased directly.')));
      return;
    }
    setState(() { _isScreenLoading = true; });
    try {
      final success = await Provider.of<SubscriptionProvider>(context, listen: false).subscribeToPlan(authProvider.token!, plan);
      if (!success && mounted) {
        final error = Provider.of<SubscriptionProvider>(context, listen: false).error;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Could not start subscription process.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting subscription: $e')));
    } finally {
      if (mounted) setState(() { _isScreenLoading = false; });
    }
  }

  Future<void> _manageSubscription() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in'))); return; }
    setState(() { _isScreenLoading = true; });
    try { await Provider.of<SubscriptionProvider>(context, listen: false).manageSubscription(authProvider.token!);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error managing subscription: $e')));
    } finally { if (mounted) setState(() { _isScreenLoading = false; }); }
  }

  Future<void> _confirmCancelSubscription() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog( title: const Text('Cancel Subscription?'), content: const Text('Your Pro benefits will continue until the end of the current billing period. Are you sure you want to cancel your auto-renewal?'), actions: [ TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('NO, KEEP IT')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('YES, CANCEL RENEWAL')),],),) ?? false;
    if (confirmed) { await _cancelSubscription(); }
  }

  Future<void> _cancelSubscription() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;
    setState(() { _isScreenLoading = true; });
    try {
      final success = await Provider.of<SubscriptionProvider>(context, listen: false).cancelSubscription(authProvider.token!);
      if (success) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription auto-renewal has been cancelled.'))); await _loadSubscriptionData();
      } else { if (mounted) { final error = Provider.of<SubscriptionProvider>(context, listen: false).error; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Could not cancel subscription.'))); } }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error canceling subscription: $e')));
    } finally { if (mounted) setState(() { _isScreenLoading = false; }); }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final bool showOverallLoading = _isScreenLoading || (subscriptionProvider.isLoading && subscriptionProvider.subscriptionInfo == null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: showOverallLoading ? null : () => _loadSubscriptionData(showLoadingIndicator: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: showOverallLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => _loadSubscriptionData(showLoadingIndicator: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (subscriptionProvider.error != null && !subscriptionProvider.isLoading)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Error: ${subscriptionProvider.error}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              _buildCurrentPlanDisplay(context),
              const SizedBox(height: 16),
              _buildSubscriptionPlansList(),
            ],
          ),
        ),
      ),
    );
  }
}