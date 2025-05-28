// lib/models/subscription.dart
import 'package:flutter/foundation.dart';
// import 'package:collection/collection.dart'; // Not strictly needed here unless SubscriptionInfo itself has lists to compare

enum SubscriptionTier { free, pro, basic } // Ensuring 'basic' is here if your model uses it
enum SubscriptionStatus { active, canceled, past_due, incomplete, trialing, unknown }

class SubscriptionInfo {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? currentPeriodEnd;
  final int recipeGenerationsLimit;
  final int recipeGenerationsUsed;
  final int recipeGenerationsRemaining;
  final bool cancelAtPeriodEnd;
  final int aiChatRepliesLimit;
  final int aiChatRepliesUsed;
  final int aiChatRepliesRemaining;

  SubscriptionInfo({
    required this.tier,
    required this.status,
    this.currentPeriodEnd,
    required this.recipeGenerationsLimit,
    required this.recipeGenerationsUsed,
    required this.recipeGenerationsRemaining,
    required this.cancelAtPeriodEnd,
    required this.aiChatRepliesLimit,
    required this.aiChatRepliesUsed,
    required this.aiChatRepliesRemaining,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is double) return value.toInt(); // Handle if backend sends numbers as double
      return defaultValue;
    }

    DateTime? parseDateTime(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        if (kDebugMode) {
          print("SubscriptionInfo.fromJson: Error parsing date '$dateString': $e");
        }
        return null;
      }
    }

    SubscriptionTier parsedTier = _parseTier(json['tier'] as String?);

    // Determine default limits based on the PARSED tier for consistency
    int defaultRecipeLimit = (parsedTier == SubscriptionTier.pro || parsedTier == SubscriptionTier.basic) ? -1 : 1;
    int defaultChatLimit = (parsedTier == SubscriptionTier.pro || parsedTier == SubscriptionTier.basic) ? -1 : 3;
    // If basic has different limits, you'll need more refined logic here or ensure backend sends them.
    if (parsedTier == SubscriptionTier.basic) {
      // Example specific limits for basic, or ensure backend always sends these for basic
      defaultRecipeLimit = 10; // Example
      defaultChatLimit = 100;  // Example
    }


    return SubscriptionInfo(
      tier: parsedTier,
      status: _parseStatus(json['status'] as String?),
      currentPeriodEnd: parseDateTime(json['currentPeriodEnd'] as String?),
      recipeGenerationsLimit: parseInt(json['recipeGenerationsLimit'], defaultValue: defaultRecipeLimit),
      recipeGenerationsUsed: parseInt(json['recipeGenerationsUsed']),
      recipeGenerationsRemaining: parseInt(json['recipeGenerationsRemaining'], defaultValue: defaultRecipeLimit), // Default remaining to full limit initially
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      aiChatRepliesLimit: parseInt(json['aiChatRepliesLimit'], defaultValue: defaultChatLimit),
      aiChatRepliesUsed: parseInt(json['aiChatRepliesUsed']),
      aiChatRepliesRemaining: parseInt(json['aiChatRepliesRemaining'], defaultValue: defaultChatLimit), // Default remaining to full limit
    );
  }

  static SubscriptionTier _parseTier(String? tierString) {
    switch (tierString?.toLowerCase()) {
      case 'premium': // This is what your backend sends for the pro tier
        return SubscriptionTier.pro; // Map "premium" from backend to app's "pro"
      case 'pro': // Keep this in case backend ever sends "pro" or for other contexts
        return SubscriptionTier.pro;
      case 'basic':
        return SubscriptionTier.basic;
      case 'free':
        return SubscriptionTier.free;
      default:
        if (kDebugMode) print("SubscriptionInfo: Unknown tier '$tierString', defaulting to free.");
        return SubscriptionTier.free;
    }
  }

  static SubscriptionStatus _parseStatus(String? statusString) {
    switch (statusString?.toLowerCase()) {
      case 'active': return SubscriptionStatus.active;
      case 'canceled': return SubscriptionStatus.canceled; // 'canceled' not 'cancelled'
      case 'past_due': return SubscriptionStatus.past_due;
      case 'incomplete': return SubscriptionStatus.incomplete;
      case 'trialing': return SubscriptionStatus.trialing;
      default:
        if (kDebugMode && statusString != null) print("SubscriptionInfo: Unknown status '$statusString', defaulting to unknown.");
        return SubscriptionStatus.unknown;
    }
  }
}

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