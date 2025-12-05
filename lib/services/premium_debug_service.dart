import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'premium_service.dart';

/// Debug service to help troubleshoot premium access issues
class PremiumDebugService {
  
  /// Debug premium status and show detailed info
  static Future<Map<String, dynamic>> debugPremiumStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isPremium = await PremiumService.isPremium();
    final isDeveloper = await PremiumService.isDeveloper();
    
    final debugInfo = {
      'currentUser': currentUser?.email ?? 'Not logged in',
      'userId': currentUser?.uid ?? 'No UID',
      'isPremium': isPremium,
      'isDeveloper': isDeveloper,
      'developerEmails': ['waazafaaza@gmail.com', 'developer@futureyou.com', 'test@futureyou.com'],
      'emailMatch': currentUser?.email == 'waazafaaza@gmail.com',
      'authState': currentUser != null ? 'Authenticated' : 'Not authenticated',
    };
    
    debugPrint('🔍 PREMIUM DEBUG INFO:');
    debugInfo.forEach((key, value) {
      debugPrint('  $key: $value');
    });
    
    return debugInfo;
  }
  
  /// Force set premium status for testing
  static Future<void> forceSetPremium(bool value) async {
    await PremiumService.setPremium(value);
    debugPrint('🔧 FORCED premium status to: $value');
  }
  
  /// Clear all premium data for fresh start
  static Future<void> resetPremiumData() async {
    await PremiumService.clearPremium();
    debugPrint('🗑️ CLEARED all premium data');
  }
}
