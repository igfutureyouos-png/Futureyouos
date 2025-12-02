import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/premium_service.dart';

/// DEBUG ONLY: Quick toggle for testing premium status
/// Remove this before production or hide behind a debug flag
class PremiumDebugToggle extends StatefulWidget {
  const PremiumDebugToggle({super.key});

  @override
  State<PremiumDebugToggle> createState() => _PremiumDebugToggleState();
}

class _PremiumDebugToggleState extends State<PremiumDebugToggle> {
  bool _isPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await PremiumService.isPremium();
    setState(() {
      _isPremium = status;
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    await PremiumService.setPremium(!_isPremium);
    await _loadStatus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPremium ? '✅ Premium ENABLED (testing)' : '❌ Premium DISABLED (free tier)'),
          backgroundColor: _isPremium ? AppColors.emerald : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: _isPremium ? AppColors.emeraldGradient : null,
          color: _isPremium ? null : AppColors.baseDark2,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: _isPremium ? AppColors.emerald : AppColors.textTertiary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPremium ? LucideIcons.checkCircle : LucideIcons.circle,
              size: 18,
              color: _isPremium ? Colors.black : AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              _loading ? 'Loading...' : (_isPremium ? 'Premium ✨' : 'Free Tier'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _isPremium ? Colors.black : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

