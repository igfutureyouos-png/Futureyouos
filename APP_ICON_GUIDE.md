# 📱 App Icon Installation Guide

## 🎨 Where to Put Your App Icon Images

### For Android:

Place your icon files in these directories with these exact names:

```
android/app/src/main/res/mipmap-mdpi/ic_launcher.png       (48x48 px)
android/app/src/main/res/mipmap-hdpi/ic_launcher.png       (72x72 px)
android/app/src/main/res/mipmap-xhdpi/ic_launcher.png      (96x96 px)
android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png     (144x144 px)
android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png    (192x192 px)
```

**Recommended Sizes:**
- **mdpi**: 48x48 pixels
- **hdpi**: 72x72 pixels  
- **xhdpi**: 96x96 pixels
- **xxhdpi**: 144x144 pixels
- **xxxhdpi**: 192x192 pixels

### For iOS:

Place your icon in: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

**Required iOS sizes (all named Icon-App-SIZEXSIZE.png):**
- Icon-App-20x20@1x.png (20x20)
- Icon-App-20x20@2x.png (40x40)
- Icon-App-20x20@3x.png (60x60)
- Icon-App-29x29@1x.png (29x29)
- Icon-App-29x29@2x.png (58x58)
- Icon-App-29x29@3x.png (87x87)
- Icon-App-40x40@1x.png (40x40)
- Icon-App-40x40@2x.png (80x80)
- Icon-App-40x40@3x.png (120x120)
- Icon-App-60x60@2x.png (120x120)
- Icon-App-60x60@3x.png (180x180)
- Icon-App-76x76@1x.png (76x76)
- Icon-App-76x76@2x.png (152x152)
- Icon-App-83.5x83.5@2x.png (167x167)
- Icon-App-1024x1024@1x.png (1024x1024)

---

## 🚀 Easy Method: Use a Tool

**Option 1: Use an online generator**
1. Go to https://easyappicon.com/ or https://appicon.co/
2. Upload one high-res image (1024x1024 PNG recommended)
3. Download the generated package
4. Copy all files to the directories above

**Option 2: Use flutter_launcher_icons package (RECOMMENDED)**

1. Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"  # Your 1024x1024 icon
  adaptive_icon_background: "#000000"     # Background color
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"  # Foreground layer
```

2. Put your 1024x1024 icon at: `assets/icon/app_icon.png`

3. Run: `flutter pub run flutter_launcher_icons`

This will automatically generate ALL sizes for both platforms! ✨

---

## 📋 Current App Info

**App Name:** Future You OS  
**Package Name:** com.futureyouos.app (check `android/app/build.gradle`)  
**Bundle ID:** com.futureyouos.app (check `ios/Runner/Info.plist`)

---

## 🎨 Icon Design Tips

For **Future-You OS**, consider:
- 🧠 Brain icon with emerald/cyan gradient
- ⚡ Lightning bolt symbolizing transformation
- 🔮 Crystal/gem representing future self
- 🎯 Target with gradient rings
- 📈 Upward arrow with glow

**Design specs:**
- Size: 1024x1024 pixels minimum
- Format: PNG with transparency
- Safe zone: Keep important content within 80% center
- Colors: Match your emerald (#10B981) + cyan (#06B6D4) gradient
- Style: Modern, bold, recognizable at small sizes

---

## ✅ After Adding Icons

Run these commands to see your new icon:
```bash
# Clean build
flutter clean

# Run on device
flutter run --release
```

Your icon should now appear on the home screen! 🎉

