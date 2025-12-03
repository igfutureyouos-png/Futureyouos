import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../services/os_metrics_service.dart';

/// 🎯 OS STATUS HUD
/// Glass morphism status bar showing discipline %, streak, and system strength
class OSStatusHUD extends StatelessWidget {
  final OSMetrics metrics;
  final bool animate;

  const OSStatusHUD({
    super.key,
    required this.metrics,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final disciplineColor = _getDisciplineColor();
    
    Widget hud = Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: disciplineColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: disciplineColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // DISCIPLINE %
          _buildMetric(
            label: 'Discipline',
            value: '${metrics.discipline.round()}%',
            color: disciplineColor,
            icon: Icons.bolt,
          ),
          
          // DIVIDER
          Container(
            height: 30,
            width: 1,
            color: AppColors.textQuaternary.withOpacity(0.2),
          ),
          
          // STREAK
          _buildMetric(
            label: 'Streak',
            value: '🔥 ${metrics.currentStreak}',
            color: AppColors.fire,
            icon: null,
          ),
          
          // DIVIDER
          Container(
            height: 30,
            width: 1,
            color: AppColors.textQuaternary.withOpacity(0.2),
          ),
          
          // SYSTEM STRENGTH
          _buildMetric(
            label: 'Strength',
            value: '${metrics.systemStrength.round()}%',
            color: _getStrengthColor(),
            icon: Icons.shield,
          ),
        ],
      ),
    );

    if (animate) {
      return hud.animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.3, duration: 400.ms, curve: Curves.easeOut);
    }

    return hud;
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required Color color,
    IconData? icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Color _getDisciplineColor() {
    final discipline = metrics.discipline;
    if (discipline >= 70) {
      return AppColors.emerald;
    } else if (discipline >= 50) {
      return AppColors.amber;
    } else {
      return AppColors.error;
    }
  }

  Color _getStrengthColor() {
    final strength = metrics.systemStrength;
    if (strength >= 80) {
      return AppColors.emerald;
    } else if (strength >= 50) {
      return AppColors.amber;
    } else {
      return AppColors.error;
    }
  }
}

