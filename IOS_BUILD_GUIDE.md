# 🍎 iOS Build Guide for Future You OS

## 📋 Complete Checklist for Codemagic Build

### ✅ Step 1: Get GoogleService-Info.plist

**CRITICAL: Your app will NOT work without this!**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your "Future You" project
3. Click ⚙️ Settings → Project Settings
4. Under "Your apps", find or add iOS app
5. **Bundle ID MUST be:** `com.futureyou.os`
6. Download `GoogleService-Info.plist`
7. Save it to: `ios/Runner/GoogleService-Info.plist`
8. Commit and push to your repo

```bash
git add ios/Runner/GoogleService-Info.plist
git commit -m "Add Firebase iOS configuration"
git push origin main
```

---

### ✅ Step 2: Apple Developer Account Setup

You need an **Apple Developer Account** ($99/year)

1. Go to: https://developer.apple.com/
2. Enroll in Apple Developer Program
3. Create App ID:
   - Go to Certificates, Identifiers & Profiles
   - Click Identifiers → +
   - Bundle ID: `com.futureyou.os`
   - Name: `Future You OS`
   - Enable capabilities: Push Notifications, Sign in with Apple

---

### ✅ Step 3: App Store Connect Setup

1. Go to: https://appstoreconnect.apple.com/
2. Click "My Apps" → + → New App
3. Fill in:
   - **Name:** Future You OS
   - **Bundle ID:** com.futureyou.os
   - **SKU:** FUTUREYOUOS (or any unique identifier)
4. Create app

---

### ✅ Step 4: Codemagic Setup

#### A. Sign up & Connect GitHub

1. Go to: https://codemagic.io/
2. Sign up (free tier is fine to start)
3. Click "Add application"
4. Select GitHub
5. Authorize Codemagic to access your repos
6. Select: `seekumimi-dotcom/Futureyou-`

#### B. Configure iOS Code Signing

**In Codemagic:**

1. Go to your app → Settings → Code signing
2. Under "iOS code signing", click "Set up code signing"
3. Choose one of these methods:

**Method 1: Automatic (Easiest)**
- Click "Enable automatic code signing"
- Connect your Apple Developer account
- Codemagic will handle everything

**Method 2: Manual**
- Upload your provisioning profiles
- Upload your signing certificates
- Configure in the YAML

#### C. Set Environment Variables

In Codemagic → Your App → Settings → Environment variables:

Add these if publishing to App Store:
- `APP_STORE_CONNECT_ISSUER_ID` (from App Store Connect → Users & Access → Keys)
- `APP_STORE_CONNECT_KEY_IDENTIFIER` (from App Store Connect)
- `APP_STORE_CONNECT_PRIVATE_KEY` (download .p8 file, paste contents)

---

### ✅ Step 5: Build Configuration

The `codemagic.yaml` file is already set up in your repo!

**What it does:**
- ✅ Installs Flutter dependencies
- ✅ Installs CocoaPods
- ✅ Builds iOS IPA file
- ✅ Sends you email when build completes
- ✅ Can auto-publish to TestFlight (when configured)

**Update this in codemagic.yaml:**
```yaml
email:
  recipients:
    - your-email@example.com  # CHANGE to your actual email!
```

---

### ✅ Step 6: Trigger Your First Build

1. Go to Codemagic → Your App
2. Click "Start new build"
3. Select branch: `main`
4. Select workflow: `ios-workflow`
5. Click "Start new build"
6. Wait 10-15 minutes ⏰
7. Download IPA from Artifacts!

---

## 🚀 Quick Command Reference

### Push changes to trigger build
```bash
git add .
git commit -m "Update for iOS build"
git push origin main
```

### Manual build on Mac (if you have one)
```bash
# Get dependencies
flutter pub get
cd ios && pod install && cd ..

# Build IPA
flutter build ipa --release

# IPA will be at:
# build/ios/ipa/*.ipa
```

---

## 📦 What You'll Get

After successful build:
- **IPA file** (iOS App file)
- **Build logs** (if something fails)

You can:
1. **Install on test devices** (via TestFlight or direct install)
2. **Submit to App Store** (when ready)
3. **Share with beta testers**

---

## 🐛 Common Issues & Fixes

### Issue 1: "GoogleService-Info.plist not found"
**Fix:** Add the file to `ios/Runner/GoogleService-Info.plist` and push to repo

### Issue 2: "Code signing failed"
**Fix:** Make sure you've set up code signing in Codemagic settings

### Issue 3: "Pod install failed"
**Fix:** Usually auto-fixed. If not, delete `ios/Podfile.lock` and try again

### Issue 4: "Bundle identifier mismatch"
**Fix:** Make sure all these match:
- `ios/Runner.xcodeproj/project.pbxproj` (bundle ID)
- Firebase iOS app bundle ID
- Apple Developer app ID

---

## 📱 Testing Your IPA

### Option 1: TestFlight (Recommended)
1. Upload IPA to App Store Connect
2. Add beta testers
3. They install via TestFlight app

### Option 2: Direct Install
1. Use tools like Diawi.com
2. Upload IPA
3. Share link to testers
4. They install directly (requires device UUID to be registered)

---

## 💰 Costs

- **Apple Developer Account:** $99/year (REQUIRED)
- **Codemagic Free Tier:** 500 build minutes/month (plenty to start)
- **Codemagic Pro:** $40+/month (only if you need more)

---

## 🎯 Next Steps After First Build

1. ✅ Get IPA file
2. ✅ Test on real iPhone (via TestFlight)
3. ✅ Fix any bugs
4. ✅ Add app screenshots
5. ✅ Submit to App Store for review
6. ✅ 🎉 Celebrate when approved!

---

## 📞 Need Help?

- **Codemagic Docs:** https://docs.codemagic.io/
- **Flutter iOS Deploy:** https://docs.flutter.dev/deployment/ios
- **App Store Connect:** https://help.apple.com/app-store-connect/

---

Good luck! 🚀

