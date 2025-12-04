import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/api_client.dart';
import '../services/premium_service.dart';
import '../services/habit_vault_service.dart';
import '../models/vault_item.dart';
import '../widgets/paywall_dialog.dart';
import '../widgets/simple_header.dart';
import '../lifetask/widgets/feature_card.dart';

class VideoData {
  final int id;
  final String title;
  final String description;
  final String duration;
  final List<Color> thumbnailGradient;

  VideoData({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.thumbnailGradient,
  });
}

class DiscoveryPrompt {
  final IconData icon;
  final String text;

  DiscoveryPrompt({
    required this.icon,
    required this.text,
  });
}

class FutureYouScreen extends StatefulWidget {
  const FutureYouScreen({super.key});

  @override
  State<FutureYouScreen> createState() => _FutureYouScreenState();
}

class _FutureYouScreenState extends State<FutureYouScreen> {
  bool _chatExpanded = false;
  VideoData? _selectedVideo;
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      role: 'future',
      text: "Welcome. I'm here to help you discover your life's purpose. Let's start with something simple...",
      timestamp: DateTime.now(),
    ),
    ChatMessage(
      id: '2',
      role: 'future',
      text: "Close your eyes for a moment. When you were a child, what activity made you lose track of time?",
      timestamp: DateTime.now(),
    ),
  ];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<VideoData> _videos = [
    VideoData(
      id: 1,
      title: 'The Funeral Exercise',
      description: 'Walk into your own funeral. What do you want them to say?',
      duration: '3:42',
      thumbnailGradient: [
        const Color(0x33FB7185),
        const Color(0x33A855F7),
      ],
    ),
    VideoData(
      id: 2,
      title: 'The Last Day',
      description: 'If today was your last, what would you regret not doing?',
      duration: '2:18',
      thumbnailGradient: [
        const Color(0x333B82F6),
        const Color(0x3306B6D4),
      ],
    ),
    VideoData(
      id: 3,
      title: 'Your Hero\'s Journey',
      description: 'What challenge is calling you to become more?',
      duration: '4:05',
      thumbnailGradient: [
        const Color(0x33F59E0B),
        const Color(0x33F97316),
      ],
    ),
  ];

  final List<DiscoveryPrompt> _discoveryPrompts = [
    DiscoveryPrompt(icon: LucideIcons.lightbulb, text: 'What don\'t you like?'),
    DiscoveryPrompt(icon: LucideIcons.heart, text: 'What makes you feel most alive?'),
    DiscoveryPrompt(icon: LucideIcons.target, text: 'What did you get lost in as a child?'),
    DiscoveryPrompt(icon: LucideIcons.trendingUp, text: 'What would you do if money wasn\'t an issue?'),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _inputController.text.trim();
    if (message.isEmpty) return;

    // ✅ PAYWALL: Check premium status before allowing Future You chat
    final isPremium = await PremiumService.isPremium();
    if (!isPremium) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => const PaywallDialog(feature: 'Future You Chat'),
        );
      }
      return;
    }

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      text: message,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _inputController.clear();
    });

    _scrollToBottom();

    try {
      // Use new Future-You freeform chat (7 lenses + memory + contradictions)
      final result = await ApiClient.sendFutureYouMessage(message);

      if (result.success && result.data != null) {
        // 🔥 Safe extraction: handle both String and List formats
        String aiMessage;
        final messageData = result.data!['message'];
        if (messageData is String) {
          aiMessage = messageData;
        } else if (messageData is List && messageData.isNotEmpty) {
          aiMessage = messageData[0].toString();
        } else {
          aiMessage = 'No response';
        }

        final responseMessage = ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          role: 'future',
          text: aiMessage,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(responseMessage);
          _isLoading = false;
        });

        debugPrint('✅ Future-You freeform response received');
      } else {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        
        // Check if it's a paywall error
        if (result.error?.contains('Premium') == true || result.error?.contains('premium') == true) {
          showDialog(
            context: context,
            builder: (context) => const PaywallDialog(feature: 'Future You Chat'),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Chat failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ Future-You chat error: $e');
      if (!mounted) return;
      
      // Check if it's a premium error in the exception message
      if (e.toString().toLowerCase().contains('premium')) {
        showDialog(
          context: context,
          builder: (context) => const PaywallDialog(feature: 'Future You Chat'),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    _scrollToBottom();
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

  void _openChatWithPrompt(String prompt) {
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      text: prompt,
      timestamp: DateTime.now(),
    );

    final aiResponse = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      role: 'future',
      text: 'Great question to explore. Take your time and really think about this...',
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(aiResponse);
      _chatExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Main content with scrollable header
          CustomScrollView(
            slivers: [
              // Header that disappears when scrolling
              SliverAppBar(
                expandedHeight: 88, // Slightly taller so 'p' and 'g' descenders show fully
                floating: true,
                snap: true,
                pinned: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: const SimpleHeader(
                  tabName: 'Purpose Engine',
                  tabColor: Color(0xFFEF4444), // Beautiful vibrant red (distinct from Today tab)
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ Removed _buildHeroSection() - "Life Purpose Discovery" card
                      _buildLifeTaskFeatureCards(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildVisualizationVideos(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildDiscoveryPrompts(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildStartSessionButton(),
                      const SizedBox(height: 150), // Bottom padding for nav
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Video player overlay
          if (_selectedVideo != null) _buildVideoPlayerOverlay(),

          // Chat is now a separate full-screen route (no overlay)
        ],
      ),
    );
  }

  // ✅ _buildHeroSection() removed - no longer needed

  Widget _buildLifeTaskFeatureCards() {
    // TODO: Track actual progress from backend
    final chaptersComplete = 0; // Will be dynamic later
    final progressPercent = (chaptersComplete / 7 * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),

        // Card 1: The Book of Purpose (Main Journey)
        FeatureCard(
          title: 'The Book of Purpose', // ✅ More compact, single line
          subtitle: 'Begin your 7-chapter cinematic journey of purpose discovery',
          badge: '7 Chapter Journey',
          icon: LucideIcons.bookOpen,
          gradientColors: [
            const Color(0xFFEF4444), // Beautiful vibrant red (matches header)
            const Color(0xFFDC2626), // Darker red
          ],
          progressText: chaptersComplete > 0 ? '$chaptersComplete of 7 Chapters' : 'Start Journey',
          progressValue: chaptersComplete > 0 ? progressPercent : null,
          glowEffect: true, // Main feature - always glowing
          onTap: () => Navigator.pushNamed(context, '/cinematic'),
        ),

        // Card 2: Vault (Artifacts)
        FeatureCard(
          title: 'Purpose Vault',
          subtitle: 'Your story map, flow states, and life\'s task artifacts',
          badge: '8 Artifacts',
          icon: LucideIcons.archive,
          gradientColors: [
            const Color(0xFF10b981), // Emerald
            const Color(0xFF3b82f6), // Blue
          ],
          progressText: 'Complete chapters to unlock',
          onTap: () {
            // TODO: Navigate to vault when ready
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Complete Chapter 1 to unlock your vault'),
                backgroundColor: AppColors.emerald,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),

        // Card 3: Your Book (Final compilation)
        FeatureCard(
          title: 'Your Purpose Book',
          subtitle: 'Read, share, and export your completed 3,500-word book',
          badge: 'Publishable',
          icon: LucideIcons.fileText,
          gradientColors: [
            const Color(0xFFf59e0b), // Amber
            const Color(0xFFef4444), // Red
          ],
          progressText: 'Complete all 7 chapters',
          onTap: () {
            // TODO: Navigate to book reader when ready
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Complete all chapters to compile your book'),
                backgroundColor: AppColors.emerald,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVisualizationVideos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visualization Exercises',
          style: AppTextStyles.bodySemiBold.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._videos.asMap().entries.map((entry) {
          final index = entry.key;
          final video = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildVideoCard(video, index),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildVideoCard(VideoData video, int index) {
    return GestureDetector(
      onTap: () => setState(() => _selectedVideo = video),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          gradient: LinearGradient(
            colors: video.thumbnailGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: AppColors.emerald.withOpacity(0.2),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: const Icon(
                LucideIcons.play,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    video.description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              video.duration,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textQuaternary,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildDiscoveryPrompts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Start Questions',
          style: AppTextStyles.bodySemiBold.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._discoveryPrompts.asMap().entries.map((entry) {
          final index = entry.key;
          final prompt = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: GestureDetector(
              onTap: () => _openChatWithPrompt(prompt.text),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppColors.emerald.withOpacity(0.2),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        border: Border.all(
                          color: AppColors.emerald.withOpacity(0.2),
                        ),
                      ),
                      child: Icon(
                        prompt.icon,
                        size: 20,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        prompt.text,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: (index * 80).ms).fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStartSessionButton() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FutureYouChatScreen(messages: _messages),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.emeraldGradient,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.messageCircle,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Start Deep Discovery Session',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildVideoPlayerOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _selectedVideo = null),
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping content
            child: _VideoPlayer(
              video: _selectedVideo!,
              onClose: () => setState(() => _selectedVideo = null),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildChatOverlay() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Scrollable content (header + messages)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 140, // Space for input at bottom
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Scrollable Header
                SliverAppBar(
                  expandedHeight: 80, // Header height
                  floating: true,
                  snap: true,
                  pinned: false,
                  backgroundColor: const Color(0xFF18181B),
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Deep Discovery Session',
                                  style: AppTextStyles.h3.copyWith(
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_messages.where((m) => m.role == 'user').length} insights captured',
                                  style: AppTextStyles.captionSmall.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => setState(() => _chatExpanded = false),
                              icon: const Icon(
                                LucideIcons.x,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Messages
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message, index);
                      },
                      childCount: _messages.length,
                    ),
                  ),
                ),

                // Loading indicator as a sliver
                if (_isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.emerald,
                                    ),
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

                // Bottom padding for input field
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),

          // Input area (moves with keyboard, nav stays fixed)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom, // Rises with keyboard
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                140, // Extra space above nav tabs
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                border: Border(
                  top: BorderSide(
                    color: AppColors.emerald.withOpacity(0.2),
                  ),
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
                          hintText: 'Share what\'s on your mind...',
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
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: isUser ? AppColors.emeraldGradient : null,
                color: isUser ? null : AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(
                  color: isUser
                      ? AppColors.emerald.withOpacity(0.3)
                      : AppColors.emerald.withOpacity(0.2),
                ),
              ),
              child: isUser
                  ? Text(
                      message.text,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          message.text,
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: message.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Copied!'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: AppColors.emerald,
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
    ).animate(delay: (index * 50).ms).fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

// Video player component
class _VideoPlayer extends StatefulWidget {
  final VideoData video;
  final VoidCallback onClose;

  const _VideoPlayer({
    required this.video,
    required this.onClose,
  });

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> with SingleTickerProviderStateMixin {
  bool _playing = true;
  double _progress = 0.0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Simulate video progress
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_playing && mounted && _progress < 100) {
        setState(() {
          _progress += 0.5;
        });
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
        border: Border.all(
          color: AppColors.emerald.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppBorderRadius.xxl),
                ),
                gradient: LinearGradient(
                  colors: widget.video.thumbnailGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppBorderRadius.xxl),
                      ),
                      color: Colors.black.withOpacity(0.4 * (1 - _pulseController.value * 0.3)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.video.title,
                            style: AppTextStyles.h2,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            widget.video.description,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          GestureDetector(
                            onTap: () => setState(() => _playing = !_playing),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _playing ? LucideIcons.pause : LucideIcons.play,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _playing = !_playing),
                      icon: Icon(
                        _playing ? LucideIcons.pause : LucideIcons.play,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _progress = 0),
                      icon: const Icon(
                        LucideIcons.rotateCcw,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.glassBackground,
                          borderRadius: BorderRadius.circular(AppBorderRadius.full),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progress / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.emeraldGradient,
                              borderRadius: BorderRadius.circular(AppBorderRadius.full),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      widget.video.duration,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'After watching, reflect on the questions that emerge',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onClose,
                      child: Text(
                        'Close',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Full-screen Future-You Chat Screen (no bottom nav!)
class _FutureYouChatScreen extends StatefulWidget {
  final List<ChatMessage> messages;

  const _FutureYouChatScreen({
    required this.messages,
  });

  @override
  State<_FutureYouChatScreen> createState() => _FutureYouChatScreenState();
}

class _FutureYouChatScreenState extends State<_FutureYouChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.messages);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = ChatMessage(
      id: DateTime.now().toString(),
      role: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _inputController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    try {
      final response = await ApiClient.sendFutureYouMessage(text);

      if (response.success && response.data != null) {
        // 🔥 Use 'message' field (string) from backend, NOT 'chat' (array)
        final aiText = response.data!['message'] as String? ?? 'No response';
        
        final aiMessage = ChatMessage(
          id: DateTime.now().toString(),
          role: 'future',
          text: aiText,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
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

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // We handle keyboard manually
      body: SafeArea(
        child: Stack(
          children: [
            // Content
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 80 + keyboardHeight, // Adjust for keyboard!
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Header with back button
                  SliverAppBar(
                    expandedHeight: 80,
                    floating: true,
                    snap: true,
                    pinned: false,
                    backgroundColor: const Color(0xFF18181B),
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        margin: const EdgeInsets.only(top: 50),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B),
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.emerald.withOpacity(0.2),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Future-You Discovery',
                                    style: AppTextStyles.h3.copyWith(fontSize: 18),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Uncover your true calling through deep reflection',
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
                  ),

                  // Messages
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                        childCount: _messages.length,
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
                                    'Reflecting...',
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

            // Input (rises with keyboard, NO bottom nav!)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom,
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
                            hintText: 'Share what\'s on your mind...',
                            hintStyle: AppTextStyles.body.copyWith(
                              color: AppColors.textQuaternary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(AppSpacing.md),
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
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    final isCard = message.role == 'card';
    
    // 🧠 Insight Card rendering
    if (isCard && message.outputCard != null) {
      return _buildInsightCard(message.outputCard!);
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: isUser
                ? Container(
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
                  )
                : SelectableText(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  // 🧠 Insight Card Widget (Beautiful Phase Completion Card)
  Widget _buildInsightCard(Map<String, dynamic> card) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F2E), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.emerald.withOpacity(0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with phase name
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.emeraldGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '🧠',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    card['title'] ?? 'Phase Insight',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                if (card['summary'] != null) ...[
                  SelectableText(
                    card['summary'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Bullets
                if (card['bullets'] != null) ...[
                  ...((card['bullets'] as List?) ?? []).map((bullet) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: AppColors.emerald, fontSize: 16)),
                          Expanded(
                            child: SelectableText(
                              bullet.toString(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Next step
                if (card['nextStep'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.emerald.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('🎯 ', style: const TextStyle(fontSize: 16)),
                        Expanded(
                          child: SelectableText(
                            card['nextStep'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Sources
                if (card['sources'] != null && (card['sources'] as List).isNotEmpty) ...[
                  Text(
                    '📚 SOURCES',
                    style: TextStyle(
                      color: AppColors.emerald,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    (card['sources'] as List).join(' • '),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _saveToVault(card),
                        icon: const Text('💾', style: TextStyle(fontSize: 16)),
                        label: const Text('Save to Vault'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald.withOpacity(0.2),
                          foregroundColor: AppColors.emerald,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyCard(card),
                        icon: const Text('📋', style: TextStyle(fontSize: 16)),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.emerald.withOpacity(0.3)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ Save to Habit Vault (local-first)
  Future<void> _saveToVault(Map<String, dynamic> card) async {
    try {
      final cardText = '${card['title']}\n\n${card['summary']}\n\n${(card['bullets'] as List?)?.join('\n• ') ?? ''}';
      
      final vaultItem = HabitVaultItem.fromContent(
        title: card['title'] ?? 'Life Task Discovery',
        summary: card['summary'],
        content: cardText,
        goalType: 'life-task',
      );
      
      final success = await HabitVaultService.saveItem(vaultItem);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💾 Saved to Habit Vault! Check Habit Master tab.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _copyCard(Map<String, dynamic> card) {
    final cardText = '${card['title']}\n\n${card['summary']}\n\n${(card['bullets'] as List?)?.join('\n• ') ?? ''}';
    Clipboard.setData(ClipboardData(text: cardText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard! 📋'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.emerald,
        ),
      );
    }
  }
}

