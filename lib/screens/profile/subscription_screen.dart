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
  bool _isLoading = false;

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

  Widget _buildCurrentPlan(SubscriptionInfo subscriptionInfo) {
    final theme = Theme.of(context);
    final isActive = subscriptionInfo.status == SubscriptionStatus.active;
    final willCancel = subscriptionInfo.cancelAtPeriodEnd;
    final endDate = subscriptionInfo.currentPeriodEnd;

    // Get plan name based on tier
    String planName;
    Color planColor;

    switch (subscriptionInfo.tier) {
      case SubscriptionTier.basic:
        planName = 'Basic';
        planColor = Colors.blue;
        break;
      case SubscriptionTier.premium:
        planName = 'Premium';
        planColor = Colors.purple;
        break;
      default:
        planName = 'Free';
        planColor = Colors.green;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: planColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Plan: $planName',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Recipe usage
            if (subscriptionInfo.tier != SubscriptionTier.premium)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipe Generations',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  UsageProgressBar(
                    used: subscriptionInfo.recipeGenerationsUsed,
                    total: subscriptionInfo.recipeGenerationsLimit,
                    color: planColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${subscriptionInfo.recipeGenerationsUsed} used of ${subscriptionInfo.recipeGenerationsLimit} this month',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Period info
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current period ends: ${_formatDate(endDate)}',
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),

            if (willCancel)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Will cancel at end of period',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Manage subscription button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _manageSubscription(),
                child: const Text('Manage Subscription'),
              ),
            ),

            if (subscriptionInfo.tier != SubscriptionTier.free && !willCancel)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _confirmCancelSubscription(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel Subscription'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlans() {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final currentTier = subscriptionProvider.subscriptionInfo?.tier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Subscription Plans',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subscriptionProvider.plans.length,
          itemBuilder: (context, index) {
            final plan = subscriptionProvider.plans[index];
            final isCurrentPlan = plan.tier == currentTier;

            return SubscriptionPlanCard(
              plan: plan,
              isCurrentPlan: isCurrentPlan,
              onSubscribe: isCurrentPlan
                  ? null
                  : () => _subscribeToPlan(plan.tier),
            );
          },
        ),
      ],
    );
  }

  Future<void> _subscribeToPlan(SubscriptionTier tier) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to subscribe')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await Provider.of<SubscriptionProvider>(context, listen: false)
          .subscribeToPlan(authProvider.token!, tier);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening checkout page...')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting subscription: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _manageSubscription() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to manage subscription')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await Provider.of<SubscriptionProvider>(context, listen: false)
          .manageSubscription(authProvider.token!);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening subscription portal...')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error managing subscription: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmCancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Your subscription will continue until the end of the current billing period, and then automatically cancel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('NO, KEEP IT'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
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
    if (authProvider.token == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await Provider.of<SubscriptionProvider>(context, listen: false)
          .cancelSubscription(authProvider.token!);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription will cancel at the end of the billing period')),
        );

        // Reload subscription data to reflect cancellation
        await Provider.of<SubscriptionProvider>(context, listen: false)
            .loadSubscriptionStatus(authProvider.token!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error canceling subscription: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference <= 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadSubscriptionData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current subscription info
              if (subscriptionInfo != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCurrentPlan(subscriptionInfo),
                ),

              // Subscription plans
              _buildSubscriptionPlans(),
            ],
          ),
        ),
      ),
    );
  }
}