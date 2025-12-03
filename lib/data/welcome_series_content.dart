// 🌑 7-Day Welcome Series Content
// PROPRIETARY CONTENT REMOVED FOR DEVELOPMENT BUILD

class WelcomeDay {
  final int day;
  final String title;
  final String body;
  final String? audioUrl;

  const WelcomeDay({
    required this.day,
    required this.title,
    required this.body,
    this.audioUrl,
  });
}

final List<WelcomeDay> welcomeSeries = [
  WelcomeDay(
    day: 1,
    title: 'Day 1: Welcome',
    body: 'Placeholder content for development build. Production version contains curated 7-day welcome series.',
  ),
  WelcomeDay(
    day: 2,
    title: 'Day 2: Getting Started',
    body: 'This is a placeholder. Real content is proprietary.',
  ),
];
