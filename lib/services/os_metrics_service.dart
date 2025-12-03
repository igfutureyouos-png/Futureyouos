import '../services/local_storage.dart';
import '../services/weekly_stats_service.dart';
import '../services/api_client.dart';

/// 🔥 OS METRICS ENGINE
/// Calculates discipline %, system strength, and streak data
/// for the AI Operating System consciousness display
class OSMetrics {
  final double discipline; // 0-100
  final double disciplineToday; // 0-100
  final double disciplineWeekly; // 0-100
  final double systemStrength; // 0-100
  final int currentStreak;
  final int longestStreak;
  final int activeHabits;
  final double completionRateLast7Days;

  OSMetrics({
    required this.discipline,
    required this.disciplineToday,
    required this.disciplineWeekly,
    required this.systemStrength,
    required this.currentStreak,
    required this.longestStreak,
    required this.activeHabits,
    required this.completionRateLast7Days,
  });

  Map<String, dynamic> toJson() => {
        'discipline': discipline.round(),
        'disciplineBreakdown': {
          'today': disciplineToday.round(),
          'weekly': disciplineWeekly.round(),
        },
        'systemStrength': systemStrength.round(),
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'activeHabits': activeHabits,
        'completionRateLast7Days': completionRateLast7Days.round(),
      };
}

class OSMetricsService {
  /// 🎯 CALCULATE ALL METRICS (LOCAL ONLY)
  /// This is the brain of the OS - all consciousness metrics in one place
  /// For offline/fast calculation based on local data
  static OSMetrics calculateMetrics() {
    final habits = LocalStorageService.getAllHabits();
    
    // If no habits, return zeros
    if (habits.isEmpty) {
      return OSMetrics(
        discipline: 0,
        disciplineToday: 0,
        disciplineWeekly: 0,
        systemStrength: 0,
        currentStreak: 0,
        longestStreak: 0,
        activeHabits: 0,
        completionRateLast7Days: 0,
      );
    }

    // 1. DISCIPLINE PERCENTAGE (Weighted: 60% today + 40% weekly)
    final todayCompletion = LocalStorageService.getTodayFulfillmentPercentage();
    final weeklyStats = WeeklyStatsService.calculateCurrentWeekStats();
    final weeklyCompletion = weeklyStats.trendingPercentage;
    
    final discipline = (todayCompletion * 0.6) + (weeklyCompletion * 0.4);

    // 2. SYSTEM STRENGTH (Complex: streak + completion + consistency)
    final currentStreak = LocalStorageService.calculateCurrentStreak();
    final longestStreak = LocalStorageService.calculateLongestStreak();
    
    // Streak contribution (40% weight, capped at 20 days = 100%)
    final streakScore = (currentStreak / 20 * 100).clamp(0, 100);
    
    // Weekly completion contribution (35% weight)
    final completionScore = weeklyCompletion;
    
    // Consistency score (25% weight) - penalize variance
    final consistencyScore = _calculateConsistencyScore();
    
    final systemStrength = 
      (streakScore * 0.40) + 
      (completionScore * 0.35) + 
      (consistencyScore * 0.25);

    // 3. ACTIVE HABITS
    final activeHabits = habits.where((h) => h.isScheduledForDate(DateTime.now())).length;

    return OSMetrics(
      discipline: discipline,
      disciplineToday: todayCompletion,
      disciplineWeekly: weeklyCompletion,
      systemStrength: systemStrength,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      activeHabits: activeHabits,
      completionRateLast7Days: weeklyCompletion,
    );
  }

  /// 📊 CONSISTENCY SCORE
  /// Lower variance = higher consistency = better score
  static double _calculateConsistencyScore() {
    final habits = LocalStorageService.getAllHabits();
    if (habits.isEmpty) return 0;

    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: i)));
    
    final completionRates = last7Days.map((date) {
      return LocalStorageService.getFulfillmentPercentage(date);
    }).toList();

    // Calculate variance
    final mean = completionRates.reduce((a, b) => a + b) / completionRates.length;
    final variance = completionRates.map((rate) => (rate - mean) * (rate - mean)).reduce((a, b) => a + b) / completionRates.length;
    final stdDev = variance.isFinite ? variance : 0;

    // Lower standard deviation = higher consistency
    // Perfect consistency (0 variance) = 100, high variance (>30) = 0
    final consistencyScore = (100 - (stdDev / 30 * 100)).clamp(0, 100);
    
    return consistencyScore;
  }

  /// 🎨 GET DISCIPLINE COLOR
  static OSMetricColor getDisciplineColor(double discipline) {
    if (discipline >= 70) {
      return OSMetricColor.emerald;
    } else if (discipline >= 50) {
      return OSMetricColor.amber;
    } else {
      return OSMetricColor.red;
    }
  }

  /// 🌟 GET GLOW COLOR FOR ORB
  static OSMetricColor getGlowColor(double systemStrength) {
    if (systemStrength >= 80) {
      return OSMetricColor.emerald;
    } else if (systemStrength >= 50) {
      return OSMetricColor.amber;
    } else {
      return OSMetricColor.red;
    }
  }

  /// ⚡ GET PULSE SPEED (seconds per pulse)
  /// Higher discipline = faster pulse (more alive)
  static double getPulseSpeed(double discipline) {
    if (discipline >= 80) {
      return 2.0; // Fast pulse - system is strong
    } else if (discipline >= 60) {
      return 3.0; // Medium pulse
    } else if (discipline >= 40) {
      return 4.0; // Slow pulse - warning
    } else {
      return 5.0; // Very slow pulse - critical
    }
  }

  /// 🔥 CHECK IF STREAK MILESTONE
  static bool isStreakMilestone(int streak) {
    return [7, 14, 30, 60, 100].contains(streak);
  }

  /// 📈 DISCIPLINE TREND
  /// Returns: 'improving', 'stable', 'declining'
  static String getDisciplineTrend() {
    final now = DateTime.now();
    final today = LocalStorageService.getFulfillmentPercentage(now);
    final yesterday = LocalStorageService.getFulfillmentPercentage(
      now.subtract(const Duration(days: 1))
    );
    
    if (today > yesterday + 10) return 'improving';
    if (today < yesterday - 10) return 'declining';
    return 'stable';
  }

  /// 🌐 FETCH METRICS FROM API (OPTIONAL)
  /// Use this when you want server-calculated metrics (more accurate with full backend data)
  /// Falls back to local calculation if API fails
  static Future<OSMetrics> fetchMetricsFromAPI() async {
    try {
      final response = await ApiClient.getOSMetrics();
      
      if (response.success && response.data != null) {
        final data = response.data!;
        return OSMetrics(
          discipline: (data['discipline'] as num).toDouble(),
          disciplineToday: (data['disciplineBreakdown']['today'] as num).toDouble(),
          disciplineWeekly: (data['disciplineBreakdown']['weekly'] as num).toDouble(),
          systemStrength: (data['systemStrength'] as num).toDouble(),
          currentStreak: data['currentStreak'] as int,
          longestStreak: data['longestStreak'] as int,
          activeHabits: data['activeHabits'] as int,
          completionRateLast7Days: (data['completionRateLast7Days'] as num).toDouble(),
        );
      }
    } catch (e) {
      // Fall through to local calculation
    }
    
    // Fallback to local calculation
    return calculateMetrics();
  }
}

enum OSMetricColor {
  emerald,
  amber,
  red,
}

