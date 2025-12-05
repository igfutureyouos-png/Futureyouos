import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../models/coach_message.dart';
import '../services/messages_service.dart';
import '../services/elevenlabs_tts_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/simple_header.dart';

class ReflectionsScreen extends StatefulWidget {
  const ReflectionsScreen({super.key});

  @override
  State<ReflectionsScreen> createState() => _ReflectionsScreenState();
}

class _ReflectionsScreenState extends State<ReflectionsScreen> {
  List<CoachMessage> _messages = [];
  MessageKind? _filter;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Mark all messages as read when opening screen (clears badge)
    messagesService.markAllAsRead();
  }

  Future<void> _loadMessages({bool syncFromBackend = true}) async {
    debugPrint('🔄 _loadMessages called (sync: $syncFromBackend)');
    
    // Only sync from backend if requested
    if (syncFromBackend) {
      debugPrint('🔄 Syncing messages from backend...');
      final success = await messagesService.syncMessages('test-user-felix');
      debugPrint('📊 Sync result: $success');
    }

    debugPrint('🔄 Getting messages from service, filter: $_filter');
    final newMessages = _filter == null
        ? messagesService.getAllMessages()
        : messagesService.getMessagesByKind(_filter!);

    // Deduplicate by message ID
    final uniqueMessages = <String, CoachMessage>{};
    for (final message in newMessages) {
      uniqueMessages[message.id] = message;
    }
    final deduplicatedMessages = uniqueMessages.values.toList();

    debugPrint('📨 Got ${newMessages.length} messages, ${deduplicatedMessages.length} unique');
    if (deduplicatedMessages.isNotEmpty) {
      debugPrint('   First message: ${deduplicatedMessages.first.id} - ${deduplicatedMessages.first.title}');
    }

    setState(() {
      _messages = deduplicatedMessages;
      debugPrint('📨 setState called, _messages now has ${_messages.length} items');
    });
  }

  void _setFilter(MessageKind? kind) {
    setState(() {
      _filter = kind;
    });
    _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadMessages,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header that disappears when scrolling
            SliverAppBar(
              expandedHeight: 80,
              floating: true,
              snap: true,
              pinned: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: const SimpleHeader(),
            ),
            // Content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Filters
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            isSelected: _filter == null,
                            onTap: () => _setFilter(null),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _FilterChip(
                            label: 'Briefs',
                            emoji: '🌅',
                            isSelected: _filter == MessageKind.brief,
                            onTap: () => _setFilter(MessageKind.brief),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _FilterChip(
                            label: 'Nudges',
                            emoji: '🔴',
                            isSelected: _filter == MessageKind.nudge,
                            onTap: () => _setFilter(MessageKind.nudge),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _FilterChip(
                            label: 'Debriefs',
                            emoji: '🌙',
                            isSelected: _filter == MessageKind.debrief,
                            onTap: () => _setFilter(MessageKind.debrief),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _FilterChip(
                            label: 'Letters',
                            emoji: '💌',
                            isSelected: _filter == MessageKind.letter,
                            onTap: () => _setFilter(MessageKind.letter),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _FilterChip(
                            label: 'Awakening',
                            emoji: '🌑',
                            isSelected: _filter == MessageKind.awakening,
                            onTap: () => _setFilter(MessageKind.awakening),
                          ),
                          // ✅ Removed Vault filter - moved to Habit Vault in Habit Master tab
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Messages list
                  _messages.isEmpty
                      ? _buildEmptyState()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Column(
                            children: _messages.asMap().entries.map((entry) {
                              final index = entry.key;
                              final message = entry.value;
                              
                              // Use special Awakening card for awakening messages
                              if (message.kind == MessageKind.awakening) {
                                return _AwakeningCard(
                                  message: message,
                                  index: index,
                                  onRead: () {
                                    messagesService.markAsRead(message.id);
                                    setState(() {});
                                  },
                                  onDelete: () async {
                                    debugPrint('🗑️ DELETE STARTED: ${message.id}');
                                    await messagesService.deleteMessage(message.id);
                                    debugPrint('🗑️ DELETE COMPLETED, RELOADING FROM HIVE...');
                                    await _loadMessages(syncFromBackend: false);
                                    debugPrint('🗑️ UI REFRESHED - ${_messages.length} messages remaining');
                                  },
                                );
                              }
                              
                              // Use standard Letter card for all other messages
                              return _LetterCard(
                                message: message,
                                index: index,
                                onRead: () {
                                  messagesService.markAsRead(message.id);
                                  setState(() {});
                                },
                                onDelete: () async {
                                  debugPrint('🗑️ DELETE STARTED: ${message.id}');
                                  await messagesService.deleteMessage(message.id);
                                  debugPrint('🗑️ DELETE COMPLETED, RELOADING FROM HIVE...');
                                  await _loadMessages(syncFromBackend: false);
                                  debugPrint('🗑️ UI REFRESHED - ${_messages.length} messages remaining');
                                },
                              );
                            }).toList(),
                          ),
                        ),

                  const SizedBox(height: 120), // Bottom padding for nav
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.sparkles,
              size: 64,
              color: AppColors.textQuaternary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No reflections yet',
              style: AppTextStyles.bodySemiBold.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Future You will reach out soon',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.emeraldGradient : null,
          color: isSelected ? null : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(
            color: isSelected
                ? AppColors.emeraldLight
                : AppColors.glassBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AWAKENING CARD - Special UI for 7-day welcome series with ElevenLabs TTS
// ═══════════════════════════════════════════════════════════════
class _AwakeningCard extends StatefulWidget {
  final CoachMessage message;
  final int index;
  final VoidCallback onRead;
  final Future<void> Function() onDelete;

  const _AwakeningCard({
    required this.message,
    required this.index,
    required this.onRead,
    required this.onDelete,
  });

  @override
  State<_AwakeningCard> createState() => _AwakeningCardState();
}

class _AwakeningCardState extends State<_AwakeningCard> {
  bool _isPlaying = false;

  /// 🔊 Play ElevenLabs TTS for awakening message
  Future<void> _playAwakeningTTS() async {
    setState(() {
      _isPlaying = true;
    });
    
    try {
      // Use user's selected voice from settings
      final textToSpeak = '${widget.message.title}. ${widget.message.body}';
      
      final success = await ElevenLabsTTSService.speakText(
        text: textToSpeak,
        // voiceKey: null, // Use user's selected voice
      );
      
      if (success) {
        debugPrint('✅ ElevenLabs awakening TTS successful with Buddha voice');
      } else {
        debugPrint('⚠️ ElevenLabs awakening failed, no fallback for awakening messages');
      }
      
    } catch (e) {
      debugPrint('❌ Awakening TTS failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
        // Darker, mystical gradient
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D3748).withOpacity(0.5), // Dark slate
            const Color(0xFF1A202C).withOpacity(0.3), // Darker slate
            Colors.black.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A), // Nearly black background
          borderRadius: BorderRadius.circular(AppBorderRadius.xxl - 2),
          border: Border.all(
            color: const Color(0xFF4A5568).withOpacity(0.3), // Subtle border
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with moon phase
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      widget.message.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'AWAKENING',
                      style: AppTextStyles.captionSmall.copyWith(
                        color: const Color(0xFF718096), // Muted gray
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title with special formatting
            Text(
              widget.message.title,
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w300, // Lighter weight for philosophical feel
                letterSpacing: 0.5,
                height: 1.4,
                color: const Color(0xFFE2E8F0), // Light gray
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Divider line
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF4A5568).withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Body text
            Text(
              widget.message.body,
              style: AppTextStyles.body.copyWith(
                color: const Color(0xFFA0AEC0), // Softer gray
                height: 1.8,
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Action buttons
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                // 🔊 ElevenLabs TTS Button
                _ActionButton(
                  label: _isPlaying ? 'Playing...' : 'Listen',
                  icon: _isPlaying ? LucideIcons.volume2 : LucideIcons.volume1,
                  onTap: _isPlaying ? () {} : () => _playAwakeningTTS(),
                ),
                _ActionButton(
                  label: 'Copy',
                  icon: LucideIcons.copy,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: widget.message.body));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(LucideIcons.check, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            const Text('Copied to clipboard'),
                          ],
                        ),
                        backgroundColor: const Color(0xFF4A5568),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                _ActionButton(
                  label: 'Share',
                  icon: LucideIcons.share2,
                  onTap: () async {
                    await Share.share(
                      '${widget.message.title}\n\n${widget.message.body}\n\n— Future-You OS',
                      subject: widget.message.title,
                    );
                  },
                ),
                _ActionButton(
                  label: 'Delete',
                  icon: LucideIcons.trash2,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        title: Text(
                          'Delete Message?',
                          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                        ),
                        content: Text(
                          'This awakening message will be permanently deleted.',
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: AppColors.textTertiary),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await widget.onDelete();
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: card
          .animate(delay: (widget.index * 80).ms)
          .fadeIn(duration: 600.ms)
          .slideY(begin: 0.15, end: 0, duration: 600.ms, curve: Curves.easeOutCubic)
          .then()
          .shimmer(
            duration: 3000.ms,
            delay: 800.ms,
            color: const Color(0xFF4A5568).withOpacity(0.1),
          ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LETTER CARD - Standard UI for briefs, debriefs, nudges, letters
// ═══════════════════════════════════════════════════════════════
class _LetterCard extends StatelessWidget {
  final CoachMessage message;
  final int index;
  final VoidCallback onRead;
  final Future<void> Function() onDelete;

  const _LetterCard({
    required this.message,
    required this.index,
    required this.onRead,
    required this.onDelete,
  });

  Color _getKindColor() {
    switch (message.kind) {
      case MessageKind.brief:
        return const Color(0xFFFFB800);
      case MessageKind.nudge:
        return const Color(0xFFFF6B6B);
      case MessageKind.debrief:
        return const Color(0xFF8B5CF6);
      case MessageKind.letter:
        return AppColors.emeraldLight;
      case MessageKind.mirror:
        return AppColors.cyan;
      case MessageKind.vault:
        return const Color(0xFFFFD700);
      case MessageKind.awakening:
        return const Color(0xFF4A5568); // Dark gray/slate for awakening journey
      default:
        return AppColors.emerald;
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.body));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.check, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Text('Copied to clipboard'),
          ],
        ),
        backgroundColor: AppColors.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareMessage() async {
    await Share.share(
      '${message.title}\n\n${message.body}\n\n— Future-You OS',
      subject: message.title,
    );
  }

  void _exportPNG(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('PNG export coming soon!'),
        backgroundColor: AppColors.textTertiary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Future<void> Function() deleteCallback) {
    debugPrint('🗑️ _confirmDelete called - showing dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Delete Message?',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'This message will be permanently deleted.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () async {
              debugPrint('🗑️ Dialog Delete button pressed');
              Navigator.pop(context);
              debugPrint('🗑️ Dialog closed, calling deleteCallback');
              await deleteCallback();
              debugPrint('🗑️ deleteCallback completed');
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kindColor = _getKindColor();

    final card = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
        gradient: LinearGradient(
          colors: [
            kindColor.withOpacity(0.35),
            AppColors.emerald.withOpacity(0.35),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kindColor.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(AppBorderRadius.xxl - 3),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          message.kindLabel.toUpperCase(),
                          style: AppTextStyles.captionSmall.copyWith(
                            color: kindColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // ✅ Removed "Future-You OS" label per user request
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              message.title,
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Body
            Text(
              message.body,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action buttons
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _ActionButton(
                  label: 'Copy',
                  icon: LucideIcons.copy,
                  onTap: () => _copyToClipboard(context),
                ),
                _ActionButton(
                  label: 'Share',
                  icon: LucideIcons.share2,
                  onTap: _shareMessage,
                ),
                _ActionButton(
                  label: 'Export',
                  icon: LucideIcons.download,
                  onTap: () => _exportPNG(context),
                  isPrimary: true,
                ),
                _ActionButton(
                  label: 'Delete',
                  icon: LucideIcons.trash2,
                  onTap: () => _confirmDelete(context, onDelete),
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: card
          .animate(delay: (index * 50).ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
          .then()
          .shimmer(duration: 2000.ms, delay: 500.ms, color: Colors.white.withOpacity(0.05)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.15)
              : isPrimary
                  ? AppColors.emerald.withOpacity(0.15)
                  : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withOpacity(0.4)
                : isPrimary
                    ? AppColors.emerald.withOpacity(0.4)
                    : AppColors.glassBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDestructive
                  ? Colors.red.shade400
                  : isPrimary
                      ? AppColors.emerald
                      : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.captionSmall.copyWith(
                color: isDestructive
                    ? Colors.red.shade400
                    : isPrimary
                        ? AppColors.emerald
                        : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
