import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple premium status service
/// For now, defaults to FREE - users must pay to unlock AI features
class PremiumService {
  static const String _premiumKey = 'is_premium';
  
  // 🔧 DEVELOPER BYPASS: Add your email here to get free AI access
  static const List<String> _developerEmails = [
    'waazafaaza@gmail.com', // Felix's email - free AI access
    'developer@futureyou.com',
    'test@futureyou.com',
  ];
  
  /// Check if user has premium access
  static Future<bool> isPremium() async {
    // 🔧 DEVELOPER BYPASS: Check if current user email is in developer list
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email != null && _developerEmails.contains(currentUser!.email)) {
      return true; // Free AI access for developers
    }
    
    final prefs = await SharedPreferences.getInstance();
    // Default to FREE (false) - user must upgrade
    return prefs.getBool(_premiumKey) ?? false;
  }
  
  /// Check if user is a developer (for UI purposes)
  static Future<bool> isDeveloper() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.email != null && _developerEmails.contains(currentUser!.email);
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

