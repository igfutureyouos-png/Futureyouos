import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/local_storage.dart';
import '../services/api_client.dart';
import '../services/welcome_series_local.dart';
import '../services/payment_service.dart';
import '../services/premium_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final int _total = 6; // 6 pages total (removed Book of Purpose)
  final TextEditingController _lifeTaskController = TextEditingController();
  
  // Identity capture controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _burningQuestionController = TextEditingController();

  void _nextStep() async {
    // Validate identity page before proceeding
    if (_step == 1) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your name'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_ageController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your age'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      _saveIdentityToLocal();
    }
    
    if (_step < _total - 1) {
      setState(() => _step++);
    } else {
      // Final step - onboarding complete!
      // Start the 7-day welcome series
      await welcomeSeriesLocal.init();
      await welcomeSeriesLocal.start();
      debugPrint('🌑 Welcome Series initialized for new user!');
      
      // Call onComplete to finish onboarding
      widget.onComplete();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  double get _progress => ((_step + 1) / _total) * 100;

  Future<void> _saveIdentityToLocal() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text) ?? 0;
    final burningQuestion = _burningQuestionController.text.trim();
    
    // Save locally
    await LocalStorageService.saveSetting('userName', name);
    await LocalStorageService.saveSetting('userAge', age);
    await LocalStorageService.saveSetting('burningQuestion', burningQuestion);
    
    debugPrint('🔍 [Onboarding] Saving identity - name: "$name", age: $age');
    
    // 🔥 Save to backend so AI OS can use it!
    // Check if user is authenticated first
    final userId = ApiClient.userId;
    if (userId == null) {
      debugPrint('⚠️ [Onboarding] User not authenticated yet - identity will sync later');
      // Don't try to save to backend without auth
      // It will sync when they first open the app after auth
      return;
    }
    
    try {
      debugPrint('🔍 [Onboarding] Attempting to save to backend for user: ${userId.substring(0, 8)}...');
      await ApiClient.saveUserIdentity(
        name: name.isNotEmpty ? name : null,
        age: age > 0 ? age : null,
        burningQuestion: burningQuestion.isNotEmpty ? burningQuestion : null,
      );
      debugPrint('✅ [Onboarding] Identity saved to backend: $name');
    } catch (e) {
      debugPrint('⚠️ [Onboarding] Failed to save identity to backend: $e');
      // Mark as not synced so it will retry later
      await LocalStorageService.saveSetting('identitySynced', false);
    }
  }

  @override
  void dispose() {
    _lifeTaskController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _burningQuestionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              const Color(0xFF09090B),
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Top progress bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 6,
                color: const Color(0xFF27272A),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: MediaQuery.of(context).size.width * (_progress / 100),
                    decoration: BoxDecoration(
                      gradient: AppColors.emeraldGradient,
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.15, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: _buildPage(_step),
              ),
            ),

            // Bottom progress dots
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_total, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => _step = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: index == _step ? 32 : 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _step
                            ? AppColors.emerald
                            : const Color(0xFF3F3F46),
                        borderRadius: BorderRadius.circular(AppBorderRadius.full),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int step) {
    switch (step) {
      case 0:
        return _buildAwakeningPage();
      case 1:
        return _buildIdentityPage();
      case 2:
        return _buildMirrorPage();
      case 3:
        return _buildOSOPage();
      case 4:
        return _buildWhatIfPage();
      case 5:
        return _buildPaywallPage(); // Removed Book of Purpose page
      default:
        return Container();
    }
  }

  // PAGE 1: AWAKENING
  Widget _buildAwakeningPage() {
    return Center(
      key: const ValueKey(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.4),
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AWAKENING',
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.sparkles,
                    size: 14,
                    color: AppColors.emerald,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF34D399),
                  Color(0xFF10B981),
                ],
              ).createShader(bounds),
              child: Text(
                'Every person has a calling — ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.1, end: 0),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF34D399),
                  Color(0xFF10B981),
                ],
              ).createShader(bounds),
              child: const Text(
                'yours is waiting to be remembered.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),
            Text(
              'Future-You OS is an AI that helps you uncover who you really are, what truly matters, and builds the system to get you there.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _nextStep,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Begin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(LucideIcons.arrowRight, size: 20, color: Colors.black),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
          ],
        ),
      ),
    );
  }

  // PAGE 2: IDENTITY CAPTURE
  Widget _buildIdentityPage() {
    return Container(
      key: const ValueKey(1),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Color(0xFF0F1F0F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(LucideIcons.user, size: 64, color: AppColors.emerald)
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(delay: 200.ms),
                    const SizedBox(height: 24),
                    Text(
                      'First, let me know you',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 12),
                    
                    // Important note about name
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withOpacity(0.1),
                        border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.info, size: 20, color: AppColors.emerald),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please use the name you want to be called by. Future-You will use this name in your reflections and letters.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.emerald,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                    
                    const SizedBox(height: 32),
                    
                    // Name input
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Your Name *',
                        labelStyle: TextStyle(color: AppColors.emerald),
                        hintText: 'What should I call you?',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.emerald.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.emerald, width: 2),
                        ),
                      ),
                    ).animate().slideY(begin: 0.2, delay: 400.ms),
                    
                    const SizedBox(height: 20),
                    
                    // Age input
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Your Age *',
                        labelStyle: TextStyle(color: AppColors.emerald),
                        hintText: 'How old are you?',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.emerald.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.emerald, width: 2),
                        ),
                      ),
                    ).animate().slideY(begin: 0.2, delay: 500.ms),
                    
                    const SizedBox(height: 40), // Extra space before button
                  ],
                ),
              ),
            ),
            
            // Fixed bottom navigation (stays at bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // Continue button
                  GestureDetector(
                    onTap: () => _nextStep(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: AppColors.emeraldGradient,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(LucideIcons.arrowRight, size: 20, color: Colors.black),
                        ],
                      ),
                    ),
                  ).animate(delay: 700.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
                  const SizedBox(height: 80), // Space for bottom dots
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PAGE 3: THE MIRROR
  Widget _buildMirrorPage() {
    return Center(
      key: const ValueKey(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
                children: [
                  const TextSpan(text: 'Meet '),
                  TextSpan(
                    text: 'Future-You',
                    style: TextStyle(
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Color(0xFF34D399), Color(0xFF10B981)],
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),
            Text(
              'The AI version of you who remembers everything you\'ve said you\'d become — and writes to you daily, guiding you with clarity and compassion.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFF27272A)),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Back', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _nextStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    child: Row(
                      children: const [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: 20, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }

  // PAGE 4: THE OSO SYSTEM
  Widget _buildOSOPage() {
    return Center(
      key: const ValueKey(3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'The OSO System',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.2,
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 16),
            Text(
              'An intelligent operating system that keeps you aligned with your Life\'s Task through three pillars:',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 32),
            _buildOSOCard(
              icon: LucideIcons.calendarHeart,
              title: 'Morning Brief',
              description: 'AI-generated daily focus that reminds you of your identity, key habits, and commitments for the day.',
              delay: 300,
            ),
            const SizedBox(height: 16),
            _buildOSOCard(
              icon: LucideIcons.mail,
              title: 'Letters from Future-You',
              description: 'Deep, evolving letters that help you reflect on progress and reconnect with your deeper purpose.',
              delay: 400,
            ),
            const SizedBox(height: 16),
            _buildOSOCard(
              icon: LucideIcons.bellRing,
              title: 'Real-Time Nudges',
              description: 'Instant guidance when you need it — keeps you aligned throughout the day with timely insights.',
              delay: 500,
            ),
            const SizedBox(height: 16),
            _buildOSOCard(
              icon: LucideIcons.moonStar,
              title: 'Evening Debrief',
              description: 'Your nightly reflection — closes the loop, celebrates wins, and prepares you for tomorrow.',
              delay: 600,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFF27272A)),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Back', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _nextStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    child: Row(
                      children: const [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: 20, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
            const SizedBox(height: 80), // Extra space for bottom dots
          ],
        ),
      ),
    );
  }

  Widget _buildOSOCard({
    required IconData icon,
    required String title,
    required String description,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        border: Border.all(
          color: AppColors.emerald.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.emerald),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms, duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  // PAGE 5: WHAT-IF ENGINE
  Widget _buildWhatIfPage() {
    return Center(
      key: const ValueKey(4),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'The What-If Engine',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.2,
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 16),
            Text(
              'Two powerful AI systems that clarify your goals and generate research-backed action plans:',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 8),
            
            // Preset badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withOpacity(0.2),
                    border: Border.all(color: AppColors.emerald.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.gitCompare, size: 14, color: AppColors.emerald),
                      SizedBox(width: 6),
                      Text(
                        'Future Simulator',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.2),
                    border: Border.all(color: const Color(0xFF667EEA).withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.hammer, size: 14, color: Color(0xFF667EEA)),
                      SizedBox(width: 6),
                      Text(
                        'Habit Architect',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF667EEA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),
            
            const SizedBox(height: 24),
            
            // Scrollable output card
            Container(
              height: 400,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF09090B),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.scrollText, size: 16, color: AppColors.emerald),
                      const SizedBox(width: 8),
                      Text(
                        'Example Output (Scroll to Read)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.arrowDown, size: 12, color: AppColors.emerald),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        '''🌗 THE TWO FUTURES — 90 DAYS AHEAD

😐 STAY SAME
→ 3mo: Average protein intake remains at 80g/day; inadequate muscle recovery limits gains (Phillips 2014).
→ 6mo: Continued inconsistency in training leads to minimal strength improvements, possibly losing muscle mass due to poor nutrition (Schoenfeld 2021).
→ 12mo: Estimated weight stagnates around 75kg; strength increases by only 10%, yielding unmet goal (Hall 2019).

⚡ COMMIT FULLY
→ 1mo: Consistent training (4x/week) boosts strength by approximately 5% and improves body composition with slight fat loss (Gentil 2020).
→ 6mo: Targeted nutrition (120g protein/day) along with structured meal prep leads to 2-4kg lean muscle gain and 15-20% strength increase (Burd 2011).
→ 12mo: Achieves 5-8kg weight gain, enhanced muscle definition and developed holistic strength (Schoenfeld 2021).

---

📊 SPLIT-FUTURE COMPARISON

| Metric | Stay | Commit | Δ | Evidence |
|--------|------|--------|---|----------|
| 💪 Body Weight (kg) | 75 | 80 | +5 | Hall 2019 |
| 📈 Strength % | +10% | +30% | +20% | Schoenfeld 2021 |
| ⚡ Energy Levels | 5/10 | 8/10 | +3 | Prather 2019 |
| 🍳 Protein Intake (g) | 80g | 120g | +40g | Phillips 2014 |

---

🧬 WHY IT WORKS

Inconsistent training hampers muscle hypertrophy leading to decreased strength gains (Schoenfeld 2021) → High protein intake post-exercise stimulates muscle protein synthesis 30% more effectively than lower intakes (Burd 2011) → Resulting in significant muscle growth and recovery improvement (Phillips 2014).

---

✅ NEXT 7 DAYS (PROOF OF CONCEPT)

1️⃣ Tonight → bed by 10:30pm (limit screen time 30min before) → adherence ↑95%
2️⃣ Tomorrow → full-body workout + protein-rich breakfast → strength ↑5%
3️⃣ Wednesday → batch-cook meals for work week, replace takeaway lunches with home-cooked options → cravings ↓20%

7-Day Impact: +5 💪 | +3 ⚡ | -20% 🍔  
Confidence: 🟢 High (±10%)

---

💎 CLOSING LINE

"In this journey, each step you take today builds the strength of your tomorrow."

---

🎯 HABITS TO COMMIT

1. 💪 Weight Training 4x/week → Weekly 
2. 🥗 Increase protein intake to 120g/day → Daily 
3. 🍳 Eat a balanced breakfast (high protein) → Daily

---

[HABIT ARCHITECT PRESET]

⚙️ WHY YOU'VE FAILED BEFORE

You struggle with habit consistency due to an imbalance in energy and meal planning. Research shows decision fatigue combined with irregular meal timing can lead to reduced motivation for exercising, resulting in a cycle of skipping workouts and poor dietary choices.

---

🟢 PHASE 1 (Weeks 1-4) — Build the Rail

• 4 sessions (40 min) • fixed start at 6:30 PM
• sleep 10:30 PM ±30 min • protein ≈1.4 g/kg
• prep 2 meals on Sunday (batch cooking) to eliminate decision fatigue.

Why: Regular sleep enhances muscle recovery while improving motivation and energy levels, leading to a 28% increase in adherence (Harvey 2017).

Feels: By day 10, routine starts to feel effortless as you establish your rhythm.

---

🔵 PHASE 2 (Weeks 5-8) — Strength Identity

• Progressive overload: increase weights by 5% each week 
• protein ≈1.6 g/kg • steps 10k daily
• reward loop: celebrate every 5kg muscle gain.

Why: Visible progress through measurable strength gains raises dopamine levels by about 15% (Pessiglione 2008).

Feels: You'll feel stronger physically and cognitively sharper.

---

🟣 PHASE 3 (Weeks 9-12) — Body Shift

• Optimize meals: implement a high-protein breakfast (+30g protein)
• tighten sleep window to ±15 min
• template eating: 1 protein + 2 servings of plants at each meal.

Why: Transitioning to whole foods helps cut out ultra-processed items, leading to about a 500 kcal reduction per day (Hall 2019).

Feels: You'll feel transformed and strong, as your body recognizes this new level of regularity.

---

🎯 HABITS TO COMMIT

1. 🍽️ High-protein breakfast → Daily
2. 🏋️‍♂️ Full Body A/B sessions → 4x/week
3. 🥗 Prepare 2 lunch meals → Weekly (Sundays)
4. 💤 Bedtime routine (wind down) → Daily''',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          height: 1.5,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
            
            const SizedBox(height: 16),
            Text(
              'One click to turn these into committed habits',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ).animate().fadeIn(delay: 500.ms),
            
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFF27272A)),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Back', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _nextStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    child: Row(
                      children: const [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: 20, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
            const SizedBox(height: 80), // Extra space for bottom dots
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PAGE 6: BOOK OF PURPOSE DISCOVERY
  Widget _buildOathPage() {
    return Center(
      key: const ValueKey(5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Book icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.3),
                    AppColors.emerald.withOpacity(0.1),
                  ],
                ),
              ),
              child: const Icon(
                LucideIcons.bookOpen,
                size: 48,
                color: AppColors.emerald,
              ),
            ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
            
            const SizedBox(height: 24),
            
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
                children: [
                  const TextSpan(text: 'The '),
                  TextSpan(
                    text: 'Book of Purpose',
                    style: TextStyle(
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Color(0xFF34D399), Color(0xFF10B981)],
                        ).createShader(const Rect.fromLTWH(0, 0, 300, 70)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 20),
            
            Text(
              'A Deep Journey of Self-Discovery',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            
            const SizedBox(height: 32),
            
            // Description card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF09090B),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discovering your Life\'s Task is not a simple statement — it\'s an epic journey through the depths of your being.',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      height: 1.6,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Through 7 profound chapters, you\'ll explore:',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildChapterBullet('I. Your Origin Story — The forces that shaped you'),
                  _buildChapterBullet('II. Your Hidden Gifts — Talents you\'ve yet to claim'),
                  _buildChapterBullet('III. Your Deepest Wounds — Pain that holds power'),
                  _buildChapterBullet('IV. Your True Values — What you\'d die for'),
                  _buildChapterBullet('V. Your Vision — The world you must create'),
                  _buildChapterBullet('VI. Your Obstacles — Inner demons to conquer'),
                  _buildChapterBullet('VII. Your Calling — The work only you can do'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withOpacity(0.1),
                      border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.sparkles, size: 20, color: AppColors.emerald),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'At the end of each chapter, Future-You will write an epic chapter about you — weaving your answers into a narrative of who you truly are.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.emerald,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'This is not a quick form. This is not surface-level. This is the work that will define the rest of your life.',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Many hours. Deep reflection. Total honesty. Your purpose awaits.',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFF27272A)),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Back', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _nextStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Begin the Journey',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: 20, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
            
            const SizedBox(height: 80), // Extra space for bottom dots
          ],
        ),
      ),
    );
  }
  
  Widget _buildChapterBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.emerald,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withOpacity(0.85),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PAGE 7: PAYWALL
  Widget _buildPaywallPage() {
    return Center(
      key: const ValueKey(6),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Choose Your Path',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.2,
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 12),
            Text(
              'Join thousands becoming their ideal self',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.emerald.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 600.ms),
            const SizedBox(height: 8),
            Text(
              'Most people drift through life. Future-You keeps you awake.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
                fontSize: 13,
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 600.ms),
            const SizedBox(height: 32),
            
            // FREE TIER
            _buildPricingCard(
              icon: LucideIcons.package,
              title: 'Pathfinder',
              price: 'Free',
              subtitle: 'Start your journey',
              features: [
                '✓ Habit & task tracking',
                '✓ Alarms & reminders',
                '✓ Basic habit libraries',
                '✗ No AI OS',
                '✗ No What-If Engine',
              ],
              onTap: () => _selectFreeTier(),
              isPrimary: false,
              delay: 300,
            ),
            const SizedBox(height: 16),
            
            // TIER 2: $6.99 - AI AWAKENS
            _buildPricingCard(
              icon: LucideIcons.sparkles,
              title: 'AI Companion',
              price: '\$6.99',
              priceSubtext: '/month',
              subtitle: 'Your personal AI OS awakens',
              badge: 'MOST POPULAR',
              features: [
                '✓ Morning Briefs (GPT-4o powered)',
                '✓ Evening Debriefs & Real-time Nudges',
                '✓ Memory System (remembers everything)',
                '✓ Weekly OS Letters',
                '✓ What-If Engine (both presets)',
                '✓ Future Timeline Simulator',
                '✓ Habit & System Libraries',
                '✓ Intelligent Scheduler',
              ],
              onTap: () => _purchaseMonthly(),
              isPrimary: true,
              delay: 400,
            ),
            const SizedBox(height: 16),
            
            // ANNUAL: $69.99
            _buildPricingCard(
              icon: LucideIcons.zap,
              title: 'Annual Commitment',
              price: '\$69.99',
              priceSubtext: '/year',
              subtitle: 'Save \$14 vs monthly (\$5.83/mo)',
              badge: '16% OFF',
              features: [
                '✓ All AI Companion features',
                '✓ Priority AI response',
                '✓ Early access to new features',
                '✓ Founder badge',
                '✓ Exclusive updates',
              ],
              onTap: () => _purchaseAnnual(),
              isPrimary: false,
              delay: 500,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFF27272A)),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Back', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onComplete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    child: Row(
                      children: const [
                        Text(
                          'Enter the OS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: 20, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
            const SizedBox(height: 80), // Extra space for bottom dots
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required IconData icon,
    required String title,
    required String price,
    String? priceSubtext,
    String? subtitle,
    String? badge,
    String? valueNote,
    required List<String> features,
    required VoidCallback onTap,
    required bool isPrimary,
    bool isHighlighted = false,
    required int delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF09090B),
          border: Border.all(
            color: isHighlighted
                ? AppColors.emerald
                : isPrimary
                    ? AppColors.emerald.withOpacity(0.5)
                    : const Color(0xFF27272A),
            width: isHighlighted ? 2.5 : isPrimary ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
          boxShadow: (isPrimary || isHighlighted)
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(isHighlighted ? 0.3 : 0.2),
                    blurRadius: isHighlighted ? 50 : 40,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with badge
            Row(
              children: [
                Icon(icon, size: 20, color: (isPrimary || isHighlighted) ? AppColors.emerald : Colors.white60),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: (isPrimary || isHighlighted) ? AppColors.emerald : Colors.white,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.emerald.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.emerald,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (priceSubtext != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: Text(
                      priceSubtext,
                      style: AppTextStyles.captionSmall.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ),
              ],
            ),
            
            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.emerald.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Features
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  feature,
                  style: AppTextStyles.caption.copyWith(
                    color: feature.startsWith('✓')
                        ? Colors.white.withOpacity(0.85)
                        : Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            
            // Value note
            if (valueNote != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.emerald.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.trendingDown,
                      size: 14,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        valueNote,
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.emerald.withOpacity(0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms, duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  /// Select free tier (no payment required)
  void _selectFreeTier() {
    // User chooses free tier - complete onboarding without payment
    widget.onComplete();
  }

  /// Purchase monthly subscription
  Future<void> _purchaseMonthly() async {
    try {
      final success = await PaymentService.instance.purchaseMonthlySubscription();
      
      if (success) {
        // Payment successful - complete onboarding
        widget.onComplete();
      } else {
        // Payment failed - show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase failed. You can try again later or continue with the free tier.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Purchase annual subscription
  Future<void> _purchaseAnnual() async {
    try {
      final success = await PaymentService.instance.purchaseAnnualSubscription();
      
      if (success) {
        // Payment successful - complete onboarding
        widget.onComplete();
      } else {
        // Payment failed - show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase failed. You can try again later or continue with the free tier.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
