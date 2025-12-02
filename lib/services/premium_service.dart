import 'package:shared_preferences/shared_preferences.dart';

/// Simple premium status service
/// For now, defaults to FREE - users must pay to unlock AI features
class PremiumService {
  static const String _premiumKey = 'is_premium';
  
  /// Check if user has premium access
  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to FREE (false) - user must upgrade
    return prefs.getBool(_premiumKey) ?? false;
  }
  
  /// Set premium status (called after successful purchase)
  static Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
  }
  
  /// Clear premium status (for testing or cancellation)
  static Future<void> clearPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_premiumKey);
  }
}

