import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import '../models/coach_message.dart';
import '../services/messages_service.dart';
import '../services/tts_playback_service.dart';
import '../services/elevenlabs_tts_service.dart';
import '../design/tokens.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 🔥 BEAUTIFUL NUDGE CARD - ORANGE COLLAPSIBLE BOX
/// Specifically for real-time nudges throughout the day
class NudgeCard extends StatefulWidget {
  final CoachMessage message;
  final VoidCallback onDismiss;
  final VoidCallback? onNavigateToReflections;
  final String? phase; // 'observer', 'architect', 'oracle'

  const NudgeCard({
    super.key,
    required this.message,
    required this.onDismiss,
    this.onNavigateToReflections,
    this.phase,
  });

  @override
  State<NudgeCard> createState() => _NudgeCardState();
}

class _NudgeCardState extends State<NudgeCard>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _glowController;
  late AnimationController _entranceController;
  late Animation<double> _glowAnimation;
  late Animation<double> _entranceSlide;
  late Animation<double> _entranceFade;
  
  // 🔊 TTS state
  bool _isPlaying = false;
  bool _hasAutoPlayed = false;

  @override
  void initState() {
    super.initState();
    
    // Pulsing glow effect (energetic for nudges)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Cinematic entrance animation
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _entranceSlide = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    ));

    _entranceController.forward();
    
    // 🔊 Auto-play TTS when nudge appears
    _autoPlayTTSIfNeeded();
  }
  
  /// 🔊 Auto-play ElevenLabs TTS on first appearance
  Future<void> _autoPlayTTSIfNeeded() async {
    // Wait for entrance animation
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!mounted) return;
    
    final alreadyPlayed = await ElevenLabsTTSService.hasAutoPlayed(widget.message.id);
    if (!alreadyPlayed && mounted) {
      setState(() {
        _hasAutoPlayed = true;
        _isPlaying = true;
      });
      
      // Get appropriate voice for nudge (drill sergeant style)
      final voiceKey = ElevenLabsTTSService.getVoiceForMessageType('nudge');
      final textToSpeak = '${widget.message.title}. ${widget.message.body}';
      
      final success = await ElevenLabsTTSService.autoPlayIfNeeded(
        messageId: widget.message.id,
        text: textToSpeak,
        voiceKey: voiceKey,
      );
      
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
      
      if (!success) {
        debugPrint('⚠️ ElevenLabs nudge failed, using device TTS fallback');
        // Fallback to device TTS if ElevenLabs fails
        await TTSPlaybackService.speakText(textToSpeak);
      }
    }
  }
  
  /// 🔊 Play/replay ElevenLabs TTS
  Future<void> _playTTS() async {
    setState(() {
      _isPlaying = true;
    });
    
    try {
      // Speak the nudge message using ElevenLabs drill voice
      final textToSpeak = '${widget.message.title}. ${widget.message.body}';
      final voiceKey = ElevenLabsTTSService.getVoiceForMessageType('nudge');
      
      final success = await ElevenLabsTTSService.speakText(
        text: textToSpeak,
        voiceKey: voiceKey,
      );
      
      if (!success) {
        debugPrint('⚠️ ElevenLabs nudge failed, using device TTS fallback');
        // Fallback to device TTS if ElevenLabs fails
        await TTSPlaybackService.speakText(textToSpeak);
      } else {
        debugPrint('✅ ElevenLabs nudge TTS successful with drill voice');
      }
      
    } catch (e) {
      debugPrint('❌ TTS failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await messagesService.markAsRead(widget.message.id);
    
    if (widget.onNavigateToReflections != null) {
      widget.onNavigateToReflections!();
    }
    
    widget.onDismiss();
  }

  /// Get phase-specific theme
  _PhaseTheme get _phaseTheme {
    final phase = widget.phase?.toLowerCase() ?? 'observer';
    
    switch (phase) {
      case 'architect':
        return _PhaseTheme(
          name: 'ARCHITECT',
          gradient: [
            const Color(0xFF667EEA), // Electric blue
            const Color(0xFF764BA2), // Deep purple
          ],
          accentColor: const Color(0xFF667EEA),
          emoji: '🔵',
        );
      case 'oracle':
        return _PhaseTheme(
          name: 'ORACLE',
          gradient: [
            const Color(0xFF8B5CF6), // Deep purple
            const Color(0xFFEC4899), // Pink
          ],
          accentColor: const Color(0xFF8B5CF6),
          emoji: '🟣',
        );
      default: // observer
        return _PhaseTheme(
          name: 'OBSERVER',
          gradient: [
            const Color(0xFFFFB800), // Gold
            const Color(0xFFFF6B35), // Orange
          ],
          accentColor: const Color(0xFFFFB800),
          emoji: '🟡',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _entranceSlide, _entranceFade]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _entranceSlide.value),
          child: Opacity(
            opacity: _entranceFade.value,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  // Outer glow (energetic orange)
                  BoxShadow(
                    color: _phaseTheme.accentColor.withOpacity(0.5 * _glowAnimation.value),
                    blurRadius: 45,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  // Inner shadow for depth
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: -5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _phaseTheme.gradient[0].withOpacity(0.2),
                          _phaseTheme.gradient[1].withOpacity(0.12),
                          Colors.black.withOpacity(0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: _phaseTheme.accentColor.withOpacity(0.5),
                        width: 2.5,
                      ),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: _isExpanded 
              ? const EdgeInsets.all(AppSpacing.xl)
              : const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Phase + Nudge indicator
                _buildHeader(),
                
                // Only show message body and actions when expanded
                if (_isExpanded) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildMessageBody(),
                  _buildActions(),
                ] else ...[
                  const SizedBox(height: AppSpacing.xs),
                  _buildExpandHint(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Phase Badge (smaller)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _phaseTheme.gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _phaseTheme.accentColor.withOpacity(0.6),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _phaseTheme.emoji,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                _phaseTheme.name,
                style: AppTextStyles.captionSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: AppSpacing.xs),
        
        // Nudge indicator (smaller)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.zap,
                color: Colors.white.withOpacity(0.95),
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                'NUDGE',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Lightning emoji + "Now"
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '⚡',
              style: const TextStyle(fontSize: 24),
            ),
            Text(
              'Now',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message text (with electric energy)
        Text(
          _isExpanded
              ? widget.message.body
              : _truncateText(widget.message.body, 120),
          style: AppTextStyles.body.copyWith(
            fontSize: 17,
            color: Colors.white.withOpacity(0.98),
            fontWeight: FontWeight.w600,
            height: 1.6,
            letterSpacing: 0.3,
          ),
          maxLines: _isExpanded ? null : 3,
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildExpandHint() {
    return Center(
      child: Text(
        'Tap to expand',
        style: AppTextStyles.caption.copyWith(
          color: _phaseTheme.accentColor.withOpacity(0.95),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Row(
        children: [
          // 🔊 TTS Play Button (always show)
          _ActionButton(
            label: '',
            icon: _isPlaying ? LucideIcons.volume2 : LucideIcons.volume1,
            onPressed: _playTTS,
            gradient: _phaseTheme.gradient,
            isPrimary: false,
          ),
          const SizedBox(width: AppSpacing.md),
          
          // OS Chat Button (Primary)
          Expanded(
            child: _ActionButton(
              label: 'OS Chat',
              icon: LucideIcons.messageCircle,
              onPressed: () {
                // Navigate to OS Chat tab
                if (widget.onNavigateToReflections != null) {
                  widget.onNavigateToReflections!();
                }
              },
              gradient: _phaseTheme.gradient,
              isPrimary: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          
          // Dismiss Button
          _ActionButton(
            label: '',
            icon: LucideIcons.x,
            onPressed: () async {
              await messagesService.markAsRead(widget.message.id);
              widget.onDismiss();
            },
            gradient: _phaseTheme.gradient,
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

class _PhaseTheme {
  final String name;
  final List<Color> gradient;
  final Color accentColor;
  final String emoji;

  _PhaseTheme({
    required this.name,
    required this.gradient,
    required this.accentColor,
    required this.emoji,
  });
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final List<Color> gradient;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.gradient,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 16,
          horizontal: isPrimary ? 28 : 16,
        ),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(colors: gradient)
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: isPrimary ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary
                  ? Colors.white
                  : Colors.white.withOpacity(0.8),
            ),
            if (isPrimary) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

