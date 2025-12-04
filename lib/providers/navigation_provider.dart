import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for managing tab navigation in MainScreen
class NavigationNotifier extends StateNotifier<int> {
  NavigationNotifier() : super(0); // Start with Today tab (index 0)

  /// Navigate to a specific tab
  void navigateToTab(int index) {
    if (index >= 0 && index <= 3) { // Ensure valid tab index
      state = index;
    }
  }

  /// Navigate to Today tab (index 0)
  void navigateToToday() => navigateToTab(0);

  /// Navigate to Planner tab (index 1)
  void navigateToPlanner() => navigateToTab(1);

  /// Navigate to OS Chat tab (index 2)
  void navigateToOSChat() => navigateToTab(2);

  /// Navigate to Habit Master tab (index 3)
  void navigateToHabitMaster() => navigateToTab(3);
}

/// Global provider for tab navigation
final navigationProvider = StateNotifierProvider<NavigationNotifier, int>((ref) {
  return NavigationNotifier();
});
