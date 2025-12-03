import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit.dart';
import '../models/habit_system.dart';

class LocalStorageService {
  static const String _habitsBoxName = 'habits';
  static const String _settingsBoxName = 'settings';
  static const String _systemsBoxName = 'habit_systems';

  static Box<Habit>? _habitsBox;
  static Box? _settingsBox;
  static Box? _systemsBox;

  static Future<void> initialize() async {
    _habitsBox = await Hive.openBox<Habit>(_habitsBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _systemsBox = await Hive.openBox(_systemsBoxName);
  }

  // CRUD
  static Future<void> saveHabit(Habit habit) async =>
      _habitsBox?.put(habit.id, habit);

  static Future<void> deleteHabit(String id) async =>
      _habitsBox?.delete(id);

  static Habit? getHabit(String id) => _habitsBox?.get(id);

  static List<Habit> getAllHabits() =>
      _habitsBox?.values.toList() ?? [];

  static List<Habit> getHabitsForDate(DateTime date) =>
      getAllHabits().where((h) => h.isScheduledForDate(date)).toList();

  static List<Habit> getTodayHabits() =>
      getHabitsForDate(DateTime.now());

  static Future<void> updateHabitCompletion(String id, bool done) async {
    final habit = getHabit(id);
    if (habit == null) return;
    final updated = habit.copyWith(
      done: done,
      completedAt: done ? DateTime.now() : null,
    );
    await saveHabit(updated);
  }

  static Future<void> clearAllHabits() async =>
      _habitsBox?.clear();

  // Settings
  static Future<void> saveSetting(String key, dynamic value) async =>
      _settingsBox?.put(key, value);

  static T? getSetting<T>(String key, {T? defaultValue}) =>
      _settingsBox?.get(key, defaultValue: defaultValue) as T?;

  static Future<void> deleteSetting(String key) async =>
      _settingsBox?.delete(key);

  static Future<void> clearAllSettings() async =>
      _settingsBox?.clear();

  static Future<void> clearAll() async {
    await clearAllHabits();
    await clearAllSettings();
  }
  
  // Habit Systems CRUD
  static Future<void> saveSystem(HabitSystem system) async {
    final json = system.toJson();
    await _systemsBox?.put(system.id, json);
  }
  
  static Future<void> deleteSystem(String id) async =>
      _systemsBox?.delete(id);
  
  static HabitSystem? getSystem(String id) {
    final json = _systemsBox?.get(id);
    if (json == null) return null;
    return HabitSystem.fromJson(Map<String, dynamic>.from(json as Map));
  }
  
  static List<HabitSystem> getAllSystems() {
    final systems = <HabitSystem>[];
    for (final value in _systemsBox?.values ?? []) {
      try {
        systems.add(HabitSystem.fromJson(Map<String, dynamic>.from(value as Map)));
      } catch (e) {
        // Skip invalid entries
        continue;
      }
    }
    return systems;
  }
  
  static Future<void> clearAllSystems() async =>
      _systemsBox?.clear();
  
  // ------------------- VIRAL SYSTEM TRACKING -------------------
  
  /// Track when a viral system was chosen (to hide it for 24h)
  static Future<void> markSystemAsChosen(String systemName) async {
    await _settingsBox?.put('viral_chosen_$systemName', DateTime.now().toIso8601String());
  }
  
  /// Check if a viral system was chosen in the last 24 hours
  static bool wasSystemRecentlyChosen(String systemName) {
    final chosenAtStr = _settingsBox?.get('viral_chosen_$systemName');
    if (chosenAtStr == null) return false;
    
    try {
      final chosenAt = DateTime.parse(chosenAtStr as String);
      final hoursSinceChosen = DateTime.now().difference(chosenAt).inHours;
      return hoursSinceChosen < 24; // Hide for 24 hours
    } catch (e) {
      return false;
    }
  }

  // ------------------- VOICE SELECTION (TTS) -------------------
  
  /// Set selected TTS voice
  static Future<void> setSelectedVoice(String voiceId) async {
    await _settingsBox?.put('selected_voice', voiceId);
  }
  
  /// Get selected TTS voice (defaults to "marcus")
  static String getSelectedVoice() {
    return _settingsBox?.get('selected_voice', defaultValue: 'marcus') as String? ?? 'marcus';
  }

  // -------------------  STREAK & ANALYTICS (date-aware)  -------------------

  static int calculateCurrentStreak() {
    final habits = getAllHabits();
    if (habits.isEmpty) return 0;
    int streak = 0;
    final today = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final checkDate = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final dayHabits =
          habits.where((h) => h.isScheduledForDate(checkDate)).toList();
      if (dayHabits.isEmpty) continue;

      final allCompleted =
          dayHabits.every((h) => h.isDoneOn(checkDate));
      if (allCompleted) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static int calculateLongestStreak() {
    final habits = getAllHabits();
    if (habits.isEmpty) return 0;
    int longest = 0, current = 0;
    DateTime? earliest;
    for (final h in habits) {
      earliest ??= h.startDate;
      if (h.startDate.isBefore(earliest)) earliest = h.startDate;
    }
    if (earliest == null) return 0;
    final days = DateTime.now().difference(earliest).inDays;

    for (int i = 0; i <= days; i++) {
      final d = DateTime(
        earliest.year,
        earliest.month,
        earliest.day + i,
      );
      final dayHabits =
          habits.where((h) => h.isScheduledForDate(d)).toList();
      if (dayHabits.isEmpty) {
        current = 0;
        continue;
      }
      final allCompleted =
          dayHabits.every((h) => h.isDoneOn(d));
      if (allCompleted) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  static double getFulfillmentPercentage(DateTime date) {
    final dayHabits =
        getAllHabits().where((h) => h.isScheduledForDate(date)).toList();
    if (dayHabits.isEmpty) return 0.0;
    final completedCount =
        dayHabits.where((h) => h.isDoneOn(date)).length;
    return (completedCount / dayHabits.length) * 100;
  }

  static double getTodayFulfillmentPercentage() =>
      getFulfillmentPercentage(DateTime.now());

  static double getDriftPercentage(DateTime date) =>
      100 - getFulfillmentPercentage(date);

  static double getTodayDriftPercentage() =>
      getDriftPercentage(DateTime.now());
}
