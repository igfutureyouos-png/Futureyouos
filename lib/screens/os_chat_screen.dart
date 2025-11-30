import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/api_client.dart';
import '../services/messages_service.dart';
import '../models/coach_message.dart' as model;

/// Unified message type for timeline (OS messages + chat)
class TimelineMessage {
  final String id;
  final String type; // 'os_brief', 'os_nudge', 'os_debrief', 'os_letter', 'user', 'ai'
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final model.MessageKind? osKind;

  TimelineMessage({
    required this.id,
    required this.type,
    required this.text,
    required this.timestamp,
    this.isRead = true,
    this.osKind,
  });
}

class OSChatScreen extends ConsumerStatefulWidget {
  const OSChatScreen({super.key});

  @override
  ConsumerState<OSChatScreen> createState() => _OSChatScreenState();
}

class _OSChatScreenState extends ConsumerState<OSChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessagesService _messagesService = MessagesService();
  
  List<TimelineMessage> _timeline = [];
  bool _isLoading = false;
  bool _initialized = false;
  String _currentPhase = 'Observer'; // Default phase

  @override
  void initState() {
    super.initState();
    _initializeMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeMessages() async {
    await _messagesService.init();
    await _loadTimeline();
    setState(() => _initialized = true);
    _scrollToBottom();
  }

  Future<void> _loadTimeline() async {
    // Load OS messages (briefs, nudges, debriefs, letters)
    final osMessages = _messagesService.getAllMessages();
    
    // Convert OS messages to timeline messages
    final timelineFromOS = osMessages.map((msg) {
      String type;
      switch (msg.kind) {
        case model.MessageKind.brief:
          type = 'os_brief';
          break;
        case model.MessageKind.nudge:
          type = 'os_nudge';
          break;
        case model.MessageKind.debrief:
        case model.MessageKind.mirror:
          type = 'os_debrief';
          break;
        case model.MessageKind.letter:
          type = 'os_letter';
          break;
        default:
          type = 'os_message';
      }
      
      return TimelineMessage(
        id: msg.id,
        type: type,
        text: '${msg.title}\n\n${msg.body}',
        timestamp: msg.createdAt,
        isRead: msg.isRead,
        osKind: msg.kind,
      );
    }).toList();

    // Merge and sort by timestamp (newest first for display, but we'll reverse for chat UI)
    _timeline = [...timelineFromOS];
    _timeline.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Oldest first (chat style)
    
    setState(() {});
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message to timeline
    final userMessage = TimelineMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _timeline.add(userMessage);
      _isLoading = true;
    });

    _inputController.clear();
    _scrollToBottom();

    try {
      // Send to AI OS chat endpoint
      final response = await ApiClient.sendChatMessageV2(text);

      if (response.success && response.data != null) {
        final aiText = response.data!['message'] as String? ?? 'No response';
        final phase = response.data!['phase'] as String?;
        
        if (phase != null) {
          setState(() {
            _currentPhase = phase.substring(0, 1).toUpperCase() + phase.substring(1);
          });
        }

        final aiMessage = TimelineMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          type: 'ai',
          text: aiText,
          timestamp: DateTime.now(),
        );

        setState(() {
          _timeline.add(aiMessage);
          _isLoading = false;
        });

        _scrollToBottom();
      } else {
        throw Exception(response.error ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Content - stays fixed, doesn't move with keyboard
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 220, // Fixed space for input + bottom nav
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Header
                      _buildHeader(),
                      
                      // Timeline messages
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final message = _timeline[index];
                              return _buildTimelineMessage(message);
                            },
                            childCount: _timeline.length,
                          ),
                        ),
                      ),

                      // Loading indicator
                      if (_isLoading)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.glassBackground,
                                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                    border: Border.all(
                                      color: AppColors.emerald.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        'Thinking...',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bottom padding
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),

                // Input area - ONLY this rises with keyboard
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 100 + keyboardHeight, // 100px for bottom nav, then keyboard height
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border(
                        top: BorderSide(color: AppColors.emerald.withOpacity(0.2)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.glassBackground,
                              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                              border: Border.all(
                                color: AppColors.emerald.withOpacity(0.2),
                              ),
                            ),
                            child: TextField(
                              controller: _inputController,
                              style: AppTextStyles.body,
                              maxLines: null,
                              decoration: InputDecoration(
                                hintText: 'Message your OS...',
                                hintStyle: AppTextStyles.body.copyWith(
                                  color: AppColors.textQuaternary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.emeraldGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: const Color(0xFF18181B),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl + 40,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            border: Border(
              bottom: BorderSide(
                color: AppColors.emerald.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'AI Operating System',
                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phase: $_currentPhase • Always watching',
                      style: AppTextStyles.captionSmall.copyWith(
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineMessage(TimelineMessage message) {
    // Handle different message types
    switch (message.type) {
      case 'os_brief':
        return _buildOSMessage(
          message: message,
          icon: LucideIcons.sunrise,
          color: const Color(0xFFFFB020), // Orange for morning
          label: 'MORNING BRIEF',
        );
      case 'os_nudge':
        return _buildOSMessage(
          message: message,
          icon: LucideIcons.alertCircle,
          color: const Color(0xFFEF4444), // Red for nudge
          label: 'NUDGE',
        );
      case 'os_debrief':
        return _buildOSMessage(
          message: message,
          icon: LucideIcons.moon,
          color: const Color(0xFF8B5CF6), // Purple for evening
          label: 'EVENING DEBRIEF',
        );
      case 'os_letter':
        return _buildOSMessage(
          message: message,
          icon: LucideIcons.mail,
          color: const Color(0xFF06B6D4), // Cyan for letter
          label: 'WEEKLY LETTER',
        );
      case 'user':
        return _buildUserMessage(message);
      case 'ai':
        return _buildAIMessage(message);
      default:
        return _buildAIMessage(message);
    }
  }

  Widget _buildOSMessage({
    required TimelineMessage message,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppBorderRadius.xl - 2),
                  topRight: Radius.circular(AppBorderRadius.xl - 2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(message.timestamp),
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textQuaternary,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SelectableText(
                message.text,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildUserMessage(TimelineMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.3),
                ),
              ),
              child: SelectableText(
                message.text,
                style: AppTextStyles.body.copyWith(
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIMessage(TimelineMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: Icon(
                          LucideIcons.copy,
                          size: 14,
                          color: AppColors.textTertiary.withOpacity(0.6),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

