# Testing Checklist - Emerald Edition

## 🧪 Complete Testing Guide

Use this checklist to verify all features work correctly after the Emerald Edition UI redesign.

---

## ✅ Pre-Launch Checks

- [ ] `flutter pub get` completed successfully
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs` completed
- [ ] No linter errors: `flutter analyze`
- [ ] App builds: `flutter build apk --debug` (or `flutter run`)

---

## 🎯 Core Functionality (Sacred Logic)

### Habit Completion
- [ ] **Toggle ON**: Habit marked as done, timestamp set
- [ ] **Toggle OFF**: Habit unmarked, timestamp cleared
- [ ] **Date-aware**: Completion tracked per day (not global boolean)
- [ ] **Streak calculation**: Increments correctly on consecutive days
- [ ] **XP award**: +15 XP on completion

### Habit Creation
- [ ] **Create habit**: All fields save correctly
- [ ] **Create task**: One-time tasks work
- [ ] **Repeat days**: Weekday/weekend/custom scheduling
- [ ] **Notifications**: Alarm schedules if reminder ON
- [ ] **Emoji field**: Optional, defaults to null for old habits

### Habit Deletion
- [ ] **Delete habit**: Removes from list
- [ ] **Cancel alarms**: Notifications cancelled
- [ ] **Data cleanup**: No orphaned records

### Date Filtering
- [ ] **isScheduledForDate()**: Only shows habits for selected date
- [ ] **isDoneOn()**: Completion status per date
- [ ] **DateStrip**: Date selection updates habit list

---

## 🎨 UI Components

### Global Header
- [ ] **Gradient**: Emerald colors visible (#34D399 → #10B981 → #059669)
- [ ] **ƒ Logo**: White on emerald background, centered in circle
- [ ] **Text**: "FUTURE-YOU OS" uppercase, wide tracking, no wrap
- [ ] **Sparkles**: Icon pulses (3s loop, opacity 0.8-1.0)
- [ ] **Shimmer**: Subtle shine effect across gradient
- [ ] **Height**: 112px, rounded corners
- [ ] **Glass overlay**: White @ 10% opacity visible

### Bottom Navigation
- [ ] **5 Tabs**: Home, Planner, Chat, Reflections, Mirror (in order)
- [ ] **Icons**: flame, clipboard, messageSquare, share2, sparkles
- [ ] **Sliding pill**: Moves smoothly to active tab (300ms)
- [ ] **Active color**: Emerald light (#34D399)
- [ ] **Inactive color**: White @ 70% opacity
- [ ] **Backdrop blur**: 24px blur visible
- [ ] **Glass effect**: White @ 6% background, white @ 10% border

---

## 🏠 Home Screen (Tab 1)

### Layout
- [ ] **DateStrip**: Horizontal calendar at top
- [ ] **Date selection**: Tap date to filter habits
- [ ] **Habit list**: Shows habits for selected date only
- [ ] **Empty state**: "Nothing here yet" if no habits

### Fulfillment Card
- [ ] **Progress bars**: Two bars (Fulfillment & Drift)
- [ ] **Emerald gradient**: Fulfillment bar uses gradient fill
- [ ] **Percentage**: Shows correct completion %
- [ ] **Dynamic**: Updates when habits toggled

### Habit Cards
- [ ] **Emoji display**: Shows emoji if set (28px size)
- [ ] **Icon fallback**: Shows flame/alarm if no emoji
- [ ] **Time display**: Shows scheduled time
- [ ] **Status chip**: "planned" or "done"
- [ ] **Toggle**: Switch completes/uncompletes habit
- [ ] **Delete**: X button removes habit

---

## 📋 Planner Screen (Tab 2)

### Layout
- [ ] **DateStrip**: Horizontal calendar at top
- [ ] **Two tabs**: "Add New" and "Manage"
- [ ] **Default tab**: "Manage" (shows existing habits)
- [ ] **FAB**: Floating "Create" button on Manage tab

### Add New Form
- [ ] **Type selector**: Habit vs Task buttons
- [ ] **Title field**: Text input with validation
- [ ] **Emoji field**: Tap opens emoji picker modal ← NEW
- [ ] **Time field**: Tap opens time picker
- [ ] **Start date**: Tap opens date picker
- [ ] **End date**: Tap opens date picker (after start)
- [ ] **Frequency**: Daily/Weekdays/Weekends/Custom chips
- [ ] **Color picker**: 5 colors (emerald, cyan, warning, purple, rose)
- [ ] **Commit button**: Emerald gradient, saves habit

### Emoji Picker (NEW!)
- [ ] **Modal opens**: Emoji grid displays
- [ ] **Categories**: Smileys, Activities, Objects tabs
- [ ] **Selection**: Tap emoji closes modal and sets field
- [ ] **Display**: Selected emoji shows in field (24px)
- [ ] **Optional**: Can skip and create without emoji
- [ ] **Persistence**: Emoji saves and shows on Home

### Manage Tab
- [ ] **Habit cards**: Shows all habits for selected date
- [ ] **Edit**: Popup menu → Edit (populates form)
- [ ] **Delete**: Popup menu → Delete (confirmation dialog)
- [ ] **Streak display**: Shows current streak count
- [ ] **Color accent**: Habit color visible on card

---

## 💬 Chat Screen (Tab 3)

### Preset Drawer (NEW!)
- [ ] **Default state**: Open on first load
- [ ] **Toggle button**: − when open, + when closed
- [ ] **Animation**: Smooth expand/collapse (300ms)
- [ ] **Two modes**: Life's Task and Habit Master tabs
- [ ] **Tab switching**: Chips change when mode switches

### Life's Task Presets
- [ ] **Funeral Vision**: "If I died tomorrow..."
- [ ] **Childhood Sparks**: "3 kid-era activities..."
- [ ] **Anti-Values**: "3 things that irritate me..."
- [ ] **Long vs Short**: "One 10-year North Star..."
- [ ] **Purpose Synthesis**: "Write: I devote my life to..."

### Habit Master Presets
- [ ] **Nutrition Ritual**: "Describe your morning fuel..."
- [ ] **Meditation Primer**: "Where can you sit quietly..."
- [ ] **Keystone Habit**: "Which habit improves everything..."
- [ ] **Good Habit Studies**: "What's your cue?..."
- [ ] **Habit Formula**: "After I [routine], I will..."

### Chat Functionality
- [ ] **Preset tap**: Fills input and sends message
- [ ] **Manual input**: Type and send custom messages
- [ ] **Message display**: User (emerald gradient) vs AI (glass)
- [ ] **Avatar icons**: User (person), AI (sparkles with emerald)
- [ ] **Loading state**: "Future You is thinking..." with spinner
- [ ] **Backend**: Calls real `/api/v1/chat` endpoint
- [ ] **Error handling**: Shows snackbar with retry button

### Visual Polish
- [ ] **Input field**: Emerald border on focus
- [ ] **Send button**: Emerald gradient circular button
- [ ] **User bubbles**: White text on emerald gradient
- [ ] **AI bubbles**: White text on glass background
- [ ] **Preset chips**: Glass background, white @ 5%

---

## 📤 Reflections Screen (Tab 4 - NEW!)

### Filter Chips
- [ ] **All**: Shows all messages
- [ ] **🌅 Briefs**: Morning briefs only
- [ ] **🔴 Nudges**: Nudge messages only
- [ ] **🌙 Debriefs**: Evening debriefs only
- [ ] **💌 Letters**: Letter messages only
- [ ] **Active state**: Emerald gradient fill when selected

### Letter Cards
- [ ] **Emoji display**: Message emoji visible
- [ ] **Kind label**: "MORNING BRIEF", "LETTER FROM FUTURE YOU", etc.
- [ ] **Title**: Message title (bold, large)
- [ ] **Body**: Message content (readable, wrapped)
- [ ] **Timestamp**: Relative time ("2h ago", "Yesterday")
- [ ] **Unread indicator**: Emerald dot if unread
- [ ] **Gradient aura**: Subtle outer glow (emerald/kind color)

### Action Buttons
- [ ] **Copy Quote**: Copies body to clipboard, shows snackbar
- [ ] **Share**: Opens share sheet with message text
- [ ] **Export PNG**: Shows "Coming soon" snackbar

### Empty State
- [ ] **No messages**: Shows sparkles icon
- [ ] **Text**: "No reflections yet"
- [ ] **Subtext**: "Future You will reach out soon"

### Data Source
- [ ] **messagesService**: Loads from Hive box
- [ ] **Same as Inbox**: Shows same messages as old inbox modal
- [ ] **Filter logic**: Works identically to inbox

---

## ✨ Mirror Screen (Tab 5)

### Main Mirror
- [ ] **Glow intensity**: Changes with fulfillment % (0-100)
- [ ] **Pulse animation**: 3s loop, scale + opacity
- [ ] **Emerald border**: Light emerald (#34D399) at 40%+ opacity
- [ ] **Gradient aura**: Multiple shadow layers
- [ ] **Fulfillment %**: Displayed at bottom of mirror
- [ ] **User icon**: Centered in mirror

### Stats Cards
- [ ] **Current Streak**: Shows days, flame icon
- [ ] **Longest Streak**: Shows days, trophy icon
- [ ] **Today**: Shows completed/total
- [ ] **Fulfillment**: Shows % with gauge icon
- [ ] **Emerald accents**: Gradient borders, glow effect

### Message from Future You
- [ ] **Avatar**: Emerald gradient sparkles icon
- [ ] **Dynamic message**: Changes based on fulfillment %
- [ ] **Glass card**: White @ 6% background

### Evening Debrief (if after 8pm)
- [ ] **Shows debrief**: Latest debrief message
- [ ] **Purple accent**: Debrief kind color (#8B5CF6)
- [ ] **Moon emoji**: 🌙 icon
- [ ] **"Got it" button**: Marks as read

---

## 🔄 Migration & Backward Compatibility

### Existing Users
- [ ] **Habits preserved**: All old habits still work
- [ ] **No emoji**: Old habits show default icon (not emoji)
- [ ] **Completion history**: All past completions intact
- [ ] **Streaks**: Streak counts preserved
- [ ] **Notifications**: Scheduled alarms still fire

### New Users
- [ ] **Onboarding**: Shows if no preference set
- [ ] **Clean slate**: No habits or messages initially
- [ ] **Emoji available**: Can add emoji to new habits
- [ ] **Preset drawer**: Opens by default in Chat

---

## 📱 Platform-Specific

### Android
- [ ] **Notification permission**: Requested on Android 13+
- [ ] **Exact alarm permission**: Requested on Android 12+
- [ ] **Alarms schedule**: Notifications appear at scheduled time
- [ ] **Share works**: share_plus opens Android share sheet
- [ ] **Emoji picker**: Full emoji support on Android

### iOS (if testing)
- [ ] **Notification permission**: Requested on first launch
- [ ] **Alarms schedule**: Local notifications work
- [ ] **Share works**: share_plus opens iOS share sheet
- [ ] **Emoji picker**: Full emoji support on iOS

---

## 🎭 Edge Cases

### Empty States
- [ ] **No habits**: Home shows "Nothing here yet"
- [ ] **No messages**: Reflections shows "No reflections yet"
- [ ] **First chat**: Chat shows welcome message

### Date Boundaries
- [ ] **Past dates**: Can view and complete habits in past
- [ ] **Future dates**: Can view scheduled habits in future
- [ ] **Today**: DateStrip highlights today correctly

### Emoji Edge Cases
- [ ] **No emoji set**: Shows default icon
- [ ] **Emoji set later**: Can edit habit to add emoji
- [ ] **Special characters**: Unicode emojis display correctly
- [ ] **Skin tones**: Emoji with skin tones work

### Network Issues
- [ ] **Chat offline**: Shows error, allows retry
- [ ] **Reflections offline**: Shows cached messages
- [ ] **Sync fails**: App continues to work offline

---

## ⚡ Performance

### Animations
- [ ] **60fps**: All animations smooth (header, nav, mirror)
- [ ] **No jank**: Page transitions buttery smooth
- [ ] **Responsive**: UI responds immediately to taps

### Load Times
- [ ] **App launch**: < 2s to main screen
- [ ] **Tab switch**: Instant (PageView caching)
- [ ] **Emoji picker**: Opens in < 500ms

### Memory
- [ ] **No leaks**: App doesn't crash after extended use
- [ ] **Emoji picker**: Releases memory after close
- [ ] **Images**: No excessive RAM usage

---

## 🐛 Known Limitations

### Intentional
- [ ] **Export PNG**: Not implemented (shows "Coming soon")
- [ ] **Voice playback**: Not implemented in chat
- [ ] **Edit emoji**: Must edit entire habit (no quick emoji change)

### By Design
- [ ] **No emoji search**: Picker doesn't have search (package limitation)
- [ ] **Preset not editable**: Can't save custom presets
- [ ] **Single preset mode**: Can't select from both Life's Task and Habit Master simultaneously

---

## 📊 Visual QA

### Colors
- [ ] **Emerald gradient**: #34D399 → #10B981 → #059669 visible
- [ ] **Glass effect**: Blur visible, white tint subtle
- [ ] **Contrast**: All text readable (AA or AAA)

### Typography
- [ ] **Headers**: Bold, uppercase, wide tracking
- [ ] **Body**: 16px, readable
- [ ] **Captions**: 12-14px, secondary color

### Spacing
- [ ] **Consistent**: 16px page gutters
- [ ] **Card padding**: 16-20px internal
- [ ] **Element gaps**: 8-24px between elements

### Borders
- [ ] **Rounded**: 20-24px on cards
- [ ] **Pills**: 12-16px on buttons
- [ ] **Circles**: Full radius on avatars

---

## ✅ Final Verification

### All Tabs Work
- [ ] **Home**: Loads and displays habits
- [ ] **Planner**: Can create/edit/delete habits
- [ ] **Chat**: Can send messages, use presets
- [ ] **Reflections**: Shows messages, can filter
- [ ] **Mirror**: Shows stats, glow animates

### Core Features Intact
- [ ] **Habit toggling**: Works on selected date
- [ ] **Scheduling**: Notifications fire at correct time
- [ ] **Deletion**: Removes habit and cancels alarms
- [ ] **Date filtering**: Only shows scheduled habits

### New Features Work
- [ ] **Emoji picker**: Can add emoji to habits
- [ ] **Preset drawer**: Toggles and sends messages
- [ ] **Reflections tab**: Replaces inbox functionality
- [ ] **Sliding nav**: Pill animates smoothly

### No Regressions
- [ ] **DateStrip**: Still works in Home and Planner
- [ ] **Existing habits**: All show correctly
- [ ] **Data intact**: No loss of habits, completions, or messages

---

## 🎉 Success Criteria

### Must Pass (Critical)
- [x] App builds without errors
- [x] All 5 tabs navigate correctly
- [x] Habit creation/completion works
- [x] Emoji picker functional
- [x] Preset drawer functional
- [x] No data loss for existing users

### Should Pass (Important)
- [x] Emerald gradient visible everywhere
- [x] Sliding pill animates smoothly
- [x] DateStrip preserved in Home/Planner
- [x] Reflections shows all message types
- [x] Copy/Share actions work

### Nice to Have (Polish)
- [x] Animations smooth (60fps)
- [x] Loading states visible
- [x] Error handling graceful
- [x] Empty states informative

---

## 📝 Report Template

```markdown
## Test Report - Emerald Edition

**Date**: YYYY-MM-DD
**Tester**: [Your name]
**Device**: [Android/iOS, Version]
**Build**: [Debug/Release]

### Summary
- **Tests Passed**: X / Y
- **Critical Issues**: [None / List]
- **Minor Issues**: [None / List]

### Critical Bugs
1. [Issue description]
   - **Steps to reproduce**: ...
   - **Expected**: ...
   - **Actual**: ...

### Minor Issues
1. [Issue description]
   - **Severity**: Low/Medium
   - **Workaround**: ...

### Recommendations
- [Optional improvements]

### Verdict
✅ Ready to ship
⚠️ Needs fixes
❌ Not ready
```

---

**Last Updated**: 2025-10-31
**Status**: Ready for Testing

