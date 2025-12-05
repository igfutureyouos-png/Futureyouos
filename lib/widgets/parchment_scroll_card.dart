import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../models/coach_message.dart';
import '../services/messages_service.dart';
import '../services/tts_playback_service.dart';
import '../services/elevenlabs_tts_service.dart';
import '../design/tokens.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 🔥 THE MOST BEAUTIFUL SCROLL UI EVER CREATED
/// Ancient parchment that unfurls to reveal consciousness messages
class ParchmentScrollCard extends StatefulWidget {
  final List<CoachMessage> messages;
  final VoidCallback? onNavigateToReflections;
  final VoidCallback? onDismiss; // Callback when messages are dismissed
  final String? phase; // 'observer', 'architect', 'oracle'

  const ParchmentScrollCard({
    super.key,
    required this.messages,
    this.onNavigateToReflections,
    this.onDismiss,
    this.phase,
  });

  @override
  State<ParchmentScrollCard> createState() => _ParchmentScrollCardState();
}

class _ParchmentScrollCardState extends State<ParchmentScrollCard>
    with TickerProviderStateMixin {
  bool _isUnfurled = false;
  late AnimationController _unfurlController;
  late AnimationController _glowController;
  late AnimationController _entranceController;
  
  late Animation<double> _unfurlAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _entranceSlide;
  late Animation<double> _entranceFade;
  
  // 🔊 TTS state
  bool _isPlaying = false;
  bool _hasAutoPlayed = false;

  @override
  void initState() {
    super.initState();
    
    // Unfurl animation (when scroll opens)
    _unfurlController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _unfurlAnimation = CurvedAnimation(
      parent: _unfurlController,
      curve: Curves.easeOutCubic,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _unfurlController,
      curve: Curves.easeOutBack,
    ));

    // Mystical glow effect
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Cinematic entrance (materializes from above)
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _entranceSlide = Tween<double>(
      begin: -60.0,
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
    
    // 🔊 Auto-play TTS when scroll appears (if audio available)
    _autoPlayTTSIfNeeded();
  }
  
  /// 🔊 Auto-play ElevenLabs TTS on first appearance
  Future<void> _autoPlayTTSIfNeeded() async {
    // Wait for entrance animation to complete
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (!mounted) return;
    
    // Auto-play first message using ElevenLabs
    if (widget.messages.isNotEmpty) {
      final message = widget.messages.first;
      final alreadyPlayed = await ElevenLabsTTSService.hasAutoPlayed(message.id);
      
      if (!alreadyPlayed && mounted) {
        setState(() {
          _hasAutoPlayed = true;
          _isPlaying = true;
        });
        
        // Get appropriate voice for message type
        final voiceKey = ElevenLabsTTSService.getVoiceForMessageType(message.kind.name);
        final textToSpeak = '${message.title}. ${message.body}';
        
        final success = await ElevenLabsTTSService.autoPlayIfNeeded(
          messageId: message.id,
          text: textToSpeak,
          voiceKey: voiceKey,
        );
        
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
        
        if (success) {
          debugPrint('✅ ElevenLabs auto-play successful for ${message.kind.name}');
        } else {
          debugPrint('⚠️ ElevenLabs failed, trying device TTS fallback');
          // Fallback to device TTS if ElevenLabs fails
          await TTSPlaybackService.speakText(textToSpeak);
        }
      }
    }
  }
  
  /// 🔊 Play/replay ElevenLabs TTS
  Future<void> _playTTS() async {
    if (widget.messages.isEmpty) return;
    
    setState(() {
      _isPlaying = true;
    });
    
    try {
      // Get the first message text for TTS
      final message = widget.messages.first;
      final textToSpeak = '${message.title}. ${message.body}';
      
      // Get appropriate ElevenLabs voice for message type
      final voiceKey = ElevenLabsTTSService.getVoiceForMessageType(message.kind.name);
      
      // Try ElevenLabs first
      final success = await ElevenLabsTTSService.speakText(
        text: textToSpeak,
        voiceKey: voiceKey,
      );
      
      if (!success) {
        debugPrint('⚠️ ElevenLabs failed, using device TTS fallback');
        // Fallback to device TTS if ElevenLabs fails
        await TTSPlaybackService.speakText(textToSpeak);
      } else {
        debugPrint('✅ ElevenLabs TTS successful with voice: $voiceKey');
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
    _unfurlController.dispose();
    _glowController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _toggleUnfurl() {
    setState(() {
      _isUnfurled = !_isUnfurled;
      if (_isUnfurled) {
        _unfurlController.forward();
      } else {
        _unfurlController.reverse();
      }
    });
  }

  void _handleDismiss() async {
    // Mark all scroll messages as read
    for (final message in widget.messages) {
      await messagesService.markAsRead(message.id);
    }
    
    if (widget.onNavigateToReflections != null) {
      widget.onNavigateToReflections!();
    }
  }

  /// Get phase-specific theme
  _PhaseTheme get _phaseTheme {
    final phase = widget.phase?.toLowerCase() ?? 'observer';
    
    switch (phase) {
      case 'architect':
        return _PhaseTheme(
          gradient: [
            const Color(0xFF667EEA),
            const Color(0xFF764BA2),
          ],
          glowColor: const Color(0xFF667EEA),
          sealColor: const Color(0xFF667EEA),
        );
      case 'oracle':
        return _PhaseTheme(
          gradient: [
            const Color(0xFF8B5CF6),
            const Color(0xFFEC4899),
          ],
          glowColor: const Color(0xFF8B5CF6),
          sealColor: const Color(0xFF8B5CF6),
        );
      default: // observer
        return _PhaseTheme(
          gradient: [
            const Color(0xFFD4A574), // Aged gold
            const Color(0xFFC4965F), // Bronze
          ],
          glowColor: const Color(0xFFD4A574),
          sealColor: const Color(0xFFB8860B), // Dark goldenrod
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _unfurlAnimation,
        _rotationAnimation,
        _glowAnimation,
        _entranceSlide,
        _entranceFade,
      ]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _entranceSlide.value),
          child: Opacity(
            opacity: _entranceFade.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    // Mystical outer glow
                    BoxShadow(
                      color: _phaseTheme.glowColor.withOpacity(0.3 * _glowAnimation.value),
                      blurRadius: 50,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                    // Deep shadow for depth
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        // Ancient parchment gradient
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF4E4C1), // Cream parchment
                            const Color(0xFFE8D4A8), // Aged beige
                            const Color(0xFFD4C5A0), // Darker aged
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        // Subtle border for aged effect
                        border: Border.all(
                          color: const Color(0xFFC4965F).withOpacity(0.6),
                          width: 2,
                        ),
                      ),
                      child: child,
                    ),
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
          onTap: _toggleUnfurl,
          borderRadius: BorderRadius.circular(24),
          splashColor: _phaseTheme.glowColor.withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            padding: _isUnfurled 
              ? const EdgeInsets.all(AppSpacing.xl)
              : const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: _isUnfurled ? _buildUnfurledContent() : _buildRolledContent(),
          ),
        ),
      ),
    );
  }

  /// Rolled up state - shows preview (compact single line)
  Widget _buildRolledContent() {
    return Row(
      children: [
        // Wax seal (scroll emoji)
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _phaseTheme.sealColor.withOpacity(0.9),
                _phaseTheme.sealColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _phaseTheme.sealColor.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              LucideIcons.scroll,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        
        const SizedBox(width: AppSpacing.md),
        
        // Tap to unfurl text (no pill, no icon)
        Expanded(
          child: Text(
            'Tap to unfurl scroll',
            style: AppTextStyles.bodyMedium.copyWith(
              color: _phaseTheme.sealColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        
        // Animated sparkles on the right
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: 0.5 + (0.5 * (1 - (value - 0.5).abs() * 2)),
              child: Transform.scale(
                scale: 0.8 + (0.2 * (1 - (value - 0.5).abs() * 2)),
                child: Icon(
                  LucideIcons.sparkles,
                  color: _phaseTheme.sealColor,
                  size: 24,
                ),
              ),
            );
          },
          onEnd: () {
            // Loop the animation
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  /// Unfurled state - shows full messages
  Widget _buildUnfurledContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Decorative header
        _buildScrollHeader(),
        
        const SizedBox(height: AppSpacing.lg),
        
        // Messages
        ...widget.messages.asMap().entries.map((entry) {
          final index = entry.key;
          final message = entry.value;
          return Column(
            children: [
              if (index > 0) _buildDivider(),
              _buildMessageSection(message),
            ],
          );
        }).toList(),
        
        const SizedBox(height: AppSpacing.xl),
        
        // Actions
        _buildActions(),
      ],
    );
  }

  Widget _buildScrollHeader() {
    return Row(
      children: [
        // Wax seal (smaller when unfurled)
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _phaseTheme.sealColor.withOpacity(0.9),
                _phaseTheme.sealColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _phaseTheme.sealColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              LucideIcons.scrollText,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        
        const SizedBox(width: AppSpacing.md),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages from Future You',
                style: AppTextStyles.h3.copyWith(
                  color: const Color(0xFF5C4A3A),
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Consciousness System',
                style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFF8B7355),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        
        // Roll up hint
        Icon(
          LucideIcons.chevronUp,
          color: _phaseTheme.sealColor.withOpacity(0.6),
          size: 24,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFC4965F).withOpacity(0.4),
            const Color(0xFFC4965F).withOpacity(0.6),
            const Color(0xFFC4965F).withOpacity(0.4),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSection(CoachMessage message) {
    final messageColor = _getMessageColor(message.kind);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message type header
        Row(
          children: [
            Text(
              message.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message.kindLabel.toUpperCase(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: messageColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Text(
              _getMessageTime(message.kind),
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFF8B7355),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: AppSpacing.md),
        
        // Message body (with beautiful calligraphy-style text)
        Text(
          message.body,
          style: AppTextStyles.body.copyWith(
            color: const Color(0xFF3C3229), // Deep brown ink
            fontSize: 16,
            height: 1.7,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // 🔊 TTS Play Button (always show)
          _buildActionButton(
            label: '',
            icon: _isPlaying ? LucideIcons.volume2 : LucideIcons.volume1,
            onPressed: _playTTS,
            isPrimary: false,
          ),
          const SizedBox(width: AppSpacing.md),
          
          // OS Chat Button (Primary)
          Expanded(
            child: _buildActionButton(
              label: 'OS Chat',
              icon: LucideIcons.messageCircle,
              onPressed: () {
                // Navigate to OS Chat tab (index 2 in main screen)
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Trigger tab change to OS Chat (assuming it's index 2)
                // This will be handled by the navigation callback
                if (widget.onNavigateToReflections != null) {
                  widget.onNavigateToReflections!();
                }
              },
              isPrimary: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          
          // Dismiss Button
          _buildActionButton(
            label: '',
            icon: LucideIcons.x,
            onPressed: () async {
              try {
                debugPrint('📜 Dismissing scroll with ${widget.messages.length} messages');
                
                // Mark all messages as read to dismiss them
                for (final message in widget.messages) {
                  await messagesService.markAsRead(message.id);
                  debugPrint('✅ Marked ${message.kind.name} as read: ${message.id}');
                }
                
                // Small delay to ensure state updates propagate
                await Future.delayed(const Duration(milliseconds: 100));
                
                // Notify parent to refresh and hide the card
                if (widget.onDismiss != null) {
                  debugPrint('📜 Calling onDismiss callback');
                  widget.onDismiss!();
                }
              } catch (e) {
                debugPrint('❌ Error dismissing scroll: $e');
              }
            },
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 16,
          horizontal: isPrimary ? 20 : 16,
        ),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    _phaseTheme.sealColor,
                    _phaseTheme.sealColor.withOpacity(0.8),
                  ],
                )
              : null,
          color: isPrimary ? null : const Color(0xFFC4965F).withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _phaseTheme.sealColor.withOpacity(isPrimary ? 0.4 : 0.3),
            width: 2,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: _phaseTheme.sealColor.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: isPrimary ? MainAxisAlignment.start : MainAxisAlignment.center,
          mainAxisSize: isPrimary ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : _phaseTheme.sealColor,
            ),
            if (isPrimary && label.isNotEmpty) ...[
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

  Color _getMessageColor(MessageKind kind) {
    switch (kind) {
      case MessageKind.brief:
        return const Color(0xFFFF9500); // Morning orange
      case MessageKind.debrief:
        return const Color(0xFFC4B5A0); // Darker beige (like brief but darker)
      case MessageKind.letter:
        return const Color(0xFFFF2D55); // Letter pink
      default:
        return const Color(0xFF8B7355); // Default brown
    }
  }

  String _getMessageTime(MessageKind kind) {
    switch (kind) {
      case MessageKind.brief:
        return '7:00 AM';
      case MessageKind.debrief:
        return '9:00 PM';
      case MessageKind.letter:
        return 'Sunday';
      default:
        return 'Now';
    }
  }
}

class _PhaseTheme {
  final List<Color> gradient;
  final Color glowColor;
  final Color sealColor;

  _PhaseTheme({
    required this.gradient,
    required this.glowColor,
    required this.sealColor,
  });
}

