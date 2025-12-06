import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

import '../design/tokens.dart';
import '../providers/navigation_provider.dart';
import 'home_screen.dart';
import 'planner_screen.dart';
import 'os_chat_screen.dart'; // New AI OS Chat tab
import 'habit_master_screen.dart';
import 'reflections_screen.dart';
import 'mirror_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with TickerProviderStateMixin {
  late PageController _pageController = PageController(initialPage: 0); // Initialize immediately
  late AnimationController _tabAnimationController;
  
  final List<TabItem> _tabs = [
    TabItem(
      icon: LucideIcons.flame,
      label: 'Today',
      screen: const HomeScreen(),
    ),
    TabItem(
      icon: LucideIcons.clipboard,
      label: 'Planner',
      screen: const PlannerScreen(),
    ),
    TabItem(
      icon: LucideIcons.messageCircle,
      label: 'OS', // AI Operating System Chat
      screen: const OSChatScreen(),
    ),
    TabItem(
      icon: LucideIcons.trophy,
      label: 'Habit\nMaster',
      screen: const HabitMasterScreen(),
    ),
    // Removed: Discovery tab (CommandCenterScreen)
    // Removed: Purpose Engine tab (FutureYouScreen)
    // Reflections accessible via icon in SimpleHeader
  ];
  
  @override
  void initState() {
    super.initState();
    _checkFirstTimeAfterOnboarding();
    _tabAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  // Check if first time after onboarding - start at Today tab
  Future<void> _checkFirstTimeAfterOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTimeAfterOnboarding = prefs.getBool('first_time_after_onboarding') ?? true;
    
    if (isFirstTimeAfterOnboarding) {
      // First time - stay on Today tab (index 0)
      // Mark as no longer first time
      await prefs.setBool('first_time_after_onboarding', false);
    }
    // Otherwise stay on Today tab (default initialPage: 0)
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _tabAnimationController.dispose();
    super.dispose();
  }
  
  void _onTabTapped(int index) {
    final currentIndex = ref.read(navigationProvider);
    if (index != currentIndex) {
      // Update provider - the ref.listen below will handle page navigation
      ref.read(navigationProvider.notifier).navigateToTab(index);
      
      // Tab animation feedback
      _tabAnimationController.forward().then((_) {
        _tabAnimationController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);
    
    // Listen to navigation changes and update page controller
    ref.listen(navigationProvider, (previous, next) {
      if (previous != next) {
        // Jump directly to the page without animation
        _pageController.jumpToPage(next);
      }
    });
    
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false, // ✅ CRITICAL: Prevents bottom nav from moving with keyboard
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Content
              PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  ref.read(navigationProvider.notifier).navigateToTab(index);
                },
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  return _tabs[index].screen;
                },
              ),
              
              // Bottom navigation (always visible, NEVER moves with keyboard)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomNavigation(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        gradient: AppColors.emeraldGradient,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glass overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo + Text
                Row(
                  children: [
                    // ƒ Logo
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'ƒ',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.6),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    // Text
                    Text(
                      'FUTURE-YOU OS',
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.4,
                        shadows: [
                          Shadow(
                            color: Colors.white.withOpacity(0.6),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Pulsing sparkles
                AnimatedBuilder(
                  animation: _tabAnimationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.8 + (_tabAnimationController.value * 0.2),
                      child: Icon(
                        LucideIcons.sparkles,
                        size: 40,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
      .shimmer(duration: 3600.ms, color: Colors.white.withOpacity(0.1));
  }
  
  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              right: AppSpacing.xs,
              top: AppSpacing.sm, // Reduced from md to sm
              bottom: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
              boxShadow: AppShadows.glass,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / _tabs.length;
                
                return Stack(
                  children: [
                    // Sliding pill indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: ref.watch(navigationProvider) * tabWidth,
                      child: Container(
                        width: tabWidth,
                        height: 64,
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.emeraldLight.withOpacity(0.2),
                                AppColors.emerald.withOpacity(0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          ),
                        ),
                      ),
                    ),
                    
                    // Tab buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _tabs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final tab = entry.value;
                        final isActive = index == ref.watch(navigationProvider);
                        
                        return _buildTabButton(tab, index, isActive);
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTabButton(TabItem tab, int index, bool isActive) {
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          onTap: () => _onTabTapped(index),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed height container for icon to ensure alignment
                SizedBox(
                  height: 24,
                  child: Icon(
                    tab.icon,
                    size: 24,
                    color: isActive 
                        ? AppColors.emeraldLight 
                        : AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                // Fixed height container for label to ensure consistent spacing
                SizedBox(
                  height: 28,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      tab.label,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 11,
                        color: isActive 
                            ? AppColors.emeraldLight 
                            : AppColors.textSecondary.withOpacity(0.7),
                        fontWeight: isActive 
                            ? FontWeight.w700 
                            : FontWeight.w400,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TabItem {
  final IconData icon;
  final String label;
  final Widget screen;
  
  const TabItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
