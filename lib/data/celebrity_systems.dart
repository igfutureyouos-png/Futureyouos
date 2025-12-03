// 🌟 Celebrity Habit Systems Data
// PROPRIETARY CONTENT REMOVED FOR DEVELOPMENT BUILD
// This is a placeholder - production version contains 40+ licensed celebrity systems

class CelebritySystem {
  final String name;
  final String title;
  final String subtitle;
  final String tier;
  final List<String> habits;
  final String whyViral;
  final String emoji;
  final List<int> gradientColors; // RGB values for gradient

  const CelebritySystem({
    required this.name,
    required this.title,
    required this.subtitle,
    required this.tier,
    required this.habits,
    required this.whyViral,
    required this.emoji,
    required this.gradientColors,
  });
}

// 🔥 PLACEHOLDER SYSTEMS (For testing only)
final List<CelebritySystem> celebritySystems = [
  CelebritySystem(
    name: 'Example Person 1',
    title: 'Test System',
    subtitle: 'PLACEHOLDER FOR TESTING',
    tier: '🔥 EXTREME INTENSITY',
    habits: [
      'Placeholder habit 1',
      'Placeholder habit 2',
      'Placeholder habit 3',
      'Placeholder habit 4',
    ],
    whyViral: 'This is placeholder content for development purposes',
    emoji: '⚔️',
    gradientColors: [239, 68, 68, 185, 28, 28],
  ),
  CelebritySystem(
    name: 'Example Person 2',
    title: 'Demo System',
    subtitle: 'FOR DEVELOPMENT ONLY',
    tier: '🌟 HIGH INTENSITY',
    habits: [
      'Test habit 1',
      'Test habit 2',
      'Test habit 3',
    ],
    whyViral: 'Demo content - not for production',
    emoji: '💪',
    gradientColors: [34, 197, 94, 22, 163, 74],
  ),
];
