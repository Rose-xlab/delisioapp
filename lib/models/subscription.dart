// lib/models/subscription.dart
import 'package:flutter/foundation.dart'; // For kDebugMode if you add debug prints

// Your existing enums
enum SubscriptionTier { free, pro }
enum SubscriptionStatus { active, canceled, past_due, incomplete, trialing, unknown } // Added unknown as a fallback

class SubscriptionInfo {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? currentPeriodEnd; // MODIFIED: Made nullable for robustness
  final int recipeGenerationsLimit;
  final int recipeGenerationsUsed;
  final int recipeGenerationsRemaining;
  final bool cancelAtPeriodEnd;

  // **** NEW FIELDS for AI Chat Reply Limits ****
  final int aiChatRepliesLimit;       // e.g., 3 for free, -1 for unlimited (convention for unlimited)
  final int aiChatRepliesUsed;
  final int aiChatRepliesRemaining;   // This will be calculated or directly from backend

  SubscriptionInfo({
    required this.tier,
    required this.status,
    this.currentPeriodEnd, // MODIFIED: Made nullable
    required this.recipeGenerationsLimit,
    required this.recipeGenerationsUsed,
    required this.recipeGenerationsRemaining,
    required this.cancelAtPeriodEnd,
    // **** ADD NEW FIELDS TO CONSTRUCTOR ****
    required this.aiChatRepliesLimit,
    required this.aiChatRepliesUsed,
    required this.aiChatRepliesRemaining,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse int, defaulting to 0 if null or invalid
    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }
    // Helper to safely parse DateTime
    DateTime? parseDateTime(String? dateString) {
      if (dateString == null) return null;
      return DateTime.tryParse(dateString);
    }

    // Determine if the tier is free for default value logic
    SubscriptionTier parsedTier = _parseTier(json['tier'] as String?);

    return SubscriptionInfo(
      tier: parsedTier,
      status: _parseStatus(json['status'] as String?),
      currentPeriodEnd: parseDateTime(json['currentPeriodEnd'] as String?), // MODIFIED: Safe parsing

      // Recipe generation fields - assuming backend sends these as numbers.
      // Using -1 as a convention for "unlimited" if backend sends that.
      recipeGenerationsLimit: parseInt(json['recipeGenerationsLimit'], defaultValue: (parsedTier == SubscriptionTier.pro ? -1 : 1)), // Default 1 for free, -1 (unlimited) for pro
      recipeGenerationsUsed: parseInt(json['recipeGenerationsUsed']),
      recipeGenerationsRemaining: parseInt(json['recipeGenerationsRemaining'], defaultValue: (parsedTier == SubscriptionTier.pro ? -1 : 1)),

      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,

      // **** PARSE NEW AI CHAT REPLY FIELDS ****
      // Backend should send these. -1 can represent unlimited.
      // Defaults are set assuming a 'free' tier might get 3 replies if data is missing.
      aiChatRepliesLimit: parseInt(json['aiChatRepliesLimit'], defaultValue: (parsedTier == SubscriptionTier.pro ? -1 : 3)),
      aiChatRepliesUsed: parseInt(json['aiChatRepliesUsed']),
      aiChatRepliesRemaining: parseInt(json['aiChatRepliesRemaining'], defaultValue: (parsedTier == SubscriptionTier.pro ? -1 : 3)),
    );
  }

  static SubscriptionTier _parseTier(String? tierString) { // Made tierString nullable
    switch (tierString?.toLowerCase()) { // Use null-safe access
      case 'pro':
        return SubscriptionTier.pro;
      case 'free': // Explicitly handle 'free' case
        return SubscriptionTier.free;
    // Removed 'basic' and 'premium' as your enum only has free/pro
      default:
        if (kDebugMode) print("SubscriptionInfo: Unknown tier '$tierString', defaulting to free.");
        return SubscriptionTier.free; // Default fallback
    }
  }

  static SubscriptionStatus _parseStatus(String? statusString) { // Made statusString nullable
    switch (statusString?.toLowerCase()) { // Use null-safe access
      case 'active':
        return SubscriptionStatus.active;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'past_due':
        return SubscriptionStatus.past_due;
      case 'incomplete':
        return SubscriptionStatus.incomplete;
      case 'trialing':
        return SubscriptionStatus.trialing;
      default:
        if (kDebugMode && statusString != null) print("SubscriptionInfo: Unknown status '$statusString', defaulting to unknown.");
        return SubscriptionStatus.unknown; // Default fallback
    }
  }
}

// Define subscription plan details (your existing class, unchanged)
class SubscriptionPlan {
  final SubscriptionTier tier;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String interval;
  final List<String> features;
  final String? planIdentifier;

  SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.interval,
    required this.features,
    this.planIdentifier,
  });
}