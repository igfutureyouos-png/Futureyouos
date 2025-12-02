# 🔔 iOS Notifications & Alarms Setup Guide

**CRITICAL**: iOS notifications require special configuration that Android doesn't need.

---

## ⚠️ Important iOS Limitations

Unlike Android, iOS has these restrictions:

1. **No Exact Timing**: iOS may delay notifications by up to 15-60 seconds to save battery
2. **Requires APNs**: You MUST configure Apple Push Notification service certificates
3. **Background Modes**: Need special permissions in Xcode
4. **User Permissions**: Must request explicitly at runtime (already handled in code)

---

## 📋 Step-by-Step Setup

### 1️⃣ Enable Background Modes in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. Click **"+ Capability"** button
5. Add **"Background Modes"**
6. Check these boxes:
   - ✅ **Background fetch**
   - ✅ **Remote notifications**

### 2️⃣ Configure Push Notification Capability

1. Still in **Signing & Capabilities**
2. Click **"+ Capability"** again
3. Add **"Push Notifications"**

### 3️⃣ Verify Info.plist Permissions

Open `ios/Runner/Info.plist` and ensure these keys exist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>

<key>NSUserNotificationsUsageDescription</key>
<string>We need notifications to remind you about your habits and send you daily briefs from your AI OS.</string>
```

**NOTE**: These should already be in the file, just verify!

### 4️⃣ Create APNs Certificate (Apple Developer Portal)

**This is the MOST IMPORTANT step for iOS notifications to work!**

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **"Identifiers"** → Select your app Bundle ID (`com.futureyou.futureyouos`)
4. Scroll to **"Push Notifications"** → Click **"Configure"**
5. Create **two certificates**:
   - **Development SSL Certificate** (for TestFlight)
   - **Production SSL Certificate** (for App Store)
6. Download both `.p8` key files

### 5️⃣ Upload APNs to Firebase (CRITICAL!)

Since the app uses Firebase for push notifications:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select the **Future-You OS** project
3. Go to **Project Settings** → **Cloud Messaging** tab
4. Under **"Apple app configuration"**:
   - Upload your **APNs Authentication Key** (`.p8` file)
   - Enter your **Key ID**
   - Enter your **Team ID**

**Without this, iOS notifications WILL NOT WORK!**

### 6️⃣ Test Notifications

#### A. Test in Simulator (Limited)
```bash
flutter run -d "iPhone 15 Pro"
```
**NOTE**: Simulator doesn't support real push notifications, only local ones.

#### B. Test on Real Device (Required)
1. Connect iPhone via USB
2. Run:
```bash
flutter run -d <your-device-id>
```
3. Grant notification permission when prompted
4. Create a habit with an alarm set for 1 minute from now
5. Wait for the notification

#### C. Test via TestFlight (Recommended)
1. Archive the app
2. Upload to TestFlight
3. Install on your iPhone
4. Test habit alarms thoroughly

---

## 🔍 Troubleshooting

### ❌ "Notifications not showing up"

**Check:**
1. Did you enable **Push Notifications** capability in Xcode?
2. Did you upload APNs certificate to Firebase?
3. Did you grant notification permission in iOS Settings?
4. Is the app in foreground or background when testing?

**iOS only shows notifications when the app is:**
- In the background
- Closed completely

**If app is in foreground**, notifications are silent (by design).

### ❌ "Build error: 'User Notifications' framework not found"

**Fix:**
1. Open Xcode
2. Select **Runner** target
3. Go to **Build Phases** → **Link Binary With Libraries**
4. Click **"+"** → Add `UserNotifications.framework`

### ❌ "Notification delayed by 5-10 minutes"

**This is normal iOS behavior.**
- iOS batches notifications to save battery
- Use `UNNotificationTrigger` with `repeats: true` for best results
- Our code already uses `DarwinNotificationDetails` which handles this

### ❌ "Firebase Cloud Messaging token not registering"

**Check:**
1. Is `GoogleService-Info.plist` in `ios/Runner/` folder? ✅ (should be there)
2. Is it added to Xcode project? (open Xcode and verify)
3. Are you running on a real device? (Simulator can't get FCM tokens)

---

## 🧪 Testing Checklist

Before submitting to App Store, test:

- [ ] Habit alarm fires at the correct time (±5 min is acceptable)
- [ ] Notification appears when app is in background
- [ ] Notification appears when app is fully closed
- [ ] Tapping notification opens the app
- [ ] Notification sound plays
- [ ] Notification shows motivational quote
- [ ] Badge icon updates (optional, but nice)
- [ ] Morning brief notification (sent by backend at 6 AM)
- [ ] Evening debrief notification (sent by backend at 9 PM)

---

## 📦 Files to Check

Before archiving, verify these files exist and are configured:

| File | Purpose | Status |
|------|---------|--------|
| `ios/Runner/GoogleService-Info.plist` | Firebase config | ✅ Should exist |
| `ios/Runner/Info.plist` | Permissions | ✅ Should have notification keys |
| `ios/Runner/Runner.entitlements` | App capabilities | ⚠️ Verify in Xcode |

---

## 🚀 Common iOS Notification Gotchas

### 1. Silent Notifications
iOS can silence notifications if:
- User disabled notifications for the app
- Device is in Do Not Disturb mode
- Device is in Low Power Mode
- Notification was sent too frequently (rate limited)

### 2. Notification Delivery
iOS doesn't guarantee instant delivery. Factors:
- Network connectivity
- Battery level
- App usage patterns
- Time of day

### 3. Background App Refresh
Make sure **Background App Refresh** is enabled:
- iOS Settings → General → Background App Refresh → ON

---

## 📞 What to Report Back

After setup, please verify and report:

1. ✅ Push Notifications capability added in Xcode
2. ✅ APNs certificate uploaded to Firebase
3. ✅ Test alarm successfully fired on real device
4. ✅ TestFlight build successfully shows notifications
5. ⚠️ Any errors or warnings in Xcode during build

---

## 🔗 Useful Links

- [Flutter Local Notifications (iOS)](https://pub.dev/packages/flutter_local_notifications)
- [Apple Push Notifications Guide](https://developer.apple.com/notifications/)
- [Firebase Cloud Messaging iOS Setup](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Background Modes Documentation](https://developer.apple.com/documentation/usernotifications)

---

**Questions? Issues?**
Report any problems via GitHub Issues with:
- Xcode version
- iOS version (device)
- Error messages from Console.app
- Screenshot of Xcode capabilities tab

