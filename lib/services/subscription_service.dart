// lib/services/subscription_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/subscription.dart'; // SubscriptionTier enum is not directly used here for checkout

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