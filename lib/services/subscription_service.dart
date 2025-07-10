// lib/services/subscription_service.dart
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  Future<SubscriptionInfo> getSubscriptionStatus(String token) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl${ApiConfig.subscriptionStatus}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return SubscriptionInfo.fromJson(responseData['subscription']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']['message'] ?? 'Failed to get subscription status');
      }
    } catch (e) {
      print('Error in getSubscriptionStatus: $e');
      rethrow;
    }
  }

  // Create checkout session
  // MODIFIED: Takes a planIdentifier string instead of SubscriptionTier
  Future<String> createCheckoutSession(
      String token,
      String planIdentifier, // MODIFIED: e.g., "pro-monthly", "pro-annual"
      String successUrl,
      String cancelUrl,
      ) async {
    try {
      // REMOVED: final tierString = tier == SubscriptionTier.premium ? 'premium' : 'basic';

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.subscriptionCheckout}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          // MODIFIED: Use planIdentifier instead of 'tier' for checkout if backend expects this
          'planIdentifier': planIdentifier,
          // If backend still expects 'tier' but with new values, adjust accordingly:
          // 'tier': planIdentifier, // e.g. if backend expects 'pro-monthly' in a 'tier' field
          'successUrl': successUrl,
          'cancelUrl': cancelUrl,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['checkoutUrl'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']['message'] ?? 'Failed to create checkout session');
      }
    } catch (e) {
      print('Error in createCheckoutSession: $e');
      rethrow;
    }
  }

  Future<String> createCustomerPortalSession(
      String token,
      String returnUrl,
      ) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.subscriptionPortal}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'returnUrl': returnUrl,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['portalUrl'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']['message'] ?? 'Failed to create customer portal session');
      }
    } catch (e) {
      print('Error in createCustomerPortalSession: $e');
      rethrow;
    }
  }


  Future<void> subscriptionSync({ // Return Future<void> if you don't need a specific return
  required String tier,
  required String status,
  required String? currentPeriodStart, // Can be null
  required String? currentPeriodEnd,   // Can be null
  required bool cancelAtPeriodEnd,
  required String token,
}) async {
  try {

    debugPrint("================================== SYNC CALLED =================================");
    final url = Uri.parse('$baseUrl${ApiConfig.subscriptionSync}');
    debugPrint("============= $url ===========================");
    final response = await client.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Send the token for authentication
      },
      body: json.encode({
        // Do NOT send userId; backend gets it from the token.
        'tier': tier,
        'status': status,
        'currentPeriodStart': currentPeriodStart,
        'currentPeriodEnd': currentPeriodEnd,
        'cancelAtPeriodEnd': cancelAtPeriodEnd,
      }),
    );

    if (response.statusCode == 200) {
      print('Backend sync successful.');
      // You can decode and return something if needed, but often
      // a successful sync doesn't need to return data.
      // final responseData = json.decode(response.body);
      // return; // Or return responseData['message'] or similar
    } else {
      // Improved error handling
      String errorMessage = 'Failed to sync subscription';
      try {
           final errorData = json.decode(response.body);
           errorMessage = errorData['message'] ?? errorData['error']?['message'] ?? errorMessage;
      } catch(_) {
          // Keep default message if parsing fails
      }
      print('Backend sync failed: ${response.statusCode} - $errorMessage');
      throw Exception(errorMessage);
    }
  } catch (e) {
    print('Error during subscriptionSyc API call: $e');
    rethrow; // Re-throw the exception so the caller can handle it
  }
}

  Future<bool> cancelSubscription(String token) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.subscriptionCancel}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']['message'] ?? 'Failed to cancel subscription');
      }
    } catch (e) {
      print('Error in cancelSubscription: $e');
      rethrow;
    }
  }
}