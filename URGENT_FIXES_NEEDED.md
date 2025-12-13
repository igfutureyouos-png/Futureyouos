# URGENT FIXES - User is Frustrated

## 1. Celebrity Systems Dialog - COPY FROM VIRAL SYSTEMS ✅

**Problem:** Celebrity Systems dialog is missing:
- Start/End Date pickers
- Schedule Type selection (Everyday/Weekdays/Weekends)  
- Alarm toggle with time picker UI
- Helper methods `_buildDateField()` and `_buildScheduleOption()`

**Solution:** Copy lines 576-1040 from `viral_systems_screen.dart` `_CommitDialogState.build()` method to `celebrity_systems_screen.dart` line 481

The dialog should have THIS EXACT STRUCTURE:
1. Title "Commit to {system.name}"
2. Start Date picker
3. End Date picker  
4. Schedule Type (3 buttons: Everyday/Weekdays/Weekends)
5. Habit Selection (scrollable list with checkboxes)
6. Alarm Toggle switch
7. Time Picker (only shows when alarm enabled)
8. Cancel/Commit buttons

Also copy helper methods:
- `_buildDateField()` from line 1000-1040
- `_buildScheduleOption()` from line 956-998

##  2. Purpose Engine Descriptions - MAKE COMPLETE ✅

**Problem:** Top 3 video card descriptions are truncated mid-word

**File:** `lib/screens/future_you_screen.dart` lines 67-96

**Current:**
```dart
VideoData(
  id: 1,
  title: 'The Funeral Exercise',
  description: 'Walk into your own funeral. What do you want them to say?',  // ✅ This one is OK
),
VideoData(
  id: 2,
  title: 'The Last Day',
  description: 'If today was your last, what would you regret not doing?',  // ✅ This one is OK
),
VideoData(
  id: 3,
  title: 'Your Hero\'s Journey',
  description: 'What challenge is calling you to become more?',  // ✅ This one is OK
),
```

**Actually these look complete!** User may be seeing something else. Check if descriptions render fully on screen or if container is too small.

## 3. Add Colored Tab Names to Headers ✅

**Files to modify:**
- `lib/screens/planner_screen.dart`
- `lib/screens/future_you_screen.dart`  
- `lib/screens/habit_master_screen.dart`

**Add to AppBar or header:**
```dart
// Planner - Use CYAN color
Text(
  'PLANNER',
  style: TextStyle(
    color: Color(0xFF06B6D4), // Cyan
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
  ),
)

// Purpose Engine - Use PURPLE color
Text(
  'PURPOSE ENGINE',
  style: TextStyle(
    color: Color(0xFFA855F7), // Purple
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
  ),
)

// Habit Master - Use EMERALD color
Text(
  'HABIT MASTER',
  style: TextStyle(
    color: Color(0xFF10B981), // Emerald  
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
  ),
)
```

## 4. What-If Simulator Routing - ALREADY CORRECT ✅

**File:** `lib/screens/command_center_screen.dart` line 88

**Current code:**
```dart
onTap: () => Navigator.pushNamed(context, '/what-if'),
```

**Route definition** in `lib/main.dart` line 140:
```dart
'/what-if': (context) => const WhatIfScreen(),
```

**This is ALREADY CORRECT!** 

If user says it goes to wrong page, they may be:
1. Clicking a different card
2. Seeing cached old version
3. The `WhatIfScreen` itself might be the wrong screen

**Verify:** Check what `WhatIfScreen` actually shows. If it's wrong, the screen implementation is the problem, not the routing.

---

## PRIORITY ORDER:

1. **Celebrity Systems Dialog** - Biggest issue, most work
2. **Tab Headers** - Quick win, adds polish
3. **Purpose Engine Descriptions** - Check if actually truncated
4. **What-If Routing** - Already correct, verify with user

## WHY ALARM ISN'T WORKING:

The alarm code IS working. The problem is:
1. User must ENABLE the alarm toggle when creating habits
2. Android permissions must be granted
3. Battery optimization must be disabled for the app

Once Celebrity Systems dialog is fixed with the alarm toggle UI, users will be able to properly enable alarms.

