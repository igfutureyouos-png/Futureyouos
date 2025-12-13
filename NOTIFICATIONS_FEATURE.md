# OS Message Notifications Feature

## ✅ What Was Added

Automatic push notifications for all AI OS messages to ensure users engage with the system's advice.

## Notification Types

### 🌅 Morning Briefs
- **Title**: "🌅 Morning Brief Ready"
- **Body**: Brief title preview
- **When**: Automatically when backend generates morning brief (typically 6-10 AM)

### 🌙 Evening Debriefs
- **Title**: "🌙 Evening Debrief Ready"
- **Body**: Debrief title preview
- **When**: Automatically when backend generates evening debrief (typically 8-11 PM)

### 🔴 Nudges
- **Title**: "🔴 Nudge from Future You"
- **Body**: Nudge title preview
- **When**: When AI detects pattern slips or time-wasting (scheduled nudge times)

### 💌 Weekly Letters
- **Title**: "💌 Weekly Letter Arrived"
- **Body**: Letter title preview
- **When**: Weekly consolidation (typically Sunday night)

## Technical Implementation

### Files Modified
1. **`lib/services/messages_service.dart`**
   - Added `_showMessageNotification()` method
   - Integrated notification calls in `syncMessages()` (for backend messages)
   - Integrated notification calls in `saveLocalMessage()` (for local messages like welcome series)

2. **`lib/services/alarm_service.dart`**
   - Added `coach_messages` notification channel
   - High priority with sound, vibration, and lights

### How It Works

```dart
// When new message arrives from backend or locally
if (existing == null && !message.isRead) {
  await _showMessageNotification(message);
}
```

### Notification Properties
- **Channel**: `coach_messages`
- **Importance**: High (but not MAX like habit alarms)
- **Sound**: ✅ Enabled (default system sound)
- **Vibration**: ✅ Enabled
- **Lights**: ✅ Enabled (LED notification)
- **Badge**: Updates app icon badge with unread count

### Smart Features
1. **No Duplicates**: Uses message ID hash as notification ID to prevent duplicate notifications
2. **Only for New Messages**: Won't notify if message already exists locally
3. **Only for Unread**: Won't notify if message is already marked as read
4. **Tappable**: Clicking notification opens the app (payload contains message ID for future deep linking)

## User Experience

### First-Time Setup
- Notifications work automatically after user grants notification permission
- Permission is requested during `AlarmService.initialize()` at app startup

### Message Flow
1. Backend generates brief/debrief/nudge/letter
2. App syncs messages via `syncMessages()`
3. New message detected → Notification shown
4. User taps notification → Opens app
5. User reads message → Badge count decreases

### Welcome Series
- The 7-day welcome messages also trigger notifications
- Helps onboard new users by alerting them when each day's content is ready

## Testing

### To Test Notifications:
1. Create a test habit with alarm (confirm habit alarms work)
2. Wait for backend to generate a morning brief (6-10 AM)
3. Should receive notification: "🌅 Morning Brief Ready"
4. Check notification settings to ensure channel is enabled

### Debug Logging:
```
🔔 Notification shown for message: abc123 (Morning Brief)
```

## Comparison: Habit Alarms vs OS Messages

| Feature | Habit Alarms | OS Messages |
|---------|--------------|-------------|
| Channel | `habit_reminders` | `coach_messages` |
| Importance | MAX | High |
| Sound | ✅ | ✅ |
| Vibration | ✅ | ✅ |
| When | User-scheduled times | AI-generated times |
| Purpose | Action reminder | Guidance/reflection |

## Future Enhancements

Potential improvements for later:
1. **Deep Linking**: Tap notification to open specific message modal
2. **Action Buttons**: "Read Now" vs "Read Later" buttons on notification
3. **Custom Sounds**: Different sounds for briefs vs nudges
4. **Smart Timing**: ML to learn best notification times per user
5. **Quiet Hours**: Respect user's do-not-disturb preferences
6. **Notification Preview**: Show first line of message content

## Related Files

- `lib/services/messages_service.dart` - Message sync and notification logic
- `lib/services/alarm_service.dart` - Notification channel initialization
- `lib/models/coach_message.dart` - Message types and emoji definitions

## Status: ✅ LIVE

Feature is fully implemented and will be included in the next APK build from GitHub Actions.

