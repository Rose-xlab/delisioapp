// lib/models/subscription.dart
enum SubscriptionTier { free, basic, premium }
enum SubscriptionStatus { active, canceled, past_due, incomplete, trialing }

class SubscriptionInfo {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime currentPeriodEnd;
  final int recipeGenerationsLimit;
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
      case 'basic': return SubscriptionTier.basic;
      case 'premium': return SubscriptionTier.premium;
      default: return SubscriptionTier.free;
    }
  }

  static SubscriptionStatus _parseStatus(String status) {
    switch (status) {
      case 'canceled': return SubscriptionStatus.canceled;
      case 'past_due': return SubscriptionStatus.past_due;
      case 'incomplete': return SubscriptionStatus.incomplete;
      case 'trialing': return SubscriptionStatus.trialing;
      default: return SubscriptionStatus.active;
    }
  }
}

// Define subscription plan details
class SubscriptionPlan {
  final SubscriptionTier tier;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String interval;
  final List<String> features;

  SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.interval,
    required this.features,
  });
}