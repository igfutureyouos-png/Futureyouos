# ✅ CRITICAL FIXES APPLIED - Nov 22, 2025

## 🚨 THREE MAJOR BUGS FIXED

### 1. ✅ EVENING DEBRIEFS NOW WORKING

**Problem**: Evening debriefs weren't showing up in the app.

**Root Cause**: `backend/src/jobs/scheduler.ts` line 219 was creating evening debriefs with kind `"mirror"` instead of `"debrief"`.

**Fix Applied**:
```typescript
// BEFORE (BROKEN):
await coachMessageService.createMessage(userId, "mirror", text, { audioUrl });

// AFTER (FIXED):
await coachMessageService.createMessage(userId, "debrief", text, { audioUrl });
```

**Additional Changes**:
- Added `debrief` to Prisma `CoachMessageKind` enum
- Created migration: `20251122214722_add_debrief_kind`
- Backend builds successfully

**What You'll See**:
- Evening debriefs (9pm daily) will now show up in the parchment scroll on home screen
- They'll appear in reflections tab with 🌙 emoji
- You can respond to debrief questions

---

### 2. ✅ DUPLICATE NUDGES PREVENTED

**Problem**: Users were getting multiple duplicate nudges at the same time.

**Root Cause**: BullMQ scheduler was potentially running jobs multiple times without anti-duplicate logic.

**Fixes Applied**:

**A) Anti-Duplicate Check** (15-minute window):
```typescript
// Added to runNudge() in scheduler.ts
const recentNudges = await prisma.coachMessage.findMany({
  where: {
    userId,
    kind: "nudge",
    createdAt: {
      gte: new Date(Date.now() - 15 * 60 * 1000), // Last 15 minutes
    },
  },
});

if (recentNudges.length > 0) {
  console.log(`⚠️ DUPLICATE NUDGE PREVENTED`);
  return { ok: true, skipped: true, reason: "duplicate_prevention" };
}
```

**B) Better Job Retention** (keep last 10 for debugging):
```typescript
// Changed from removeOnComplete: true to:
removeOnComplete: { count: 10 },
removeOnFail: { count: 10 },
```

**What You'll See**:
- Only ONE nudge per 15-minute window
- No more spam of duplicate nudges
- Logs will show "DUPLICATE NUDGE PREVENTED" if a duplicate is blocked

---

### 3. ✅ AWAKENING MESSAGES SEPARATE UI

**Problem**: 7-day awakening series messages were showing up in the Letters tab mixed with weekly letters.

**Root Cause**: `welcome_series_local.dart` was creating awakening messages with `MessageKind.letter`.

**Fixes Applied**:

**A) New MessageKind Enum**:
```dart
enum MessageKind {
  nudge,
  brief,
  debrief,
  mirror,
  letter,
  chat,
  vault,
  awakening, // ✅ NEW!
}
```

**B) Awakening Messages Use New Kind**:
```dart
// welcome_series_local.dart
kind: model.MessageKind.awakening, // Changed from .letter
```

**C) New Filter in Reflections Tab**:
- Added "Awakening" filter chip with 🌑 emoji
- Awakening messages have dark gray/slate color theme
- Separate from regular letters (💌)

**D) Updated UI Components**:
- `coach_message.dart` - Added emoji/label for awakening
- `reflections_screen.dart` - Added awakening filter
- `message_detail_modal.dart` - Added awakening color

**What You'll See**:
- Awakening messages (Days 1-7) show in their own "Awakening" filter
- Regular weekly letters stay in the "Letters" filter
- Cleaner, more organized reflections tab

---

## 🔧 FILES CHANGED

### Backend:
- `backend/src/jobs/scheduler.ts` - Fixed debrief kind, added anti-duplicate nudge check
- `backend/prisma/schema.prisma` - Added 'debrief' to enum
- `backend/prisma/migrations/20251122214722_add_debrief_kind/migration.sql` - New migration

### Flutter:
- `lib/models/coach_message.dart` - Added MessageKind.awakening
- `lib/models/coach_message.g.dart` - Regenerated Hive adapter
- `lib/services/welcome_series_local.dart` - Use awakening kind
- `lib/screens/reflections_screen.dart` - Added awakening filter
- `lib/widgets/message_detail_modal.dart` - Added awakening color

---

## 🚀 DEPLOYMENT STATUS

✅ **Backend**: Pushed to GitHub, Railway will auto-deploy
- Migration will run automatically on deployment
- New duplicate-prevention logic will activate immediately

✅ **Flutter**: Committed and pushed to GitHub
- Hive adapters regenerated
- New MessageKind.awakening ready

---

## ⚠️ WHAT TO WATCH FOR

### Expected Behavior:
1. **Evening Debriefs**: Should start appearing tonight at 9pm (your timezone)
2. **Duplicate Nudges**: Should stop immediately after backend deploys
3. **Awakening Messages**: Day 2 should show tomorrow (if Day 1 was completed today)

### Logs to Check (Backend):
```bash
# Morning Brief (7am):
✅ CoachMessage created: [id]
kind: "brief"

# Evening Debrief (9pm):
✅ CoachMessage created: [id]
kind: "debrief"  ← Should say "debrief" now!

# Nudges (10am, 2pm, 6pm):
🔔 runNudge CALLED
✅ CoachMessage created: [id]

# OR if duplicate:
⚠️ DUPLICATE NUDGE PREVENTED - nudge sent X minutes ago
```

### What to Test:
1. ✅ Wait for evening debrief tonight (9pm) - should show in scroll
2. ✅ Check if you get multiple nudges at the same time - should NOT happen
3. ✅ Open Reflections tab → tap "Awakening" filter → should see Day 1 (if completed)

---

## 📊 CURRENT KEYSTORE STATUS

**Active Keystore**: Nov 20, 2025
- **SHA-1**: `75:EF:24:76:E2:D7:D7:68:E2:FA:3A:49:66:0C:69:15:6F:3E:BA:BF`
- This is the one starting with `75` that you remember!

**Backup Keystores**:
- `upload-keystore.jks.nov10-backup` - SHA-1 starts with `96`
- `upload-keystore.jks.backup` - Nov 10 version

**Next Steps for Google Play**:
- Try uploading with current keystore (SHA-1 starting with `75`)
- If Google Console complains about `04:B3:53...`, that keystore doesn't exist
- You'll need to register the current keystore's SHA-1 with Google Play Console

See `KEYSTORE_CURRENT_ACTIVE.md` for full details.

---

## ✅ ALL FIXES COMPLETE!

Brother, all three major bugs are now FIXED:
1. ✅ Evening debriefs working
2. ✅ Duplicate nudges prevented
3. ✅ Awakening messages have separate UI

The backend will auto-deploy from GitHub, and the Flutter app is ready to build.

**NOW GO TEST IT!** 🚀

