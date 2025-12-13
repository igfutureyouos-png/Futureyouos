# Keystore SHA-1 Mismatch Fix

## Current Situation

- **Current Keystore SHA-1**: `96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C`
- **Google Play Expected SHA-1**: `04:B3:53:47:BA:7F:C4:65:73:9E:CE:8D:77:36:3C:58`

## Understanding the Issue

SHA-1 fingerprints are cryptographic hashes derived from the keystore's private key. You **cannot** generate a keystore with a specific SHA-1 - the SHA-1 is determined by the key itself.

## Solutions

### Solution 1: Update Google Play Console (RECOMMENDED)

If this is a NEW app or you control the keystore:

1. Go to Google Play Console
2. Navigate to your app → Release → Setup → App Integrity
3. Under "App signing by Google Play", find "Upload certificate"
4. **Upload the current keystore SHA-1**: `96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C`
5. Also update Firebase Console with this SHA-1

### Solution 2: Get the Correct Keystore from Google Play

If the app is already published with a different keystore:

1. Go to Google Play Console → Release → Setup → App Integrity
2. Download the "App signing key certificate" (if available)
3. Convert it to JKS format
4. Replace `android/app/upload-keystore.jks` with the correct file

### Solution 3: Create a New App Release

If you've lost the original keystore:

1. This requires creating a new app listing in Google Play
2. You cannot update the existing app without the original keystore

## Firebase Configuration

Don't forget to update Firebase:

1. Go to Firebase Console → Project Settings → General
2. Under "Your apps", select your Android app
3. Add the SHA-1 fingerprint: `96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C`

## Current Keystore Details

```
Alias: upload
Password: pass123
Path: android/app/upload-keystore.jks
SHA-1: 96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C
Created: Nov 10, 2025
Valid until: Mar 28, 2053
```

## Questions to Answer

1. **Is this a new app or existing app?**
   - If new: Use Solution 1
   - If existing: Use Solution 2

2. **Do you have access to the original keystore that was used?**
   - If yes: Replace the current upload-keystore.jks
   - If no: You'll need to create a new app listing

3. **Is Google Play App Signing enabled?**
   - If yes: Google manages the signing key, you just need the upload key
   - If no: You need the exact keystore used for signing

## Next Steps

Please clarify:
- Where did the SHA-1 `04:B3:53:47:BA:7F:C4:65:73:9E:CE:8D:77:36:3C:58` come from?
- Is this an existing app on Google Play or a new one?
- Do you have the original keystore file that matches that SHA-1?

