import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Timezone init
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'models/habit.dart';
import 'models/coach_message.dart';
import 'services/local_storage.dart';
import 'services/messages_service.dart';
import 'services/sync_service.dart';
import 'services/offline_queue.dart'; // QueuedRequest Hive adapter is in .g.dart part file
import 'services/alarm_service.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/support_screen.dart';
import 'screens/viral_systems_screen.dart';
import 'screens/celebrity_systems_screen.dart';
import 'screens/mastery_lessons_screen.dart';
import 'screens/what_if_screen.dart';
import 'screens/what_if_redesign.dart'; // NEW What-If AI Simulator
import 'screens/reflections_screen.dart';
import 'screens/future_you_screen.dart';
import 'screens/habit_vault_screen.dart';
import 'screens/alarm_test_screen.dart';
import 'cinematic/cinematic_entry.dart';
import 'lifetask/screens/lifetask_journey_screen.dart';
import 'lifetask/screens/cinematic_test_screen.dart';
import 'design/theme.dart';

Future<void> _initTimezone() async {
  try {
    tzdata.initializeTimeZones();
    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));
    debugPrint('✅ Timezone initialized: $localTz');
  } catch (e) {
    debugPrint('⚠️ Timezone fallback to UTC: $e');
    tz.setLocalLocation(tz.getLocation('UTC'));
  }
}

Future<void> main() async {
  // Wrap everything in error handler
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized');
    } catch (e) {
      debugPrint('❌ Firebase initialization failed: $e');
      // Continue anyway - app should still work without Firebase (degraded mode)
    }

    // Initialize timezone ONCE
    await _initTimezone();

    // Initialize alarm service (handles permissions, notifications, and channels)
    await AlarmService.initialize();
    debugPrint('✅ AlarmService initialized');

    // Hive setup
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HabitAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(CoachMessageAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(QueuedRequestAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(MessageKindAdapter());
      }
      await LocalStorageService.initialize();
      await messagesService.init();
      debugPrint('✅ Hive initialized');
      
      // Initialize sync service in background (non-blocking to prevent grey screens)
      syncService.init().catchError((e) {
        debugPrint('❌ Sync initialization failed: $e');
      });
    } catch (e) {
      debugPrint('❌ Hive/Sync initialization failed: $e');
      // Don't throw - let app run with degraded functionality
    }

    // System UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    runApp(const ProviderScope(child: FutureYouApp()));
  }, (error, stack) {
    debugPrint('💥 Fatal error: $error\n$stack');
  });
}

class FutureYouApp extends StatelessWidget {
  const FutureYouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Future You OS',
      // Use a basic theme if custom theme fails
      theme: _getSafeTheme(),
      home: const AppRouter(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/terms': (context) => const TermsScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/support': (context) => const SupportScreen(),
        '/cinematic': (context) => const LifeTaskJourneyScreen(), // NEW: Life's Task Discovery
        '/cinematic-old': (context) => const CinematicEntry(), // OLD: Keep for reference
        '/test-cinematic': (context) => const CinematicTestScreen(), // DEBUG: Test intros
        '/viral-systems': (context) => const ViralSystemsScreen(), // Viral Systems
        '/celebrity-systems': (context) => const CelebritySystemsScreen(), // Celebrity Routines
        '/mastery-lessons': (context) => const MasteryLessonsScreen(), // Habit Mastery Rules
        '/what-if': (context) => const WhatIfRedesignScreen(), // NEW What-If AI Simulator
        '/habit-library': (context) => const WhatIfScreen(), // OLD Habit Library (keep for backward compat)
        '/reflections': (context) => const ReflectionsScreen(), // AI Reflections
        '/future-you': (context) => const FutureYouScreen(), // Future-You / Purpose Engine
        '/habit-vault': (context) => const HabitVaultScreen(), // Habit Vault
        '/alarm-test': (context) => const AlarmTestScreen(), // Alarm Debugger
      },
    );
  }

  ThemeData _getSafeTheme() {
    try {
      return AppTheme.darkTheme;
    } catch (e) {
      debugPrint('⚠️ Custom theme failed, using fallback: $e');
      return ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.blue,
      );
    }
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _showOnboarding = true;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _errorMessage = '';
  StreamSubscription<User?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _checkAppState();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // Listen to Firebase auth state changes for automatic navigation
  void _listenToAuthChanges() {
    try {
      _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
        debugPrint('🔄 Auth state changed: ${user?.uid ?? "null"}');
        if (mounted) {
          setState(() {
            _isAuthenticated = user != null;
          });
        }
      });
    } catch (e) {
      debugPrint('⚠️ Could not listen to auth changes: $e');
    }
  }

  Future<void> _checkAppState() async {
    try {
      // Check onboarding status
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      
      // Check auth status (with fallback if Firebase failed)
      bool isAuthenticated = false;
      try {
        final user = FirebaseAuth.instance.currentUser;
        isAuthenticated = user != null;
      } catch (e) {
        debugPrint('⚠️  Firebase Auth not available: $e');
        // Fallback: check if user ID is stored locally
        final userId = prefs.getString('user_id');
        isAuthenticated = userId != null && userId.isNotEmpty;
      }
      
      debugPrint('📱 Onboarding: $hasSeenOnboarding | Auth: $isAuthenticated');
      
      if (!mounted) return;
      setState(() {
        _showOnboarding = !hasSeenOnboarding;
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ App state check error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _completeOnboarding() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('has_seen_onboarding', true);
    });
    if (mounted) {
      setState(() => _showOnboarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🟢 Building AppRouter | loading=$_isLoading | onboarding=$_showOnboarding | auth=$_isAuthenticated');

    // Error state
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 20),
                const Text(
                  'Initialization Error',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = '';
                      _isLoading = true;
                    });
                    _checkAppState();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Loading Future You OS...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // Route based on onboarding and auth state
    try {
      // Show onboarding if not completed
      if (_showOnboarding) {
        debugPrint('🟢 Showing OnboardingScreen');
        return OnboardingScreen(onComplete: _completeOnboarding);
      }

      // Show login if not authenticated
      if (!_isAuthenticated) {
        debugPrint('🟢 Showing LoginScreen');
        return const LoginScreen();
      }

      // Show main app if authenticated
      debugPrint('🟢 Showing MainScreen');
      return const MainScreen();
    } catch (e) {
      debugPrint('❌ Screen render error: $e');
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 48),
              const SizedBox(height: 20),
              const Text(
                'Screen Load Error',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                e.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }
}

// Keep test screen for debugging
class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Future You OS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'App is working!',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              },
              child: const Text('Go to Main App'),
            ),
          ],
        ),
      ),
    );
  }
}
