import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../design/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/scrollable_header.dart';
import '../providers/habit_provider.dart';
import '../services/api_client.dart';
import '../services/premium_service.dart';
import '../widgets/paywall_dialog.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Insight data structures
class UniversityInsight {
  final String university;
  final String emoji;
  final String year;
  final String title;
  final String finding;
  final String? longDescription;
  final String? sampleSize;
  final String topic; // 'lifetask' or 'habit'
  final Color tintColor;

  UniversityInsight({
    required this.university,
    required this.emoji,
    required this.year,
    required this.title,
    required this.finding,
    this.longDescription,
    this.sampleSize,
    required this.topic,
    required this.tintColor,
  });
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _messageVoiceUrls = {};
  
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      role: 'future',
      text: "I'm Future You. Tell me who you want to be and by when. I'll turn it into daily commitments.",
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];
  
  List<QuickCommit> _quickCommits = [];
  bool _isLoading = false;
  bool _presetsOpen = true; // Open by default
  String _presetMode = 'lifetask'; // 'lifetask' or 'habit'
  final Map<String, List<UniversityInsight>> _messageInsights = {}; // Track insights per message
  
  // University research insights database
  final List<UniversityInsight> _insightDatabase = [
    UniversityInsight(
      university: 'Harvard',
      emoji: '🟥',
      year: '2014',
      title: 'Identity-Based Habits',
      finding: 'Identity framing increased adherence 2–3× over time.',
      longDescription: '"I am" language sustained behaviour longer than outcome framing.',
      sampleSize: 'n≈180',
      topic: 'habit',
      tintColor: const Color(0xFFF43F5E),
    ),
    UniversityInsight(
      university: 'MIT',
      emoji: '⚙️',
      year: '2005',
      title: 'Basal Ganglia & Habit Loops',
      finding: 'Cue-Routine-Reward consolidation explains stacking on stable cues.',
      longDescription: 'Cues chunk routines into automated sequences.',
      sampleSize: 'rats + human fMRI',
      topic: 'habit',
      tintColor: const Color(0xFF71717A),
    ),
    UniversityInsight(
      university: 'Stanford',
      emoji: '❤️',
      year: '2018',
      title: 'Tiny Habits',
      finding: '30-second anchored actions dramatically raise success.',
      longDescription: 'Micro-actions tied to daily anchors boosted consistency.',
      sampleSize: 'field cohorts',
      topic: 'habit',
      tintColor: const Color(0xFFEF4444),
    ),
    UniversityInsight(
      university: 'Cornell',
      emoji: '💚',
      year: '2010',
      title: 'Mind-Wandering & Purpose',
      finding: 'Directed reflection raises goal salience.',
      longDescription: 'Daily "why this matters" prompts improved subsequent focus.',
      sampleSize: 'n≈124',
      topic: 'lifetask',
      tintColor: AppColors.emerald,
    ),
    UniversityInsight(
      university: 'Cambridge',
      emoji: '💜',
      year: '2015',
      title: 'Flow & Skill-Challenge',
      finding: 'Flow peaks when challenge slightly exceeds skill.',
      longDescription: 'Operate at the edge of competence.',
      sampleSize: 'lab + diary',
      topic: 'lifetask',
      tintColor: const Color(0xFF8B5CF6),
    ),
  ];
  
  final Map<String, List<Map<String, String>>> _presets = {
    'lifetask': [
      {'title': 'Funeral Vision', 'prompt': 'If I died tomorrow, what would I regret not starting?'},
      {'title': 'Childhood Sparks', 'prompt': '3 kid-era activities that erased time; extract the skills.'},
      {'title': 'Anti-Values', 'prompt': '3 things that irritate me — choose 1 to reduce 1% for 10 people.'},
      {'title': 'Long vs Short', 'prompt': 'One 10-year North Star and one 10-day micro-proof.'},
      {'title': 'Purpose Synthesis', 'prompt': 'Write: "I devote my life to…" — first raw draft.'},
    ],
    'habit': [
      {'title': 'Nutrition Ritual', 'prompt': 'Describe your morning fuel; pick one optimization for this week.'},
      {'title': 'Meditation Primer', 'prompt': 'Where can you sit quietly for 2 minutes today?'},
      {'title': 'Keystone Habit', 'prompt': 'Which habit improves everything else when present?'},
      {'title': 'Good Habit Studies', 'prompt': 'What\'s your cue? MIT shows cues drive loops more than willpower.'},
      {'title': 'Habit Formula', 'prompt': 'After I [existing routine], I will [new habit].'},
    ],
  };
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // Removed date selection bar from chat screen
  
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // ✅ PAYWALL: Check premium status before allowing AI chat
    final isPremium = await PremiumService.isPremium();
    if (!isPremium) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => const PaywallDialog(feature: 'AI Chat'),
        );
      }
      return;
    }
    
    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      text: message,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _messageController.clear();
    });
    
    _scrollToBottom();
    
    // Call real backend chat API (/api/v1/chat)
    try {
      final result = await ApiClient.sendChatMessageV2(message);
      
      if (result.success && result.data != null) {
        final phase = result.data!['phase'] as String?;
        final aiMessage = result.data!['message'] as String;
        
        final responseMessage = ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          role: 'future',
          text: aiMessage,
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _messages.add(responseMessage);
          _quickCommits = []; // Backend doesn't send quick commits for phase-based chat
          _isLoading = false;
        });
        
        // Pick relevant insights for this AI response
        _pickInsights(message, responseMessage.id);
        
        debugPrint('✅ Chat response received (phase: $phase)');
      } else {
        setState(() { _isLoading = false; });
        if (!mounted) return;
        
        // Check if it's a paywall error
        if (result.error?.contains('Premium') == true || result.error?.contains('premium') == true) {
          showDialog(
            context: context,
            builder: (context) => const PaywallDialog(feature: 'AI Chat'),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Chat failed'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _sendMessage(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      debugPrint('❌ Chat error: $e');
      if (!mounted) return;
      
      // Check if it's a premium error in the exception message
      if (e.toString().toLowerCase().contains('premium')) {
        showDialog(
          context: context,
          builder: (context) => const PaywallDialog(feature: 'AI Chat'),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendMessage(),
            ),
          ),
      );
    }
    
    _scrollToBottom();
  }
  
  List<UniversityInsight> _pickInsights(String messageText, String messageId) {
    // Filter insights by current preset mode
    final relevantInsights = _insightDatabase
        .where((insight) => insight.topic == _presetMode)
        .toList();
    
    // Pick up to 3 insights based on keywords in message
    final insights = <UniversityInsight>[];
    
    // Prioritize based on message content
    if (messageText.toLowerCase().contains('tiny') || 
        messageText.toLowerCase().contains('smallest') ||
        messageText.toLowerCase().contains('micro')) {
      // Stanford first
      final stanford = relevantInsights.firstWhere(
        (i) => i.university == 'Stanford',
        orElse: () => relevantInsights.first,
      );
      insights.add(stanford);
    }
    
    if (messageText.toLowerCase().contains('identity') || 
        messageText.toLowerCase().contains('system')) {
      // Harvard first
      final harvard = relevantInsights.firstWhere(
        (i) => i.university == 'Harvard',
        orElse: () => relevantInsights.first,
      );
      if (!insights.contains(harvard)) insights.add(harvard);
    }
    
    if (messageText.toLowerCase().contains('cue') || 
        messageText.toLowerCase().contains('trigger')) {
      // MIT first
      final mit = relevantInsights.firstWhere(
        (i) => i.university == 'MIT',
        orElse: () => relevantInsights.first,
      );
      if (!insights.contains(mit)) insights.add(mit);
    }
    
    // Fill up to 3 with remaining relevant insights
    for (final insight in relevantInsights) {
      if (insights.length >= 3) break;
      if (!insights.contains(insight)) insights.add(insight);
    }
    
    // Store insights for this message
    if (insights.isNotEmpty) {
      setState(() {
        _messageInsights[messageId] = insights;
      });
    }
    
    return insights;
  }
  
  ChatResponse _generateFutureYouResponse(String userMessage) {
    final title = userMessage.replaceAll(RegExp(r'by .*', caseSensitive: false), '').trim();
    final cleanTitle = title.length > 60 ? title.substring(0, 60) : title;
    
    final quickCommits = [
      QuickCommit(
        label: 'Add Habit (Weekdays 7:00)',
        type: 'habit',
        title: cleanTitle.isNotEmpty ? cleanTitle : 'New Habit',
        time: '07:00',
      ),
      QuickCommit(
        label: 'Add Habit (Daily 6:00)',
        type: 'habit',
        title: cleanTitle.isNotEmpty ? cleanTitle : 'New Habit',
        time: '06:00',
      ),
      QuickCommit(
        label: 'Add Task (Today 9:00)',
        type: 'task',
        title: cleanTitle.isNotEmpty ? cleanTitle : 'New Task',
        time: '09:00',
      ),
    ];
    
    return ChatResponse(
      message: "Locked on. I queued quick-commit options for ${DateFormat('MMM d').format(_selectedDate)}. Tap one to make it real.",
      quickCommits: quickCommits,
    );
  }
  
  Future<void> _handleQuickCommit(QuickCommit commit) async {
    try {
      await ref.read(habitEngineProvider).createHabit(
        title: commit.title,
        type: commit.type,
        time: commit.time,
        startDate: _selectedDate,
        repeatDays: commit.type == 'habit' ? [1, 2, 3, 4, 5] : [_selectedDate.weekday % 7],
      );
      
      // Add confirmation message
      final confirmationMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'future',
        text: "✅ Perfect! I've locked in '${commit.title}' at ${commit.time}. Your future self is already thanking you.",
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _messages.add(confirmationMessage);
        _quickCommits.clear();
      });
      
      _scrollToBottom();
      
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create ${commit.type}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Full-screen chat messages
          Expanded(
            child: GlassCard(
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Header as first item
                      const SliverToBoxAdapter(
                        child: ScrollableHeader(),
                      ),
                      // Messages list
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final message = _messages[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildMessageBubble(message),
                                  // Show insights after AI messages
                                  if (message.role == 'future' && 
                                      _messageInsights.containsKey(message.id))
                                    ..._messageInsights[message.id]!.map((insight) => 
                                      _buildInsightCard(insight)),
                                ],
                              );
                            },
                            childCount: _messages.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glassBackground,
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                            border: Border.all(color: AppColors.glassBorder),
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
                              const SizedBox(width: 8),
                              Text(
                                'Future You is thinking...',
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
              ],
            ),
          ),
        ),
        
        const SizedBox(height: AppSpacing.lg),
        
        // Quick commits
        if (_quickCommits.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Commit',
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _quickCommits.map<Widget>((commit) {
                  return GlassButton(
                    onPressed: () => _handleQuickCommit(commit),
                    backgroundColor: AppColors.emerald.withOpacity(0.15),
                    borderColor: AppColors.emerald.withOpacity(0.3),
                    child: Text(
                      commit.label,
                      style: AppTextStyles.captionSmall.copyWith(
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

        // Removed standalone voice button; voice now on mentor bubbles
        ],
        
        // Input field with preset toggle
        GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Input row
              Row(
                children: [
                  // Preset toggle button
                  GestureDetector(
                    onTap: () => setState(() => _presetsOpen = !_presetsOpen),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Center(
                        child: Text(
                          _presetsOpen ? '−' : '+',
                          style: const TextStyle(
                            fontSize: 24,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Input field
                  Expanded(
                    child: TextFormField(
                      controller: _messageController,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Ask anything…',
                        filled: true,
                        fillColor: AppColors.glassBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                          borderSide: const BorderSide(color: AppColors.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                          borderSide: const BorderSide(color: AppColors.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                          borderSide: const BorderSide(color: AppColors.emerald),
                        ),
                      ),
                      onFieldSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Send button
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppColors.emeraldGradient,
                        borderRadius: BorderRadius.circular(AppBorderRadius.full),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.send,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Preset drawer
              if (_presetsOpen) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.glassBorder, height: 1),
                const SizedBox(height: AppSpacing.md),
                
                // Mode tabs
                Row(
                  children: [
                    _buildPresetTab('Life\'s Task', 'lifetask'),
                    const SizedBox(width: AppSpacing.sm),
                    _buildPresetTab('Habit Master', 'habit'),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Preset chips
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _presets[_presetMode]!.map((preset) {
                    return _buildPresetChip(
                      preset['title']!,
                      preset['prompt']!,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        
        // Bottom padding for navigation (lifted to clear tab bar)
        const SizedBox(height: 120),
      ],
      ),
    );
  }
  
  Widget _buildQuickPrompts() {
    final prompts = [
      {'icon': '🎯', 'text': 'Find my purpose'},
      {'icon': '💪', 'text': 'Build a routine'},
      {'icon': '🔥', 'text': 'Break a bad habit'},
      {'icon': '🧘', 'text': 'Daily reflection'},
    ];
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Start',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.emerald,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prompts.map((prompt) {
              return GestureDetector(
                onTap: () {
                  _messageController.text = prompt['text']!;
                  _sendMessage();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.emerald.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(prompt['icon']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        prompt['text']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPresetTab(String label, String mode) {
    final isActive = _presetMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _presetMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.emeraldGradient.scale(0.3) : null,
          color: isActive ? null : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(
            color: isActive ? AppColors.emerald.withOpacity(0.4) : AppColors.glassBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.captionSmall.copyWith(
            color: isActive ? AppColors.emerald : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String title, String prompt) {
    return GestureDetector(
      onTap: () {
        _messageController.text = prompt;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Stack(
          children: [
            // Text
            Text(
              title,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Shimmer effect overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat())
              .slideX(
                begin: -1.2, 
                end: 1.2, 
                duration: 1800.ms,
                curve: Curves.easeInOut,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child:                   Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: isUser ? AppColors.emeraldGradient.scale(0.9) : null,
                      color: isUser ? null : AppColors.glassBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      border: Border.all(
                        color: isUser
                            ? AppColors.emeraldLight.withOpacity(0.3)
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: AppTextStyles.body.copyWith(
                        color: isUser
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (!isUser && _messageVoiceUrls.containsKey(message.id)) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 20, color: Colors.white70),
                    onPressed: () async {
                      final url = _messageVoiceUrls[message.id]!;
                      try {
                        await _audioPlayer.stop();
                        await _audioPlayer.play(UrlSource(url));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Voice playback failed: $e')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(
                LucideIcons.user,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInsightCard(UniversityInsight insight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 40),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              insight.tintColor.withOpacity(0.15),
              insight.tintColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: insight.tintColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: insight.tintColor.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // University header
            Row(
              children: [
                Text(insight.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  insight.university,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '•',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  insight.year,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Title
            Text(
              insight.title,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Finding
            Text(
              insight.finding,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (insight.longDescription != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                insight.longDescription!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (insight.sampleSize != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sample: ${insight.sampleSize}',
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textQuaternary,
                ),
              ),
            ],
            // Learn more hint
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  LucideIcons.externalLink,
                  size: 12,
                  color: insight.tintColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Learn more',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: insight.tintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 200.ms, curve: Curves.easeOutCubic),
    );
  }
}
