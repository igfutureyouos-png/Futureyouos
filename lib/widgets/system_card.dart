import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/habit.dart';
import '../models/habit_system.dart';
import '../design/tokens.dart';

/// Beautiful glass morphism card for displaying habit systems
/// Two modes: Tickable (Home) or Read-only with Delete (Planner)
class SystemCard extends StatelessWidget {
  final HabitSystem system;
  final List<Habit> habits;
  final DateTime selectedDate; // Date to check completion status
  final Function(Habit)? onToggleHabit; // For Home page - ticking enabled
  final VoidCallback? onTap;
  final VoidCallback? onDelete; // For Planner page - delete entire system
  final VoidCallback? onDeleteHabits; // For Planner page - delete individual habits
  final bool showProgress;

  const SystemCard({
    super.key,
    required this.system,
    required this.habits,
    required this.selectedDate,
    this.onToggleHabit,
    this.onTap,
    this.onDelete,
    this.onDeleteHabits,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = habits.where((h) => h.done).length;
    final totalCount = habits.length;
    final completion = totalCount > 0 ? (completedCount / totalCount * 100).toInt() : 0;
    final gradient = LinearGradient(
      colors: system.gradientColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          child: Stack(
            children: [
              // Gradient Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),

              // Glass overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),
              ),

              // Animated particles
              Positioned.fill(
                child: _AnimatedParticles(),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        // System name/emoji
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppBorderRadius.md),
                          ),
                          child: Center(
                            child: Text(
                              system.name.isNotEmpty ? system.name[0].toUpperCase() : '⭐',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                system.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                onDelete != null
                                    ? '${habits.length} habits • Read-only'
                                    : '$completedCount/$totalCount habits today',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(onDelete != null ? 0.6 : 0.8),
                                  fontSize: 13,
                                  fontStyle: onDelete != null ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ✅ FIX 4: Stunning progress circle (only on Home page - when onToggleHabit is provided)
                        if (onToggleHabit != null) _buildProgressRing(completion, system.gradientColors.first),
                        // Delete individual habits button (orange)
                        if (onDeleteHabits != null)
                          GestureDetector(
                            onTap: onDeleteHabits,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                                color: Colors.orange.withOpacity(0.9),
                              ),
                            ),
                          ),
                        if (onDeleteHabits != null) const SizedBox(width: 8),
                        // Delete entire system button (red)
                        if (onDelete != null)
                          GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_sweep,
                                size: 18,
                                color: Colors.red.withOpacity(0.9),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Habits Grid
                    _buildHabitsGrid(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, duration: 400.ms);
  }

  Widget _buildProgressRing(int value, Color color) {
    const r = 22.0;
    const strokeWidth = 5.0;
    final c = 2 * 3.14159 * r;
    final offset = c * (1 - value / 100);

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: _ProgressRingPainter(
              value: value,
              color: color,
            ),
          ),
          Center(
            child: Text(
              '$value%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsGrid() {
    // ✅ FIX 1: One habit per line for better readability
    return Column(
      children: habits.map((habit) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildHabitTile(habit),
      )).toList(),
    );
  }

  Widget _buildHabitTile(Habit habit) {
    final accentColor = system.gradientColors.first;
    final isReadOnly = onToggleHabit == null; // Read-only if no toggle callback
    
    return GestureDetector(
      // Only allow tapping if onToggleHabit is provided AND habit not already done
      onTap: (onToggleHabit != null && !habit.done) 
          ? () => onToggleHabit!(habit) 
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isReadOnly ? 0.08 : 0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: Colors.white.withOpacity(isReadOnly ? 0.05 : 0.08),
          ),
        ),
        child: Row(
          children: [
            // Checkbox (tickable on Home) or Bullet (read-only on Planner)
            if (isReadOnly)
              // Read-only bullet indicator
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: accentColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )
            else
              // Tickable checkbox (Home page)
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: habit.done ? accentColor : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: habit.done ? accentColor : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: habit.done
                    ? const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
            SizedBox(width: isReadOnly ? 10 : 8),
            // Title
            Expanded(
              child: Text(
                habit.title,
                style: TextStyle(
                  color: Colors.white.withOpacity(isReadOnly ? 0.85 : 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: (!isReadOnly && habit.done) ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.white.withOpacity(0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Time if available (show in both modes)
            if (habit.time != null && habit.time!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 9,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      habit.time!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // _parseGradient method removed - now using system.gradientColors directly
}

class _AnimatedParticles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(6, (index) {
        return Positioned(
          left: (index * 37) % 100 + 10,
          top: (index * 53) % 100 + 10,
          child: Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: (800 + index * 200).ms)
              .then()
              .fadeOut(duration: (800 + index * 200).ms),
        );
      }),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final int value;
  final Color color;

  _ProgressRingPainter({
    required this.value,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2; // Start from top
    final sweepAngle = 2 * 3.14159 * (value / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

