import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/coach_message.dart' as model;
import '../data/welcome_series_content.dart';

/// Local service to track and manage welcome series progress
class WelcomeSeriesLocal {
  static const String _boxName = 'welcome_series';
  late Box<dynamic> _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox(_boxName);
    _initialized = true;
    debugPrint('✅ Welcome Series Local initialized');
  }

  /// Check if welcome series has been started
  bool hasStarted() {
    if (!_initialized) return false;
    return _box.get('started', defaultValue: false) as bool;
  }

  /// Start the welcome series
  Future<void> start() async {
    if (!_initialized) await init();
    await _box.put('started', true);
    await _box.put('start_date', DateTime.now().toIso8601String());
    await _box.put('current_day', 1);
    debugPrint('🌑 Welcome Series started');
  }

  /// Get current day (1-7)
  int getCurrentDay() {
    if (!_initialized || !hasStarted()) return 1;
    return _box.get('current_day', defaultValue: 1) as int;
  }

  /// Check if series is complete
  bool isComplete() {
    if (!_initialized || !hasStarted()) return false;
    return getCurrentDay() > 7;
  }

  /// Check if today's day has been read
  bool hasTodayBeenRead() {
    if (!_initialized || !hasStarted()) return false;
    
    final currentDay = getCurrentDay();
    if (currentDay > 7) return true;
    
    final lastReadDate = _box.get('day_${currentDay}_read_date');
    if (lastReadDate == null) return false;
    
    final lastRead = DateTime.parse(lastReadDate as String);
    final now = DateTime.now();
    
    // Check if read today
    return lastRead.year == now.year &&
           lastRead.month == now.month &&
           lastRead.day == now.day;
  }

  /// Calculate which day should be shown based on start date
  /// Returns the day number (1-7) that should be shown today, or null if complete
  int? getDayToShowToday() {
    if (!_initialized || !hasStarted()) return null;
    
    final startDateStr = _box.get('start_date');
    if (startDateStr == null) return null;
    
    final startDate = DateTime.parse(startDateStr as String);
    final now = DateTime.now();
    
    // Calculate days since start (0-indexed, so day 1 = day 0)
    final daysSinceStart = now.difference(startDate).inDays;
    
    // Day 1 is shown on day 0, day 2 on day 1, etc.
    final dayToShow = daysSinceStart + 1;
    
    debugPrint('🌑 getDayToShowToday():');
    debugPrint('   - startDate: $startDate');
    debugPrint('   - now: $now');
    debugPrint('   - daysSinceStart: $daysSinceStart');
    debugPrint('   - dayToShow: $dayToShow');
    
    // Check if this day has already been completed
    // Once a day is marked as read, it should never show again
    final readDate = _box.get('day_${dayToShow}_read_date');
    debugPrint('   - day_${dayToShow}_read_date: $readDate');
    
    if (readDate != null) {
      // If this day was ever marked as read, it's complete - don't show again
      debugPrint('   - Day $dayToShow was already completed, skipping');
      return null;
    }
    
    // If beyond day 7, series is complete
    if (dayToShow > 7) {
      debugPrint('   - Day $dayToShow > 7, series complete');
      return null;
    }
    
    debugPrint('   - Returning dayToShow: $dayToShow');
    return dayToShow;
  }

  /// Mark current day as read (doesn't advance - advancement is based on calendar days)
  Future<void> markDayComplete() async {
    if (!_initialized) await init();
    
    final dayToShow = getDayToShowToday();
    if (dayToShow == null || dayToShow > 7) return;
    
    // Mark this day as read
    await _box.put('day_${dayToShow}_read_date', DateTime.now().toIso8601String());
    
    // Update current day
    await _box.put('current_day', dayToShow);
    
    if (dayToShow >= 7) {
      await _box.put('completed', true);
      await _box.put('completed_date', DateTime.now().toIso8601String());
      debugPrint('✨ Welcome Series completed!');
    } else {
      debugPrint('✅ Day $dayToShow marked as read');
    }
  }

  /// Check if we should show today's welcome day
  /// Only shows if:
  /// 1. Series has started
  /// 2. Not yet complete (day <= 7)
  /// 3. Today's day hasn't been read yet
  bool shouldShowToday() {
    if (!hasStarted()) return false;
    final dayToShow = getDayToShowToday();
    return dayToShow != null;
  }

  /// Get the content for today's day
  WelcomeDay? getTodaysContent() {
    if (!shouldShowToday()) return null;
    final dayToShow = getDayToShowToday();
    if (dayToShow == null) return null;
    
    // Update current day to match what should be shown
    if (getCurrentDay() != dayToShow) {
      _box.put('current_day', dayToShow);
    }
    
    // Get welcome day from content
    if (dayToShow < 1 || dayToShow > welcomeSeries.length) return null;
    return welcomeSeries[dayToShow - 1];
  }

  /// Convert welcome day to CoachMessage for storage in reflections
  model.CoachMessage welcomeDayToMessage(WelcomeDay dayContent) {
    return model.CoachMessage(
      id: 'welcome_day_${dayContent.day}',
      userId: 'test-user-felix', // Will be set by caller if different
      kind: model.MessageKind.awakening, // ✅ Use awakening kind for separate UI
      title: '${dayContent.moonPhase} ${dayContent.title}',
      body: dayContent.body,
      createdAt: DateTime.now(),
      isRead: false,
      meta: {
        'source': 'welcome_series',
        'day': dayContent.day,
        'moonPhase': dayContent.moonPhase,
        'audioUrl': dayContent.audioUrl,
      },
    );
  }

  /// Reset series (for testing)
  Future<void> reset() async {
    if (!_initialized) await init();
    await _box.clear();
    debugPrint('🔄 Welcome Series reset');
  }

  /// Get stats for debugging
  Map<String, dynamic> getStats() {
    if (!_initialized) return {};
    
    return {
      'started': hasStarted(),
      'current_day': getCurrentDay(),
      'is_complete': isComplete(),
      'should_show_today': shouldShowToday(),
      'today_read': hasTodayBeenRead(),
    };
  }
}

// Singleton instance
final welcomeSeriesLocal = WelcomeSeriesLocal();

