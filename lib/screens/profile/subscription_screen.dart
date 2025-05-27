// lib/screens/profile/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _isLoading = false; // Local loading state for screen-specific actions

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(authProvider.token!);
      }
    } catch (e) {
      print('Error loading subscription data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load subscription: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Widget _buildCurrentPlan(SubscriptionInfo subscriptionInfo) {
  //   final theme = Theme.of(context);
  //   final isActive = subscriptionInfo.status == SubscriptionStatus.active;
  //   final willCancel = subscriptionInfo.cancelAtPeriodEnd;
  //   final endDate = subscriptionInfo.currentPeriodEnd;

  //   String planNameDisplay;
  //   Color planColor;

  //   // Get current plan details from provider's list for accurate name (e.g. "Pro Monthly")
  //   // This assumes the backend returns a tier that can be matched,
  //   // or you have logic to map SubscriptionInfo.tier to a specific plan.
  //   // For simplicity, we'll derive from tier here, but for exact "Pro Monthly" vs "Pro Annual"
  //   // name in current plan, you might need more info from backend or match against currentPeriodEnd interval.

  //   // Attempt to find the exact current plan based on its identifier if available from backend
  //   // This part requires backend to send 'planIdentifier' or similar with SubscriptionInfo
  //   String? currentBackendPlanIdentifier = subscriptionInfo.status == SubscriptionStatus.active
  //       ? Provider.of<SubscriptionProvider>(context, listen: false).plans.firstWhere(
  //           (p) => p.tier == subscriptionInfo.tier && (
  //           (p.interval == 'month' && subscriptionInfo.currentPeriodEnd.difference(DateTime.now()).inDays < 35 ) || // rough guess for monthly
  //               (p.interval == 'year' && subscriptionInfo.currentPeriodEnd.difference(DateTime.now()).inDays > 35) // rough guess for yearly
  //           // A more reliable way would be if SubscriptionInfo included the priceId or plan.planIdentifier
  //       ), orElse: () => Provider.of<SubscriptionProvider>(context, listen:false).plans.firstWhere((p) => p.tier == subscriptionInfo.tier, orElse: () => SubscriptionPlan(tier: subscriptionInfo.tier, name: "Current", description: "", price: 0, currency: "USD", interval: "", features: []))
  //   ).name
  //       : subscriptionInfo.tier.toString().split('.').last.toUpperCase(); // Fallback if not active or exact match complex


  //   switch (subscriptionInfo.tier) {
  //     case SubscriptionTier.pro:
  //     // Use the matched plan name if possible, otherwise default to "Pro"
  //       final proPlanDetails = Provider.of<SubscriptionProvider>(context, listen:false).plans.firstWhere((p) => p.tier == SubscriptionTier.pro, orElse: () => SubscriptionPlan(tier: SubscriptionTier.pro, name: "Pro", description: "", price: 0, currency: "USD", interval: "", features: [], planIdentifier: "pro"));
  //       planNameDisplay = proPlanDetails.name; // This will be "Pro Monthly" or "Pro Annual" if plans are set up
  //       // We need a better way to know which specific Pro plan the user is on.
  //       // For now, we will try to find if the user is on a known "Pro" plan.
  //       final actualProPlan = Provider.of<SubscriptionProvider>(context, listen: false).plans.firstWhere(
  //               (p) => p.tier == SubscriptionTier.pro && p.name.toLowerCase().contains(subscriptionInfo.currentPeriodEnd.difference(DateTime.now()).inDays < 40 ? "month" : "year"), // very rough heuristic
  //           orElse: () => proPlanDetails
  //       );
  //       planNameDisplay = actualProPlan.name;
  //       planColor = Colors.deepPurple;
  //       break;
  //     default: // free
  //       final freePlanDetails = Provider.of<SubscriptionProvider>(context, listen:false).plans.firstWhere((p) => p.tier == SubscriptionTier.free);
  //       planNameDisplay = freePlanDetails.name; // Should be "Free"
  //       planColor = Colors.green;
  //   }


  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Icon(Icons.star, color: planColor, size: 24),
  //               const SizedBox(width: 8),
  //               Text(
  //                 'Current Plan: $planNameDisplay',
  //                 style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  //               ),
  //               const Spacer(),
  //               Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                 decoration: BoxDecoration(
  //                   color: isActive ? Colors.green : Colors.orange,
  //                   borderRadius: BorderRadius.circular(12),
  //                 ),
  //                 child: Text(
  //                   isActive ? 'Active' : subscriptionInfo.status.toString().split('.').last,
  //                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 16),

  //           if (subscriptionInfo.tier == SubscriptionTier.free) // Only show for Free
  //             Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text('Recipe Generations', style: theme.textTheme.titleMedium),
  //                 const SizedBox(height: 8),
  //                 UsageProgressBar(
  //                   used: subscriptionInfo.recipeGenerationsUsed,
  //                   total: subscriptionInfo.recipeGenerationsLimit,
  //                   color: planColor,
  //                 ),
  //                 const SizedBox(height: 8),
  //                 Text(
  //                   '${subscriptionInfo.recipeGenerationsUsed} used of ${subscriptionInfo.recipeGenerationsLimit} this month',
  //                   style: TextStyle(color: theme.textTheme.bodySmall?.color),
  //                 ),
  //                 const SizedBox(height: 16),
  //               ],
  //             ),
  //           Row(
  //             children: [
  //               Icon(Icons.calendar_today, size: 16, color: theme.textTheme.bodySmall?.color),
  //               const SizedBox(width: 8),
  //               Text(
  //                 '${isActive && !willCancel && subscriptionInfo.tier == SubscriptionTier.pro ? "Renews" : "Ends"}: ${_formatDate(endDate)}',
  //                 style: TextStyle(color: theme.textTheme.bodySmall?.color),
  //               ),
  //             ],
  //           ),
  //           if (willCancel && subscriptionInfo.tier == SubscriptionTier.pro)
  //             const Padding(
  //               padding: EdgeInsets.only(top: 8.0),
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.info_outline, size: 16, color: Colors.orange),
  //                   SizedBox(width: 8),
  //                   Text(
  //                     'Set to cancel at period end',
  //                     style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           const SizedBox(height: 16),

  //           if (subscriptionInfo.tier == SubscriptionTier.pro) // Only show manage for Pro
  //             SizedBox(
  //               width: double.infinity,
  //               child: ElevatedButton(
  //                 onPressed: () => _manageSubscription(),
  //                 child: const Text('Manage Subscription'),
  //               ),
  //             ),

  //           if (subscriptionInfo.tier == SubscriptionTier.pro && !willCancel && isActive)
  //             Padding(
  //               padding: const EdgeInsets.only(top: 8.0),
  //               child: SizedBox(
  //                 width: double.infinity,
  //                 child: OutlinedButton(
  //                   onPressed: () => _confirmCancelSubscription(),
  //                   style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
  //                   child: const Text('Cancel Subscription'),
  //                 ),
  //               ),
  //             ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildSubscriptionPlans() {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final currentSubInfo = subscriptionProvider.subscriptionInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Subscription Plans',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subscriptionProvider.plans.length,
          itemBuilder: (context, index) {
            final plan = subscriptionProvider.plans[index];
            final isPro = subscriptionProvider.isProSubscriber;
            final currentPackage = subscriptionProvider.package;

            // Determine if this plan is the current active plan
            bool isCurrentPlan = false;
            if (plan.tier == SubscriptionTier.free && !isPro) {
              isCurrentPlan = true;
            } else if (plan.tier == SubscriptionTier.pro && isPro && plan.planIdentifier == currentPackage) {
              isCurrentPlan = true;
            }

            // Disable subscribe button for current plan
            final disableSubscribeButton = isCurrentPlan;

            // Button text: "Upgrade" for all paid plans that are not current
            String buttonText = "Subscribe";
            if (plan.tier == SubscriptionTier.pro && !isCurrentPlan) {
              buttonText = "Upgrade";
            }

            return SubscriptionPlanCard(
              plan: plan,
              isCurrentPlan: isCurrentPlan,
              onSubscribe: (plan.tier == SubscriptionTier.free || plan.planIdentifier == null || plan.planIdentifier == 'free' || disableSubscribeButton)
                  ? null
                  : _subscribeToPlan,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to subscribe')),
      );
      return;
    }
    if (plan.tier == SubscriptionTier.free || plan.planIdentifier == null || plan.planIdentifier == 'free') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Free plan is automatically applied or cannot be subscribed to directly.')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final success = await Provider.of<SubscriptionProvider>(context, listen: false)
          .subscribeToPlan(authProvider.token!, plan);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening checkout page...')),
        );
      } else {
        final error = Provider.of<SubscriptionProvider>(context, listen: false).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Could not start subscription process.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting subscription: $e')),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _manageSubscription() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in')),
      );
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final success = await Provider.of<SubscriptionProvider>(context, listen: false)
          .manageSubscription(authProvider.token!);
      if (success) {
        // Message is usually handled by provider or not needed as browser opens
      } else {
        final error = Provider.of<SubscriptionProvider>(context, listen: false).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Could not open management portal.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error managing subscription: $e')),
      );
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  Future<void> _confirmCancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Your Pro plan benefits will continue until the end of the current billing period, and then automatically cancel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('NO, KEEP IT'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await _cancelSubscription();
    }
  }

  Future<void> _cancelSubscription() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    setState(() { _isLoading = true; });
    try {
      final success = await Provider.of<SubscriptionProvider>(context, listen: false)
          .cancelSubscription(authProvider.token!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription will cancel at period end.')),
        );
        await _loadSubscriptionData();
      } else {
        final error = Provider.of<SubscriptionProvider>(context, listen: false).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Could not cancel subscription.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error canceling subscription: $e')),
      );
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2,'0')}/${date.day.toString().padLeft(2,'0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final subscriptionInfo = subscriptionProvider.subscriptionInfo;
    final isLoading = _isLoading || subscriptionProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadSubscriptionData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading && subscriptionInfo == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadSubscriptionData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subscriptionProvider.error != null && !isLoading)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Error: ${subscriptionProvider.error}", style: TextStyle(color: Colors.red)),
                ),
              // if (subscriptionInfo != null)
              //   Padding(
              //     padding: const EdgeInsets.all(16.0),
              //     child: _buildCurrentPlan(subscriptionInfo),
              //   ),
              if (subscriptionInfo == null && !isLoading && subscriptionProvider.error == null)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text("No active subscription information found. You are on the Free plan.", textAlign: TextAlign.center,)),
                ),
              _buildSubscriptionPlans(),
            ],
          ),
        ),
      ),
    );
  }
}