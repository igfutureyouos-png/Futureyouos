# 🦄 Future You OS (Unicorn) - Flutter Edition

A premium Flutter app for self-improvement and habit mastery. This is the complete Flutter rebuild of the React "Future U OS (Unicorn)" with identical design, enhanced functionality, and a fully operational habit scheduler with local alarms and backend sync capabilities.

![Future You OS](https://img.shields.io/badge/Flutter-3.24+-blue?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## ✨ Features

### 🏠 **Home Tab**
- **Horizontal Date Strip**: Navigate through dates with smooth animations
- **Fulfillment Bar**: Visual progress of daily commitments (promises kept vs. made)
- **Drift Meter**: Shows unfulfilled commitments with motivational messaging
- **Habit Cards**: Interactive cards with completion toggles, streaks, and XP tracking
- **Real-time Updates**: Instant local storage updates with backend sync

### 📅 **Planner Tab**
- **Habit/Task Creation**: Toggle between habits and one-time tasks
- **Smart Scheduling**: Time picker with repeat day selection (Sun-Sat)
- **Flexible Frequency**: Daily, weekdays, weekends, or custom patterns
- **Alarm Integration**: Automatic notification scheduling for all habits
- **Form Validation**: Comprehensive input validation with user feedback

### 💬 **Chat Tab (Future You)**
- **AI-Powered Chat**: Conversational interface with Future You mentor
- **Quick Commit Buttons**: Instant habit/task creation from chat suggestions
- **Smart Parsing**: Extracts goals and timeframes from natural language
- **Backend Integration**: Ready for OpenAI API integration via `/chat/send` endpoint

### 🪞 **Mirror Tab (Future Mirror)**
- **Animated Avatar**: Glowing mirror that reflects your "Future Self Index"
- **Dynamic Glow**: Pulsing animation intensity based on fulfillment percentage
- **Streak Stats**: Current and longest streak displays with flame animations
- **Motivational Messages**: Personalized feedback from Future You based on progress

### 🔥 **Streak Tab (Gamified)**
- **Streak Tracking**: Consecutive days of 100% habit completion
- **XP System**: Points earned for habit completion with streak multipliers
- **Achievement Badges**: 7-Day Discipline, 30-Day Legend, 100-Day Master
- **Flame Animations**: Intensity increases with streak length

### ⚙️ **Settings Tab**
- **Account Management**: Display name and email configuration
- **Notification Controls**: Toggle daily briefs and chat mentions
- **Theme Settings**: Dark glass theme with emerald accents
- **Data Management**: Export data (JSON) and reset local storage
- **Sync Controls**: Manual sync with backend and sync status indicators

## 🏗️ Architecture

### **Tech Stack**
- **Framework**: Flutter 3.24+ with Dart 3.0+
- **State Management**: Riverpod for reactive state management
- **Local Storage**: Hive for high-performance local data persistence
- **Notifications**: flutter_local_notifications + android_alarm_manager_plus
- **Backend Sync**: HTTP client with REST API integration
- **Animations**: flutter_animate + custom implicit animations
- **UI Design**: Glassmorphism with neon emerald glow effects

### **Project Structure**
```
lib/
├── main.dart                 # App entry point with service initialization
├── models/
│   ├── habit.dart           # Habit model with Hive annotations
│   └── habit.g.dart         # Generated Hive adapter
├── services/
│   ├── alarm_service.dart   # Notification & alarm scheduling
│   ├── api_client.dart      # Backend API integration
│   └── local_storage.dart   # Hive database operations
├── logic/
│   └── habit_engine.dart    # Business logic & state management
├── screens/
│   ├── main_screen.dart     # Bottom navigation & app shell
│   ├── home_screen.dart     # Daily habit overview
│   ├── planner_screen.dart  # Habit/task creation
│   ├── chat_screen.dart     # Future You chat interface
│   ├── mirror_screen.dart   # Future self reflection
│   └── settings_screen.dart # App configuration
├── widgets/
│   ├── glass_card.dart      # Glassmorphism components
│   ├── habit_card.dart      # Habit display & interaction
│   ├── date_strip.dart      # Horizontal date selector
│   └── streak_badge.dart    # Achievement & streak displays
└── design/
    ├── tokens.dart          # Design system constants
    └── theme.dart           # Flutter theme configuration
```

## 🚀 Getting Started

### **Prerequisites**
- Flutter SDK 3.24.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / VS Code with Flutter extensions
- Android device/emulator (API level 21+) or iOS device/simulator (iOS 12+)

### **Quick Setup**

1. **Clone and setup**
   ```bash
   git clone <repository-url>
   cd futureyouos
   ./setup-dev.sh  # Automated setup script
   ```

2. **Manual setup** (if needed)
   ```bash
   flutter pub get
   dart run build_runner build
   flutter run
   ```

### **Git Workflow**

This project includes a simplified Git workflow:

```bash
# Easy commit and push
./git-workflow.sh "your commit message"

# Or use default message
./git-workflow.sh
```

See [GIT_WORKFLOW.md](GIT_WORKFLOW.md) for detailed instructions.

### **Automated Builds**

- **GitHub Actions** automatically builds APK files on every push
- Download APK files from the Actions tab in GitHub
- No manual build process needed for testing

### **Android Setup**

The app is pre-configured for Android with the following permissions:
- `INTERNET` - Backend sync
- `WAKE_LOCK` - Alarm functionality
- `RECEIVE_BOOT_COMPLETED` - Alarm persistence across reboots
- `VIBRATE` - Notification vibration
- `USE_EXACT_ALARM` - Precise alarm scheduling (Android 12+)
- `SCHEDULE_EXACT_ALARM` - Exact alarm permission
- `POST_NOTIFICATIONS` - Notification display (Android 13+)

### **iOS Setup**

For iOS deployment, add the following to `ios/Runner/Info.plist`:
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>This app needs notifications to remind you about your habits</string>
```

## 🔧 Configuration

### **Backend Integration**

Update the API base URL in `lib/services/api_client.dart`:
```dart
static const String _baseUrl = 'https://your-backend-url.com';
```

### **Notification Customization**

Modify notification settings in `lib/services/alarm_service.dart`:
- Custom notification sounds
- Notification channel configuration
- Motivational quote rotation

### **Design Customization**

Adjust colors and styling in `lib/design/tokens.dart`:
- Brand colors (emerald/cyan gradients)
- Glass effect opacity
- Border radius values
- Typography scale

## 📱 Usage

### **Creating Habits**
1. Navigate to **Planner** tab
2. Toggle between **Habit** (recurring) or **Task** (one-time)
3. Enter title and select time
4. Choose repeat days (habits) or specific date (tasks)
5. Tap **Commit** to save and schedule notifications

### **Tracking Progress**
1. View today's habits on **Home** tab
2. Toggle completion status with animated switches
3. Monitor **Fulfillment** and **Drift** percentages
4. Check streak progress on **Mirror** tab

### **Chat with Future You**
1. Open **Chat** tab
2. Describe your goals in natural language
3. Select from **Quick Commit** suggestions
4. Habits are automatically created and scheduled

### **Managing Settings**
1. Access **Settings** tab
2. Configure notifications and sync preferences
3. Export data or reset local storage
4. Manually trigger backend sync

## 🔄 Data Flow

### **Local-First Architecture**
1. **Create/Update**: Save to Hive → Schedule alarms → Sync to backend
2. **Read**: Load from Hive (instant) → Background sync from backend
3. **Sync**: Queue pending actions → Batch upload when online
4. **Integrity**: Local data is source of truth, backend provides backup/sync

### **Backend API Endpoints**
- `POST /habits` - Create habit
- `PUT /habits/:id` - Update habit  
- `DELETE /habits/:id` - Delete habit
- `POST /habits/log` - Log completion action
- `POST /chat/send` - Send chat message
- `POST /sync/all` - Bulk sync all data

## 🎨 Design System

### **Colors**
- **Base**: Dark gradient (#00140F → #070B12)
- **Primary**: Emerald (#10B981) 
- **Secondary**: Cyan (#06B6D4)
- **Glass**: White with 6% opacity + blur
- **Text**: White with opacity hierarchy (100% → 40%)

### **Components**
- **GlassCard**: Backdrop blur with border glow
- **GlassButton**: Interactive with scale animations
- **GlowingGlassCard**: Animated glow effects
- **HabitCard**: Completion toggle with streak display
- **StreakBadge**: Achievement unlocks with animations

### **Animations**
- **Page Transitions**: Smooth navigation with hero animations
- **Completion**: Scale + glow effects on habit completion
- **Streak Flames**: Intensity increases with streak count
- **Mirror Glow**: Pulsing based on fulfillment percentage

## 🧪 Testing

### **Run Tests**
```bash
flutter test
```

### **Integration Tests**
```bash
flutter drive --target=test_driver/app.dart
```

### **Test Coverage**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 📦 Building

### **Android APK**
```bash
flutter build apk --release
```

### **Android App Bundle**
```bash
flutter build appbundle --release
```

### **iOS**
```bash
flutter build ios --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original React version design and concept
- Flutter community for excellent packages
- Glassmorphism design trend inspiration
- Habit formation research and gamification principles

## 📞 Support

For support, email support@futureyouos.com or create an issue in this repository.

---

**Built with ❤️ using Flutter** | **Future You OS v1.0.0**