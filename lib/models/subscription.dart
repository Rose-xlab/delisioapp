// lib/models/subscription.dart
enum SubscriptionTier { free, pro } // MODIFIED: Removed basic, premium; Added pro
enum SubscriptionStatus { active, canceled, past_due, incomplete, trialing }

class SubscriptionInfo {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime currentPeriodEnd;
  final int recipeGenerationsLimit; // For Pro, this might be a special value or ignored by UI
  final int recipeGenerationsUsed;
  final int recipeGenerationsRemaining;
  final bool cancelAtPeriodEnd;

  SubscriptionInfo({
    required this.tier,
    required this.status,
    required this.currentPeriodEnd,
    required this.recipeGenerationsLimit,
    required this.recipeGenerationsUsed,
    required this.recipeGenerationsRemaining,
    required this.cancelAtPeriodEnd,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      tier: _parseTier(json['tier']),
      status: _parseStatus(json['status']),
      currentPeriodEnd: DateTime.parse(json['currentPeriodEnd']),
      recipeGenerationsLimit: json['recipeGenerationsLimit'],
      recipeGenerationsUsed: json['recipeGenerationsUsed'],
      recipeGenerationsRemaining: json['recipeGenerationsRemaining'],
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'],
    );
  }

  static SubscriptionTier _parseTier(String tier) {
    switch (tier) {
      case 'pro': // MODIFIED: Changed from 'basic'/'premium'
        return SubscriptionTier.pro;
    // case 'basic': return SubscriptionTier.basic; // REMOVED
    // case 'premium': return SubscriptionTier.premium; // REMOVED
      default:
        return SubscriptionTier.free;
    }
  }

  static SubscriptionStatus _parseStatus(String status) {
    switch (status) {
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'past_due':
        return SubscriptionStatus.past_due;
      case 'incomplete':
        return SubscriptionStatus.incomplete;
      case 'trialing':
        return SubscriptionStatus.trialing;
      default:
        return SubscriptionStatus.active;
    }
  }
}

// Define subscription plan details
class SubscriptionPlan {
  final SubscriptionTier tier;
  final String name; // e.g., "Free", "Pro Monthly", "Pro Annual"
  final String description;
  final double price;
  final String currency;
  final String interval; // e.g., "month", "year"
  final List<String> features;
  final String? planIdentifier; // MODIFIED: Added for backend communication (e.g., "pro-monthly")

  SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.interval,
    required this.features,
    this.planIdentifier, // MODIFIED
  });
}