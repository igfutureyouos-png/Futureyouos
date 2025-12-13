# ✅ FINAL KEYSTORE CONFIGURATION

## Current Active Keystore

**File**: `android/app/upload-keystore.jks`  
**Alias**: `upload`  
**Password**: `pass123`  
**Created**: Nov 10, 2025  
**Valid Until**: Mar 28, 2053

### SHA Fingerprints

```
SHA-1:   96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C
SHA-256: 9E:B1:F9:8E:64:41:3B:E2:8B:08:B5:A8:35:F2:74:4D:D4:34:C1:D9:A6:2B:40:9C:D5:5F:F1:2A:71:C8:2A:72
```

## ⚠️ IMPORTANT: About SHA-1 04:B3:53:47...

The SHA-1 `04:B3:53:47:BA:7F:C4:65:73:9E:CE:8D:77:36:3C:58` does NOT exist in any keystore file on this system.

**You CANNOT generate a keystore with a specific SHA-1** - it's determined by the cryptographic key itself.

If Google Play Console is expecting that SHA-1, it means either:
1. That SHA-1 was from a different project
2. The original keystore was deleted and is unrecoverable

## ✅ SOLUTION: Register the CORRECT SHA-1

### Step 1: Google Play Console

1. Go to Google Play Console
2. Create/select your app
3. Go to **Release** → **Setup** → **App signing**
4. Register this SHA-1: `96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C`

### Step 2: Firebase Console

1. Go to Firebase Console → Project Settings
2. Select your Android app (or add it if not exists)
3. Add SHA-1 fingerprint: `96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C`
4. Download the updated `google-services.json`
5. Replace `android/app/google-services.json`

### Step 3: Build and Upload

```bash
cd android
./gradlew bundleRelease
```

The APK/Bundle will be signed with the correct keystore.

## Backup Files

- `upload-keystore.jks.backup` - Original backup (Nov 10, identical to active)
- `upload-keystore.jks.nov20` - Nov 20 keystore (different SHA-1, NOT USED)

## Command to Verify Anytime

```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload -storepass pass123 | grep SHA1
```

Expected output:
```
SHA1: 96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C
```

---

**DO NOT generate a new keystore unless you're creating a completely new app!**

