// lib/services/subscription_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final String baseUrl = ApiConfig.baseUrl;
  final http.Client client = http.Client();

  // Get subscription status
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
  Future<String> createCheckoutSession(
      String token,
      SubscriptionTier tier,
      String successUrl,
      String cancelUrl,
      ) async {
    try {
      final tierString = tier == SubscriptionTier.premium ? 'premium' : 'basic';

      final response = await client.post(
        Uri.parse('$baseUrl${ApiConfig.subscriptionCheckout}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'tier': tierString,
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

  // Create customer portal session
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

  // Cancel subscription
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