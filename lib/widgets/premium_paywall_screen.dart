import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/payment_service.dart';
import '../services/premium_service.dart';

/// 💎 PREMIUM PAYWALL V2 - Conversion Optimized
/// Based on Calm, Headspace, Duolingo Super best practices
/// Key changes:
/// - Clear visual hierarchy (value → social proof → pricing → CTA)
/// - Horizontal plan selector with decoy effect
/// - Trust signals and transparency
/// - Proper spacing that works on all devices
/// - Subtle animations that don't distract
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
  // STATE - KEEP EXACTLY AS IS
  // ═══════════════════════════════════════════════════════════════════════════
  bool _isLoading = false;
  bool _isDeveloper = false;
  int _selectedPlanIndex = 1; // Default to annual (better conversion)

  @override
  void initState() {
    super.initState();
    _checkDeveloperStatus();
  }

  Future<void> _checkDeveloperStatus() async {
    final isDev = await PremiumService.isDeveloper();
    if (mounted) {
      setState(() {
        _isDeveloper = isDev;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD - COMPLETELY REDESIGNED FOR CONVERSION
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: AppColors.baseDark1,
      body: Stack(
        children: [
          // ─────────────────────────────────────────────────────────────────────
          // BACKGROUND - Subtle, not distracting
          // ─────────────────────────────────────────────────────────────────────
          _buildBackground(),

          // ─────────────────────────────────────────────────────────────────────
          // MAIN CONTENT - Scrollable for small screens
          // ─────────────────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Close button - top right, always visible
                _buildCloseButton(),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: isSmallScreen ? 8 : 16,
                    ),
                    child: Column(
                      children: [
                        // 1. HERO - Crown + Title
                        _buildHero(isSmallScreen),

                        SizedBox(height: isSmallScreen ? 20 : 32),

                        // 2. SOCIAL PROOF - Trust signals
                        _buildSocialProof(),

                        SizedBox(height: isSmallScreen ? 20 : 28),

                        // 3. VALUE PROPS - What they get
                        _buildValueProps(isSmallScreen),

                        SizedBox(height: isSmallScreen ? 24 : 32),

                        // 4. PRICING - Plan selector
                        _buildPricingSection(),

                        const SizedBox(height: 20),

                        // 5. CTA - Primary action
                        _buildCTA(),

                        const SizedBox(height: 16),

                        // 6. TRUST FOOTER - Restore + Terms
                        _buildTrustFooter(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─────────────────────────────────────────────────────────────────────
          // LOADING OVERLAY
          // ─────────────────────────────────────────────────────────────────────
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUND - Clean, premium feel
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBackground() {
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D1117), // Slightly blue-black
                AppColors.baseDark1,
                Color(0xFF0A0F0D), // Hint of emerald in black
              ],
            ),
          ),
        ),

        // Top glow - subtle
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
  // CLOSE BUTTON - Accessible but not prominent
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCloseButton() {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO SECTION - Crown + Title + Feature context
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHero(bool isSmallScreen) {
    return Column(
      children: [
        // Crown with glow
        Container(
          width: isSmallScreen ? 72 : 88,
          height: isSmallScreen ? 72 : 88,
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
          child: Icon(
            LucideIcons.crown,
            color: Colors.black,
            size: isSmallScreen ? 36 : 44,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

        SizedBox(height: isSmallScreen ? 16 : 24),

        // Title with gradient
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.emeraldGradient.createShader(bounds),
          child: Text(
            'Unlock Your Full Potential',
            style: TextStyle(
              fontSize: isSmallScreen ? 26 : 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

        const SizedBox(height: 8),

        // Subtitle - contextual
        Text(
          'Get ${widget.feature} and everything else',
          style: TextStyle(
            fontSize: isSmallScreen ? 15 : 16,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

        // Developer badge
        if (_isDeveloper) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.emerald.withOpacity(0.15),
                  AppColors.emerald.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.emerald.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.code2, color: AppColors.emerald, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Developer Access Enabled',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 13,
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
  // SOCIAL PROOF - Trust signals that convert
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSocialProof() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildProofItem('4.9', '★', 'App Store'),
          _buildProofDivider(),
          _buildProofItem('50K+', '', 'Active Users'),
          _buildProofDivider(),
          _buildProofItem('92%', '', 'Success Rate'),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
  }

  Widget _buildProofItem(String value, String suffix, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            if (suffix.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textQuaternary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProofDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withOpacity(0.08),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALUE PROPS - What they actually get
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildValueProps(bool isSmallScreen) {
    final features = [
      (
        icon: LucideIcons.messageCircle,
        title: 'Unlimited AI Conversations',
        subtitle: 'Chat with Future-You anytime, no limits',
      ),
      (
        icon: LucideIcons.target,
        title: 'Smart Habit Intelligence',
        subtitle: 'Personalized briefs, nudges & coaching',
      ),
      (
        icon: LucideIcons.sparkles,
        title: 'What-If Simulator',
        subtitle: 'See your future before you live it',
      ),
    ];

    return Column(
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;

        return Padding(
          padding: EdgeInsets.only(bottom: index < features.length - 1 ? 12 : 0),
          child: _buildFeatureRow(
            feature.icon,
            feature.title,
            feature.subtitle,
            isSmallScreen,
          ),
        )
            .animate()
            .fadeIn(delay: (500 + index * 100).ms, duration: 400.ms)
            .slideX(begin: -0.1, end: 0);
      }).toList(),
    );
  }

  Widget _buildFeatureRow(
    IconData icon,
    String title,
    String subtitle,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: isSmallScreen ? 44 : 48,
            height: isSmallScreen ? 44 : 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.emerald.withOpacity(0.2),
                  AppColors.emerald.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.emerald,
              size: isSmallScreen ? 22 : 24,
            ),
          ),

          const SizedBox(width: 14),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: isSmallScreen ? 13 : 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Checkmark
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.check,
              color: AppColors.emerald,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRICING SECTION - Horizontal cards with decoy effect
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPricingSection() {
    return Column(
      children: [
        // Section header
        Text(
          'Choose Your Plan',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 14),

        // Plan cards - horizontal
        Row(
          children: [
            // Monthly plan
            Expanded(
              child: _buildPlanCard(
                index: 0,
                title: 'Monthly',
                price: '\$6.99',
                period: '/month',
                subtitle: 'Flexible billing',
                badge: null,
              ),
            ),

            const SizedBox(width: 12),

            // Annual plan - RECOMMENDED (decoy effect)
            Expanded(
              child: _buildPlanCard(
                index: 1,
                title: 'Annual',
                price: '\$49.99',
                period: '/year',
                subtitle: '\$4.17/month',
                badge: 'SAVE 40%',
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 800.ms, duration: 400.ms);
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    required String period,
    required String subtitle,
    String? badge,
  }) {
    final isSelected = _selectedPlanIndex == index;
    final isRecommended = badge != null;

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
            color: isSelected
                ? AppColors.emerald
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: isSelected ? AppColors.emerald : Colors.white,
                        fontSize: 24,
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Subtitle
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isRecommended && isSelected
                        ? AppColors.emerald.withOpacity(0.8)
                        : AppColors.textQuaternary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // Selection indicator
                Container(
                  width: double.infinity,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.emerald
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),

            // Badge
            if (badge != null)
              Positioned(
                top: -10,
                right: -8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
  // CTA BUTTON - Primary conversion action
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCTA() {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: AppColors.emeraldGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.4),
            blurRadius: 24,
            spreadRadius: -4,
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.crown,
                        color: Colors.black,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Unlock Premium Now',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 900.ms, duration: 400.ms)
        .then()
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          duration: 2000.ms,
          begin: const Offset(1, 1),
          end: const Offset(1.015, 1.015),
        );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRUST FOOTER - Restore purchases + Terms
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTrustFooter() {
    return Column(
      children: [
        // Restore purchases
        TextButton(
          onPressed: _restorePurchases,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Restore Purchases',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Terms and transparency
        Text(
          'Cancel anytime in Settings • Secure payment',
          style: TextStyle(
            color: AppColors.textQuaternary,
            fontSize: 11,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 4),

        // Privacy & Terms links
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink('Privacy'),
            Text(
              ' • ',
              style: TextStyle(
                color: AppColors.textQuaternary,
                fontSize: 11,
              ),
            ),
            _buildFooterLink('Terms'),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 1000.ms, duration: 400.ms);
  }

  Widget _buildFooterLink(String text) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to privacy/terms
      },
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 11,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textQuaternary,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADING OVERLAY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
            ),
            const SizedBox(height: 16),
            Text(
              'Processing...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PURCHASE LOGIC - KEEP EXACTLY AS IS
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
