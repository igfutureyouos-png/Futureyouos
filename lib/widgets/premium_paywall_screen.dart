import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/payment_service.dart';
import '../services/premium_service.dart';

/// 💎 PREMIUM PAYWALL - Single Screen, No Scroll, No Fake Data
class PremiumPaywallScreen extends StatefulWidget {
  final String feature;

  const PremiumPaywallScreen({
    super.key,
    required this.feature,
  });

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  // ═══════════════════════════════════════════════════════════════════════════
  // STATE - UNTOUCHED
  // ═══════════════════════════════════════════════════════════════════════════
  bool _isLoading = false;
  bool _isDeveloper = false;
  int _selectedPlanIndex = 1; // Default annual

  @override
  void initState() {
    super.initState();
    _checkDeveloperStatus();
  }

  Future<void> _checkDeveloperStatus() async {
    final isDev = await PremiumService.isDeveloper();
    if (mounted) {
      setState(() => _isDeveloper = isDev);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD - SINGLE SCREEN, NO SCROLL
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseDark1,
      body: Stack(
        children: [
          // Background
          _buildBackground(),

          // Content - NO SCROLL
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          LucideIcons.x,
                          color: AppColors.textQuaternary,
                          size: 22,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                    ),
                  ),

                  // Spacer pushes content to center-ish
                  const Spacer(flex: 2),

                  // Hero - Crown + Title
                  _buildHero(),

                  const SizedBox(height: 32),

                  // Value props - compact
                  _buildValueProps(),

                  const Spacer(flex: 3),

                  // Pricing
                  _buildPricing(),

                  const SizedBox(height: 20),

                  // CTA
                  _buildCTA(),

                  const SizedBox(height: 16),

                  // Footer
                  _buildFooter(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Loading
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUND
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D1117),
                AppColors.baseDark1,
                Color(0xFF0A0F0D),
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: 0,
          right: 0,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppColors.emerald.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO - Crown + Title
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHero() {
    return Column(
      children: [
        // Crown
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.emeraldGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withOpacity(0.4),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.crown,
            color: Colors.black,
            size: 40,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

        const SizedBox(height: 20),

        // Title
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.emeraldGradient.createShader(bounds),
          child: const Text(
            'Unlock Premium',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Get ${widget.feature} and all features',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

        // Developer badge
        if (_isDeveloper) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.code2, color: AppColors.emerald, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Developer Access',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALUE PROPS - Compact, no fake data
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildValueProps() {
    return Column(
      children: [
        _buildFeatureRow(LucideIcons.messageCircle, 'Unlimited AI conversations'),
        const SizedBox(height: 12),
        _buildFeatureRow(LucideIcons.target, 'Smart briefs, nudges & coaching'),
        const SizedBox(height: 12),
        _buildFeatureRow(LucideIcons.sparkles, 'What-If life simulator'),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.emerald.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.emerald, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(LucideIcons.check, color: AppColors.emerald, size: 18),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRICING - Horizontal cards
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPricing() {
    return Row(
      children: [
        // Monthly
        Expanded(
          child: _buildPlanCard(
            index: 0,
            title: 'Monthly',
            price: '\$6.99',
            period: '/mo',
            badge: null,
          ),
        ),
        const SizedBox(width: 12),
        // Annual
        Expanded(
          child: _buildPlanCard(
            index: 1,
            title: 'Annual',
            price: '\$49.99',
            period: '/yr',
            badge: 'SAVE 40%',
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    required String period,
    String? badge,
  }) {
    final isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.15),
                    AppColors.emerald.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.emerald : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: isSelected ? AppColors.emerald : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        period,
                        style: TextStyle(
                          color: AppColors.textQuaternary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -10,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CTA
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCTA() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.emeraldGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _purchase,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.crown, color: Colors.black, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Unlock Premium Now',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFooter() {
    return Column(
      children: [
        TextButton(
          onPressed: _restorePurchases,
          child: Text(
            'Restore Purchases',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          'Cancel anytime • Secure payment',
          style: TextStyle(
            color: AppColors.textQuaternary,
            fontSize: 11,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 700.ms, duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADING OVERLAY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PURCHASE LOGIC - UNTOUCHED
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _purchase() async {
    setState(() => _isLoading = true);

    try {
      final success = _selectedPlanIndex == 0
          ? await PaymentService.instance.purchaseMonthlySubscription()
          : await PaymentService.instance.purchaseAnnualSubscription();

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Welcome to Premium! ${widget.feature} is now unlocked.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    try {
      final restored = await PaymentService.instance.restorePurchases();

      if (mounted) {
        if (restored) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored successfully!'),
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No previous purchases found.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
