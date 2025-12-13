# 🔥 STREAK INTEGRATION PLAN - Clean & Non-Breaking

## 📊 CURRENT STATE ANALYSIS

### ✅ BACKEND (Already Working)
```
✓ Habit model has `streak: Int` field
✓ `lastTick: DateTime?` field for tracking
✓ Coach service logs streak data in events
✓ Metrics controller calculates current/longest streaks
✓ API endpoint: GET /api/v1/user/metrics returns streaks
```

### ⚠️  FRONTEND (Partially Working)
```
✓ StreakBadge widget exists (beautiful UI)
✓ StreakFlame widget (animated fire)
✓ LocalStorageService.calculateCurrentStreak()
✓ StreakService exists for state management
✓ OSStatusHUD shows overall streak
✓ MirrorScreen shows current/longest streaks

✗ Individual habits DON'T show their streaks
✗ Command Center has hardcoded "47 Days"
✗ No per-habit streak display on home screen
✗ No streak celebration animations
```

---

## 🎯 IMPLEMENTATION PLAN (5 Clean Steps)

### **STEP 1: Update Habit Model (Flutter)**
**File:** `lib/models/habit.dart`

**Current:**
```dart
class Habit {
  String id;
  String title;
  // ...
}
```

**Add:**
```dart
class Habit {
  String id;
  String title;
  int streak;           // ← ADD THIS
  DateTime? lastTick;   // ← ADD THIS (if not already there)
  
  // In fromJson():
  streak: json['streak'] as int? ?? 0,
  lastTick: json['lastTick'] != null 
    ? DateTime.parse(json['lastTick']) 
    : null,
  
  // In toJson():
  'streak': streak,
  'lastTick': lastTick?.toIso8601String(),
}
```

**Why Safe:** Only adds fields, doesn't change existing logic.

---

### **STEP 2: Sync Streaks from Backend**
**File:** `lib/services/sync_service.dart`

**Add method:**
```dart
Future<void> syncHabitStreaks() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/habits'),
      headers: {'x-user-id': userId},
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final habits = (data['habits'] as List)
        .map((h) => Habit.fromJson(h))
        .toList();
      
      // Update local storage with streak data
      for (final habit in habits) {
        LocalStorageService.updateHabitStreak(
          habit.id, 
          habit.streak, 
          habit.lastTick
        );
      }
    }
  } catch (e) {
    debugPrint('⚠️ Failed to sync streaks: $e');
  }
}
```

**Why Safe:** New method, doesn't modify existing sync logic.

---

### **STEP 3: Add Per-Habit Streak Display**
**File:** `lib/widgets/habit_card.dart` (or wherever habit cards are)

**Add streak badge to habit card:**
```dart
// Inside habit card build method:
Row(
  children: [
    Text(habit.title, ...),
    Spacer(),
    if (habit.streak > 0)
      Row(
        children: [
          StreakFlame(streak: habit.streak, size: 16),
          SizedBox(width: 4),
          Text(
            '${habit.streak}',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
  ],
)
```

**Why Safe:** Only adds visual element, doesn't change behavior.

---

### **STEP 4: Update Habit Completion Logic**
**File:** `lib/services/habit_service.dart` (or habit completion logic)

**When completing a habit:**
```dart
Future<void> completeHabit(String habitId) async {
  final habit = LocalStorageService.getHabit(habitId);
  
  // Check if this is consecutive day completion
  final today = DateTime.now();
  final lastTick = habit.lastTick;
  
  bool isConsecutive = false;
  if (lastTick != null) {
    final daysSince = today.difference(lastTick).inDays;
    isConsecutive = daysSince == 1; // Completed yesterday
  }
  
  // Update streak
  final newStreak = isConsecutive ? habit.streak + 1 : 1;
  
  // Save locally
  LocalStorageService.updateHabitStreak(
    habitId, 
    newStreak, 
    today
  );
  
  // Sync to backend
  await syncService.syncHabits();
  
  // Show celebration if milestone
  if (newStreak == 7 || newStreak == 30 || newStreak == 100) {
    _showStreakCelebration(habit.title, newStreak);
  }
}
```

**Why Safe:** Only extends completion logic, preserves existing flow.

---

### **STEP 5: Fix Command Center (Remove Hardcoded Data)**
**File:** `lib/screens/command_center_screen.dart`

**Current:**
```dart
Text('47 Days', ...)  // ← HARDCODED
```

**Replace with:**
```dart
FutureBuilder<OSMetrics>(
  future: OSMetricsService.getMetrics(),
  builder: (context, snapshot) {
    final currentStreak = snapshot.data?.currentStreak ?? 0;
    return Text(
      '$currentStreak Days',
      style: AppTextStyles.h3.copyWith(
        color: AppColors.emerald,
        fontWeight: FontWeight.w900,
      ),
    );
  },
)
```

**Why Safe:** Just replaces hardcoded value with real data.

---

## 🎨 BONUS: Streak Celebration Animation

**File:** `lib/widgets/streak_celebration.dart` (NEW)

```dart
void showStreakCelebration(BuildContext context, String habitTitle, int streak) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.transparent,
      content: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreakFlame(streak: streak, size: 80),
            SizedBox(height: AppSpacing.md),
            Text(
              '$streak Day Streak!',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.warning,
              ),
            ),
            Text(
              habitTitle,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

## �� IMPLEMENTATION CHECKLIST

### Phase 1: Backend Verification (Already Done ✅)
- [x] Habit model has streak field
- [x] API returns streak data
- [x] Streaks are calculated correctly

### Phase 2: Model Updates (Non-Breaking)
- [ ] Add `streak` field to Flutter Habit model
- [ ] Add `lastTick` field to Flutter Habit model
- [ ] Update fromJson/toJson methods
- [ ] Test model serialization

### Phase 3: Data Sync (Non-Breaking)
- [ ] Add syncHabitStreaks() method
- [ ] Call on app startup
- [ ] Call after habit completion
- [ ] Add to periodic sync

### Phase 4: UI Updates (Additive Only)
- [ ] Add StreakFlame to habit cards
- [ ] Show streak number next to habits
- [ ] Fix Command Center hardcoded data
- [ ] Add to planner view (optional)

### Phase 5: Logic Updates (Extend, Don't Replace)
- [ ] Update completion logic to increment streaks
- [ ] Handle streak breaks (missed days)
- [ ] Add milestone detection (7, 30, 100 days)
- [ ] Add celebration animations

### Phase 6: Polish & Test
- [ ] Test streak increments correctly
- [ ] Test streak resets on missed days
- [ ] Test sync after completion
- [ ] Test UI doesn't break with 0 streaks
- [ ] Test animations perform well

---

## 🚨 SAFETY GUIDELINES

### ✅ DO:
- Add new fields with defaults
- Make UI changes additive (show streak IF exists)
- Keep existing sync logic intact
- Add new methods, don't modify old ones
- Test incrementally

### ❌ DON'T:
- Remove or rename existing fields
- Break existing habit completion flow
- Change API contracts
- Modify sync service core logic
- Deploy all at once without testing

---

## 🔥 IMPLEMENTATION ORDER (Safest First)

1. **Update Model** (safest - just adds fields)
2. **Add UI Display** (safe - just shows data if exists)
3. **Fix Hardcoded Data** (safe - replaces fake with real)
4. **Add Sync Method** (safe - new method)
5. **Update Completion Logic** (careful - test thoroughly)
6. **Add Celebrations** (polish - do last)

---

## 📊 SUCCESS METRICS

After implementation, you should see:
- ✅ Each habit shows 🔥 with streak number
- ✅ Command Center shows real streak data
- ✅ Mirror screen shows accurate current/longest
- ✅ Streaks increment on consecutive completions
- ✅ Streaks reset on missed days
- ✅ Celebrations at 7, 30, 100 day milestones
- ✅ AI OS references real streak data in briefs

---

## 🧪 TESTING PLAN

1. **Complete a habit** → Streak should increment
2. **Complete same habit next day** → Streak +1
3. **Skip a day** → Streak resets to 0
4. **Check Command Center** → Shows real data
5. **Check Mirror** → Shows correct current/longest
6. **Complete to day 7** → Celebration appears
7. **Restart app** → Streaks persist

