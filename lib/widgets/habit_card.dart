import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/habit.dart';
import '../design/tokens.dart';
import 'glass_card.dart';
import 'glass_button.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  
  const HabitCard({
    super.key,
    required this.habit,
    this.onToggle,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  IconData get _habitIcon {
    switch (widget.habit.type) {
      case 'habit':
        return LucideIcons.flame;
      case 'task':
        return LucideIcons.alarmCheck;
      default:
        return LucideIcons.circle;
    }
  }
  
  Color get _iconColor {
    if (widget.habit.done) {
      return AppColors.success;
    }
    return widget.habit.color;
  }
  
  void _handleToggle() {
    if (widget.onToggle != null) {
      widget.onToggle!();
      
      // Animate completion
      if (widget.habit.done) {
        _animationController.forward().then((_) {
          _animationController.reverse();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          // Icon or Emoji container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              gradient: LinearGradient(
                colors: [
                  _iconColor.withOpacity(0.2),
                  _iconColor.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: _iconColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: widget.habit.emoji != null
                ? Center(
                    child: Text(
                      widget.habit.emoji!,
                      style: const TextStyle(fontSize: 28),
                    ),
                  )
                : Icon(
                    _habitIcon,
                    color: _iconColor,
                    size: 20,
                  ),
          ),
          
          const SizedBox(width: AppSpacing.md),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.habit.title,
                  style: AppTextStyles.bodySemiBold.copyWith(
                    decoration: widget.habit.done 
                        ? TextDecoration.lineThrough 
                        : null,
                    color: widget.habit.done 
                        ? AppColors.textTertiary 
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Only show time if it's not empty
                    if (widget.habit.time.isNotEmpty) ...[
                      const Icon(
                        LucideIcons.clock,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.habit.time,
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _iconColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                        border: Border.all(
                          color: _iconColor.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        widget.habit.type.toUpperCase(),
                        style: AppTextStyles.label.copyWith(
                          color: _iconColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Streak indicator - Left of toggle
              if (widget.habit.streak > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.flame,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.habit.streak}',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              // Toggle button
              GestureDetector(
                onTap: _handleToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    color: widget.habit.done 
                        ? AppColors.emerald 
                        : AppColors.textQuaternary,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: widget.habit.done 
                        ? Alignment.centerRight 
                        : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: widget.habit.done
                          ? const Icon(
                              LucideIcons.check,
                              size: 12,
                              color: AppColors.emerald,
                            )
                          : null,
                    ),
                  ),
                ),
              ).animate(target: widget.habit.done ? 1 : 0)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 200.ms,
                )
                .then()
                .scale(
                  begin: const Offset(1.1, 1.1),
                  end: const Offset(1, 1),
                  duration: 200.ms,
                ),
              
              const SizedBox(width: AppSpacing.sm),
              
              // Delete button
              GlassButton(
                onPressed: widget.onDelete,
                padding: const EdgeInsets.all(AppSpacing.sm),
                width: 32,
                height: 32,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                child: const Icon(
                  LucideIcons.x,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HabitProgressBar extends StatelessWidget {
  final double progress;
  final String label;
  final Color color;
  final Gradient? gradient;
  
  const HabitProgressBar({
    super.key,
    required this.progress,
    required this.label,
    this.color = AppColors.emerald,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 100.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              '${clampedProgress.toInt()}%',
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
            color: AppColors.glassBackground,
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: gradient ?? LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                  ),
                  transform: Matrix4.translationValues(
                    -(100 - clampedProgress) / 100 * MediaQuery.of(context).size.width,
                    0,
                    0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _getProgressMessage(clampedProgress),
          style: AppTextStyles.label.copyWith(
            color: AppColors.textQuaternary,
          ),
        ),
      ],
    );
  }
  
  String _getProgressMessage(double progress) {
    if (progress >= 100) {
      return "Perfect! All promises kept today.";
    } else if (progress >= 80) {
      return "Excellent progress! Keep pushing.";
    } else if (progress >= 60) {
      return "Good momentum. Stay consistent.";
    } else if (progress >= 40) {
      return "Building up. Every action counts.";
    } else if (progress >= 20) {
      return "Getting started. You've got this.";
    } else {
      return "Fresh start. Your future self is waiting.";
    }
  }
}
