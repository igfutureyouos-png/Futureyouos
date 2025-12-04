import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_service.dart';

/// Simple payment service for Apple App Store and Google Play Store
class PaymentService {
  static PaymentService? _instance;
  static PaymentService get instance => _instance ??= PaymentService._();
  PaymentService._();

  // Product IDs (must match your App Store Connect and Google Play Console)
  static const String monthlySubscriptionId = 'ai_companion_monthly';
  static const String annualSubscriptionId = 'ai_companion_annual';

  bool _isInitialized = false;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _products = [];

  /// Initialize payment service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if in-app purchases are available
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        debugPrint('⚠️ In-app purchases not available on this device');
        return;
      }

      // Listen to purchase updates
      _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          debugPrint('❌ Purchase stream error: $error');
        },
      );

      // Load available products
      await _loadProducts();

      _isInitialized = true;
      debugPrint('✅ Payment service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize payment service: $e');
      rethrow;
    }
  }

  /// Load available products from stores
  Future<void> _loadProducts() async {
    const Set<String> productIds = {
      monthlySubscriptionId,
      annualSubscriptionId,
    };

    try {
      final ProductDetailsResponse response = 
          await InAppPurchase.instance.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('✅ Loaded ${_products.length} products');
    } catch (e) {
      debugPrint('❌ Failed to load products: $e');
    }
  }

  /// Get available products/subscriptions
  Future<List<ProductDetails>> getProducts() async {
    if (!_isInitialized) await initialize();
    return _products;
  }

  /// Purchase monthly subscription
  Future<bool> purchaseMonthlySubscription() async {
    return await _purchaseSubscription(monthlySubscriptionId);
  }

  /// Purchase annual subscription
  Future<bool> purchaseAnnualSubscription() async {
    return await _purchaseSubscription(annualSubscriptionId);
  }

  /// Generic subscription purchase
  Future<bool> _purchaseSubscription(String productId) async {
    if (!_isInitialized) await initialize();

    try {
      // Find the product
      final ProductDetails? product = _products
          .where((p) => p.id == productId)
          .firstOrNull;

      if (product == null) {
        throw Exception('Product $productId not found');
      }

      // Create purchase param
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      // Make the purchase
      final bool success = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      debugPrint('Purchase initiated: $success for $productId');
      return success;
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      return false;
    }
  }

  /// Restore purchases (for users who already purchased)
  Future<bool> restorePurchases() async {
    if (!_isInitialized) await initialize();

    try {
      await InAppPurchase.instance.restorePurchases();
      debugPrint('✅ Restore purchases initiated');
      return true;
    } catch (e) {
      debugPrint('❌ Restore purchases error: $e');
      return false;
    }
  }

  /// Check current subscription status
  Future<bool> checkSubscriptionStatus() async {
    // For simplicity, we'll rely on local storage
    // In production, you might want to verify with your backend
    return await PremiumService.isPremium();
  }

  /// Handle purchase updates from the store
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          debugPrint('⏳ Purchase pending: ${purchaseDetails.productID}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          debugPrint('✅ Purchase completed: ${purchaseDetails.productID}');
          _handleSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          debugPrint('❌ Purchase error: ${purchaseDetails.error}');
          break;
        case PurchaseStatus.canceled:
          debugPrint('🚫 Purchase canceled: ${purchaseDetails.productID}');
          break;
      }

      // Complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    // Grant premium access
    await PremiumService.setPremium(true);
    
    debugPrint('✅ Premium access granted for: ${purchaseDetails.productID}');
  }

  /// Get subscription info (simplified version)
  Future<Map<String, dynamic>?> getSubscriptionInfo() async {
    final isPremium = await PremiumService.isPremium();
    
    if (!isPremium) {
      return null; // No active subscription
    }

    // Return basic info (you can enhance this with actual subscription data)
    return {
      'isActive': true,
      'productId': 'unknown', // Would need to track this
      'expirationDate': DateTime.now().add(const Duration(days: 30)), // Placeholder
      'willRenew': true,
      'periodType': 'monthly',
    };
  }

  /// Cancel subscription (redirects to platform settings)
  Future<void> cancelSubscription() async {
    // Note: Actual cancellation must be done through platform stores
    // This method shows instructions or redirects to settings
    
    if (Platform.isIOS) {
      // iOS: User needs to go to Settings > Apple ID > Subscriptions
      debugPrint('iOS: Redirect to Settings > Apple ID > Subscriptions');
    } else if (Platform.isAndroid) {
      // Android: User needs to go to Google Play Store > Subscriptions
      debugPrint('Android: Redirect to Google Play Store > Subscriptions');
    }
  }

  /// Dispose resources
  void dispose() {
    _purchaseSubscription?.cancel();
  }
}