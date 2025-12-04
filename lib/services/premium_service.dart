import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple premium status service
/// For now, defaults to FREE - users must pay to unlock AI features
class PremiumService {
  static const String _premiumKey = 'is_premium';
  
  // 🔧 TESTING: Add your email here to bypass paywall
  static const List<String> _testEmails = [
    'felix@example.com', // Replace with your actual email
    'test@futureyou.com',
  ];
  
  /// Check if user has premium access
  static Future<bool> isPremium() async {
    // 🔧 TESTING: Check if current user email is in test list
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email != null && _testEmails.contains(currentUser!.email)) {
      return true; // Bypass paywall for test emails
    }
    
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

