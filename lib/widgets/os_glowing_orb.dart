import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design/tokens.dart';
import '../services/os_metrics_service.dart';

/// 🌟 OS GLOWING ORB
/// Pulsing orb that visualizes system consciousness
/// Pulses faster when discipline is high, glows brighter when strong
class OSGlowingOrb extends StatefulWidget {
  final OSMetrics metrics;
  final double size;

  const OSGlowingOrb({
    super.key,
    required this.metrics,
    this.size = 120,
  });

  @override
  State<OSGlowingOrb> createState() => _OSGlowingOrbState();
}

class _OSGlowingOrbState extends State<OSGlowingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(OSGlowingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update pulse speed if discipline changed significantly
    if ((widget.metrics.discipline - oldWidget.metrics.discipline).abs() > 10) {
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    final pulseSpeed = OSMetricsService.getPulseSpeed(widget.metrics.discipline);
    
    _pulseController?.dispose();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: (pulseSpeed * 1000).round()),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _getGlowColor();
    final glowIntensity = _getGlowIntensity();

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: widget.size * _pulseAnimation.value,
            height: widget.size * _pulseAnimation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glowColor.withOpacity(0.8),
                  glowColor.withOpacity(0.4),
                  glowColor.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(glowIntensity * 0.4),
                  blurRadius: 60 * _pulseAnimation.value,
                  spreadRadius: 20 * _pulseAnimation.value,
                ),
                BoxShadow(
                  color: glowColor.withOpacity(glowIntensity * 0.2),
                  blurRadius: 100 * _pulseAnimation.value,
                  spreadRadius: 40 * _pulseAnimation.value,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.7,
                height: widget.size * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glowColor.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.metrics.discipline.round()}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.size * 0.25,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'OS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: widget.size * 0.12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getGlowColor() {
    final strength = widget.metrics.systemStrength;
    if (strength >= 80) {
      return AppColors.emerald;
    } else if (strength >= 50) {
      return AppColors.amber;
    } else {
      return AppColors.error;
    }
  }

  double _getGlowIntensity() {
    // Higher system strength = brighter glow
    return (widget.metrics.systemStrength / 100).clamp(0.3, 1.0);
  }
}

