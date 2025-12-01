import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/date_strip.dart';
import '../widgets/scrollable_header.dart';
import '../screens/settings_screen.dart';
import '../screens/reflections_screen.dart';
import '../widgets/parchment_scroll_card.dart';
import '../widgets/nudge_card.dart';
import '../widgets/morning_brief_modal.dart';
import '../widgets/system_card.dart';
import '../providers/habit_provider.dart';
import '../services/messages_service.dart';
import '../services/weekly_stats_service.dart';
import '../services/local_storage.dart';
import '../services/api_client.dart' as api;
import '../models/habit_system.dart';
import '../models/habit.dart';
import '../models/coach_message.dart';
import '../widgets/week_overview_card.dart';
import '../services/welcome_series_local.dart';
import '../data/welcome_series_content.dart';
import '../widgets/welcome_day_modal.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();
  bool _hasShownBrief = false;
  bool _hasShownWelcomeDay = false;
  int _unreadCount = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      // 🔥 NEW: Sync identity to backend if not already synced
      try {
        await api.ApiClient.syncIdentityToBackend();
      } catch (e) {
        debugPrint('⚠️ Identity sync skipped: $e');
      }
      
      // Initialize welcome series first
      await welcomeSeriesLocal.init();
      
      // Check if welcome series needs to be started (for new users)
      if (!welcomeSeriesLocal.hasStarted()) {
        debugPrint('🌑 Welcome series not started, starting now...');
        await welcomeSeriesLocal.start();
      }
      
      // Debug: Check welcome series status
      final stats = welcomeSeriesLocal.getStats();
      debugPrint('🌑 Welcome series stats: $stats');
      
      // Refresh messages
      await _refreshMessages();
      
      // Check for brief and welcome day
      _checkForMorningBrief();
      _checkForWelcomeDay();
      
      // Load unread count
      _loadUnreadCount();
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing home screen: $e');
      debugPrint('Stack trace: $stackTrace');
      // Ensure UI still renders even if initialization fails
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, refresh messages
      _refreshMessages();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when screen becomes visible
    _refreshMessages();
  }

  Future<void> _refreshMessages() async {
    try {
      debugPrint('🔄 Refreshing messages...');
      
      // Ensure messages service is initialized (init() is safe to call multiple times)
      await messagesService.init();
      
      await messagesService.syncMessages('test-user-felix');
      
      // Small delay to ensure local storage is updated
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (mounted) {
        setState(() {
          debugPrint('✅ Messages refreshed, updating UI');
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error refreshing messages: $e');
      debugPrint('Stack trace: $stackTrace');
      // Always ensure UI updates even on error to prevent grey screen
      if (mounted) {
        setState(() {
          debugPrint('⚠️ UI updated despite error to prevent grey screen');
        });
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    final count = messagesService.getUnreadCount();
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  void _checkForMorningBrief() {
    // Check if it's morning (6am - 10am) and if we haven't shown brief yet today
    final now = DateTime.now();
    if (now.hour >= 6 && now.hour < 10 && !_hasShownBrief) {
      final brief = messagesService.getTodaysBrief();
      if (brief != null && !brief.isRead) {
        // Show brief after build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showMorningBrief(context, brief);
            _hasShownBrief = true;
          }
        });
      }
    }
  }

  void _checkForWelcomeDay() {
    try {
      // Ensure welcome series is initialized
      if (!welcomeSeriesLocal.hasStarted()) {
        debugPrint('🌑 Welcome series not started yet, skipping check');
        return;
      }
      
      // Check if we should show welcome day
      final shouldShow = welcomeSeriesLocal.shouldShowToday();
      debugPrint('🌑 Welcome check: hasShown=$_hasShownWelcomeDay, shouldShow=$shouldShow');
      
      if (!_hasShownWelcomeDay && shouldShow) {
        final dayContent = welcomeSeriesLocal.getTodaysContent();
        debugPrint('🌑 Day content: ${dayContent?.day} - ${dayContent?.title}');
        
        if (dayContent != null && mounted) {
          debugPrint('🌑 Showing welcome day modal for Day ${dayContent.day}');
          // Show welcome day after build completes (priority after brief)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            
            // Delay to ensure brief modal doesn't conflict
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && !_hasShownWelcomeDay) {
                try {
                  _showWelcomeDayModal(dayContent);
                  _hasShownWelcomeDay = true;
                } catch (e) {
                  debugPrint('❌ Error showing welcome modal: $e');
                }
              }
            });
          });
        } else {
          debugPrint('🌑 No day content available or widget unmounted');
        }
      } else {
        if (_hasShownWelcomeDay) {
          debugPrint('🌑 Welcome day already shown today');
        } else if (!shouldShow) {
          debugPrint('🌑 Welcome day should not show today (already read or complete)');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Welcome series check failed: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't crash the app - just log the error
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showWelcomeDayModal(WelcomeDayContent dayContent) {
    if (!mounted) return;
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WelcomeDayModal(
          day: dayContent.day,
          moonPhase: dayContent.moonPhase,
          title: dayContent.title,
          content: dayContent.content,
          onContinue: () async {
            try {
              // Save welcome message to reflections tab
              final message = welcomeSeriesLocal.welcomeDayToMessage(dayContent);
              await messagesService.saveLocalMessage(message);
              
              // Mark day as complete
              await welcomeSeriesLocal.markDayComplete();
              
              if (mounted) {
                Navigator.of(context).pop();
                setState(() {
                  _hasShownWelcomeDay = true;
                });
              }
            } catch (e) {
              debugPrint('❌ Error marking welcome day complete: $e');
              if (mounted) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Error showing welcome day modal: $e');
    }
  }
  
  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final habitEngine = ref.watch(habitEngineProvider);
    final allHabits = habitEngine.habits;
    
    // Filter habits for selected date
    final dayHabits = allHabits.where((habit) {
      return habit.isScheduledForDate(_selectedDate);
    }).toList();
    
    // Load all systems
    final allSystems = LocalStorageService.getAllSystems();
    
    // Group habits by systemId (NEW: using habit.systemId field)
    final Map<String, List<dynamic>> systemHabitsMap = {};
    final List<dynamic> standaloneHabits = [];
    
    for (final habit in dayHabits) {
      if (habit.systemId != null && habit.systemId!.isNotEmpty) {
        // Habit belongs to a system
        if (!systemHabitsMap.containsKey(habit.systemId)) {
          systemHabitsMap[habit.systemId!] = [];
        }
        systemHabitsMap[habit.systemId!]!.add(habit);
      } else {
        // Standalone habit
        standaloneHabits.add(habit);
      }
    }
    
    // ✅ Date-aware completion
    final completedCount = dayHabits.where((h) => h.isDoneOn(_selectedDate)).length;
    
    // ✅ Check for ALL active AI OS messages (brief, nudge, debrief, letter)
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;
    
    // Get active messages (only show for today)
    final activeNudge = isToday ? messagesService.getActiveNudge() : null;
    final todaysBrief = isToday ? messagesService.getTodaysBrief() : null;
    final activeDebrief = isToday ? messagesService.getLatestDebrief() : null;
    final activeLetters = isToday ? messagesService.getUnreadLetters() : [];
    
    // Collect scroll messages (briefs, debriefs, letters) - ONLY unread ones
    final scrollMessages = <CoachMessage>[
      if (todaysBrief != null && !todaysBrief.isRead) todaysBrief,
      if (activeDebrief != null && !activeDebrief.isRead) activeDebrief,
      ...activeLetters.where((letter) => !letter.isRead),
    ];
    
    // Format date like React: "Thursday, Oct 30, 2025"
    final dateFormatter = DateFormat('EEEE, MMM d, yyyy');
    final formattedDate = dateFormatter.format(_selectedDate);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ New header matching planner style with brain logo
            _buildHomeHeader(),
            
            // Date strip
            DateStrip(
              selectedDate: _selectedDate,
              onDateSelected: _onDateSelected,
              accentColor: AppColors.emerald, // Match home header
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // ✅ AI OS Messages - LEGENDARY UI 🔥🔥🔥
            
            // 📜 PARCHMENT SCROLL - Briefs, Debriefs, Letters
            if (scrollMessages.isNotEmpty)
              ParchmentScrollCard(
                messages: scrollMessages,
                phase: 'observer', // TODO: Get from user's actual phase
                onNavigateToReflections: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReflectionsScreen()),
                  );
                },
                onDismiss: () {
                  // Refresh home screen to hide dismissed messages
                  setState(() {});
                },
              ),
            
            // ⚡ ORANGE NUDGE BOX - Real-time nudges only
            if (activeNudge != null)
              NudgeCard(
                message: activeNudge,
                phase: 'observer', // TODO: Get from user's actual phase
                onDismiss: () => setState(() {}),
                onNavigateToReflections: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReflectionsScreen()),
                  );
                },
              ),
            
            const SizedBox(height: AppSpacing.sm),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Habit cards (System cards + Standalone habits)
            if (dayHabits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl * 2),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 32,
                        color: AppColors.textQuaternary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Nothing here yet',
                        style: AppTextStyles.bodySemiBold.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Add a habit or task in Planner.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            
            if (dayHabits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    // System Cards (NEW: using SystemCard widget)
                    ...allSystems.where((system) => systemHabitsMap.containsKey(system.id)).map((system) {
                      final systemHabits = systemHabitsMap[system.id]!.cast<Habit>();
                      return SystemCard(
                        system: system,
                        habits: systemHabits,
                        selectedDate: _selectedDate, // ✅ Pass selected date for date-aware completion
                        onToggleHabit: (habit) async {
                          // ✅ HOME PAGE: Enable habit ticking
                          await ref.read(habitEngineProvider.notifier).toggleHabitCompletion(habit.id);
                        },
                      );
                    }).toList(),
                    
                    // Standalone Habit Cards
                    ...standaloneHabits.asMap().entries.map((entry) {
                      final index = entry.key;
                      final habit = entry.value;
                      final isDone = habit.isDoneOn(_selectedDate);
                      
                      return _buildReactHabitCard(
                        habit: habit,
                        isDone: isDone,
                        index: index + allSystems.length,
                        onToggle: () async {
                          await ref.read(habitEngineProvider).toggleHabitCompletion(habit.id);
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            
            // ✅ REMOVED FOR NOW - Week Overview Card (saved for future version)
            // const SizedBox(height: AppSpacing.xl),
            // WeekOverviewCard(
            //   stats: WeeklyStatsService.calculateCurrentWeekStats(),
            // ),
            
            // Bottom padding for nav bar (extra space for breathing room)
            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }
  
  // OLD _buildSystemCard removed - now using SystemCard widget from lib/widgets/system_card.dart
  
  Widget _buildReactHabitCard({
    required dynamic habit,
    required bool isDone,
    required int index,
    required VoidCallback onToggle,
  }) {
    // Handle empty time (for system habits that don't have a specific time)
    String? time;
    if (habit.time != null && habit.time.isNotEmpty) {
      try {
        final timeFormatter = DateFormat('HH:mm');
        time = timeFormatter.format(DateTime.parse('2025-01-01 ${habit.time}:00'));
      } catch (e) {
        time = null; // Invalid time format, treat as no time
      }
    }
    
    // Use the habit's chosen color
    final habitColor = habit.color;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDone 
                ? habitColor.withOpacity(0.05)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: isDone
                  ? habitColor.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Emoji or icon
                  if (habit.emoji != null)
                    Text(
                      habit.emoji!,
                      style: const TextStyle(fontSize: 32),
                    )
                  else
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: habitColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        LucideIcons.flame,
                        size: 20,
                        color: habitColor,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time + Alarm + Status chip
                        Row(
                          children: [
                            if (time != null) ...[
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: habitColor,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Show alarm icon if reminder is on
                              if (habit.reminderOn) ...[
                                Icon(
                                  LucideIcons.bellRing,
                                  size: 12,
                                  color: habitColor.withOpacity(0.8),
                                ),
                              ],
                              const SizedBox(width: AppSpacing.sm),
                              Text('•', style: TextStyle(color: Colors.white38)),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: habitColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: habitColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                isDone ? 'done' : 'planned',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: habitColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // Title
                        Text(
                          habit.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Checkmark icon
                  Icon(
                    isDone ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    size: 28,
                    color: isDone
                        ? habitColor
                        : Colors.white.withOpacity(0.3),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: isDone ? 1.0 : 0.56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                habitColor.withOpacity(0.8),
                                habitColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppBorderRadius.full),
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
      ),
    ).animate(delay: (index * 30).ms)
      .fadeIn(duration: 260.ms)
      .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
  }
  
  Widget _buildProgressBar({
    required double progress,
    required String label,
    required Color color,
    required String description,
  }) {
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
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                ),
                FractionallySizedBox(
                  widthFactor: clampedProgress / 100,
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: label.contains('Fulfillment') 
                          ? AppColors.emeraldGradient 
                          : LinearGradient(
                              colors: [color, color.withOpacity(0.8)],
                            ),
                      borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          description,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textQuaternary,
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Header matching planner style with brain logo in emerald
  Widget _buildHomeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm, // ✅ Reduced to sm - pushes logo more left
        AppSpacing.xl,
        AppSpacing.sm, // ✅ Reduced to sm - pushes icons more right
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brain logo with "Future-You OS" text
          Row(
            children: [
              // Brain icon in emerald square
              // ✅ Logo moved more to the left (reduced left padding handled by parent)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald,
                      AppColors.emerald.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 4), // ✅ Reduced to 4 - header very close to logo
              // Future-You OS text in emerald gradient - very close to logo
              ShaderMask(
                shaderCallback: (bounds) => AppColors.emeraldGradient
                    .createShader(bounds),
                child: const Text(
                  'Future-You OS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          
          // Reflections + Settings icons
          Row(
            children: [
              // Reflections icon
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReflectionsScreen(),
                    ),
                  );
                  _loadUnreadCount();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        border: Border.all(
                          color: AppColors.emerald.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.bookOpen,
                        color: AppColors.emerald,
                        size: 22,
                      ),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              _unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Settings icon
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(
                      color: AppColors.emerald.withOpacity(0.2),
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.settings,
                    color: AppColors.emerald,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
