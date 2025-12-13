# 🔑 ALL KEYSTORE SHA FINGERPRINTS

## ✅ CURRENT ACTIVE KEYSTORE (Nov 20, 2025)

**File**: `android/app/upload-keystore.jks`  
**Created**: Nov 20, 2025  
**Alias**: upload  
**Password**: pass123

**SHA-1**: `75:EF:24:76:E2:D7:D7:68:E2:FA:3A:49:66:0C:69:15:6F:3E:BA:BF`

**SHA-256**: `B7:4E:80:91:68:E7:AD:22:FE:0C:EC:33:1B:62:E6:85:86:FE:A2:23:F1:6D:D5:7C:D1:C1:67:27:57:DC:6C:60`

---

## 📦 BACKUP KEYSTORES

### Nov 10, 2025 Keystore

**Files**: 
- `android/app/upload-keystore.jks.backup`
- `android/app/upload-keystore.jks.nov10-backup`

**Created**: Nov 10, 2025  
**Alias**: upload  
**Password**: pass123

**SHA-1**: `96:B9:63:91:BC:B9:73:0E:B9:2D:B7:EA:81:5E:95:C6:FA:71:11:8C`

**SHA-256**: `9E:B1:F9:8E:64:41:3B:E2:8B:08:B5:A8:35:F2:74:4D:D4:34:C1:D9:A6:2B:40:9C:D5:5F:F1:2A:71:C8:2A:72`

---

## 🚨 GOOGLE PLAY CONSOLE EXPECTS

**SHA-1**: `04:B3:53:47:BA:7F:C4:65:73:9E:CE:8D:77:36:3C:58`

**⚠️ THIS KEYSTORE DOES NOT EXIST ON THIS SYSTEM!**

This is why uploads are failing. You need to either:
1. **Reset the upload key** in Google Play Console (takes 2-3 days)
2. **Delete app and create new** (instant, recommended)

---

## 📋 SUMMARY

You have **TWO** keystores on this system:

| Keystore | Created | SHA-1 Starts With | Status |
|----------|---------|-------------------|--------|
| Nov 20, 2025 | Nov 20 | `75:EF...` | ✅ **ACTIVE** |
| Nov 10, 2025 | Nov 10 | `96:B9...` | Backup |

**Google expects**: `04:B3...` ❌ **DOESN'T EXIST**

---

## ✅ RECOMMENDATION

**Use the ACTIVE keystore** (SHA-1: `75:EF...`)

**Steps**:
1. Delete current app in Google Play Console
2. Create new app entry
3. Upload AAB signed with current keystore
4. Google will lock in SHA-1: `75:EF...`
5. Done!

---

## 🔧 VERIFY COMMAND

```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload -storepass pass123 | grep SHA1
```

Should show:
```
SHA1: 75:EF:24:76:E2:D7:D7:68:E2:FA:3A:49:66:0C:69:15:6F:3E:BA:BF
```

