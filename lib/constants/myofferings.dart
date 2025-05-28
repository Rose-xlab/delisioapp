// lib/constants/myofferings.dart
enum MyOfferings {
  pro, // This enum member represents the conceptual "Pro" offering you want to display
}

extension MyOfferingsExtension on MyOfferings {
  String get identifier { // This getter returns the *Offering Identifier*
    switch (this) {
      case MyOfferings.pro:
      // Using the Offering Identifier you confirmed from your dashboard
        return 'Offerings';
    }
  }

  static String get proEntitlement {
    // This was confirmed from your earlier screenshot of the Entitlements page
    return 'Pro';
  }
}