# 🎬 COMPLETE CURSOR COMMAND — CINEMATIC UI (CORRECT FLOW)

## Build the REAL cinematic experience:
**Intro → AI Chat → Custom Chapter → Next Phase**

---

## FILE STRUCTURE TO CREATE:

```
lib/cinematic/
  cinematic_entry.dart          // Entry widget
  cinematic_screen.dart         // PageView of 7 phases
  cinematic_phase_scene.dart    // Handles: intro → chat → chapter
  cinematic_intro.dart          // Typing animation + TTS for phase intro
  cinematic_chat.dart           // AI conversation interface
  chapter_display.dart          // Shows generated chapter with typing
  cinematic_particles.dart      // Background particles
  audio_controller.dart         // Music + TTS management
  phase_model.dart              // Phase enum + metadata
```

---

## UPDATE pubspec.yaml (ADD-ONLY):

```yaml
dependencies:
  flutter_animate: ^4.5.0
  just_audio: ^0.9.38
  audio_session: ^0.1.18
  flutter_tts: ^3.8.3
  lottie: ^3.1.2
  share_plus: ^10.0.2
  shared_preferences: ^2.2.2

flutter:
  assets:
    - assets/cinema/music/
    - assets/cinema/anims/
```

Create placeholder MP3 files in `assets/cinema/music/`:
- hope.mp3
- conflict.mp3
- promise.mp3

Create placeholder Lottie JSON in `assets/cinema/anims/`:
- particles.json

---

## IMPLEMENT phase_model.dart:

```dart
enum FuturePhase {
  call,
  conflict,
  mirror,
  mentor,
  task,
  path,
  promise
}

extension FuturePhaseX on FuturePhase {
  String get apiName => {
    FuturePhase.call: 'call',
    FuturePhase.conflict: 'conflict',
    FuturePhase.mirror: 'mirror',
    FuturePhase.mentor: 'mentor',
    FuturePhase.task: 'task',
    FuturePhase.path: 'path',
    FuturePhase.promise: 'promise',
  }[this]!;

  String get title => {
    FuturePhase.call: 'Chapter I — The Call',
    FuturePhase.conflict: 'Chapter II — The Conflict',
    FuturePhase.mirror: 'Chapter III — The Mirror',
    FuturePhase.mentor: 'Chapter IV — The Mentor',
    FuturePhase.task: 'Chapter V — The Task',
    FuturePhase.path: 'Chapter VI — The Path',
    FuturePhase.promise: 'Chapter VII — The Promise',
  }[this]!;

  String get introText => {
    FuturePhase.call: 'The world is still.\nIt is the kind of stillness that feels like the moment before a truth arrives.\nSomething inside you is awake before you are, a small pull you cannot name yet.\n\nThis is the beginning of the search for your life\'s task.',
    FuturePhase.conflict: 'There is a truth you rarely say out loud.\nThe truth that you have been living beneath yourself.\n\nThis chapter exists to bring truth to the surface.\nTruth often feels like discomfort first.\nDiscomfort is the doorway to direction.',
    FuturePhase.mirror: 'You stand before a surface that shows you more than your face.\nIt shows patterns. It shows habits. It shows the stories you tell yourself when no one is listening.\n\nThe mirror waits for your honesty.\nThis is the moment you meet yourself without the armour.',
    FuturePhase.mentor: 'A voice arrives, but it feels like it is coming from inside your chest rather than the air.\nIt is older. It is you, years ahead. Not the broken version. The fulfilled one.\n\nThe mentor does not give you the answer.\nThe mentor makes you remember that you already had it.',
    FuturePhase.task: 'A sentence forms like a key turning in a lock.\n\nYour life\'s task is the intersection of three truths:\n1. What you cannot stop thinking about\n2. What you do better than most without forcing it\n3. What the world becomes better the moment you touch it\n\nYou have known this for a long time.\nThis chapter gives you permission to admit it.',
    FuturePhase.path: 'Purpose means nothing without direction.\nDirection means nothing without discipline.\nDiscipline means nothing without identity.\n\nThe path is where you turn understanding into movement.\n\nConsistency is the currency that buys the life you want.',
    FuturePhase.promise: 'A final truth rises slowly, like light returning after darkness.\n\nYour future self speaks again, quieter now.\n\n"We kept the promise. Not in one grand moment. In small, relentless decisions."\n\nThis is the beginning. Not the end.',
  }[this]!;

  String get musicAsset => {
    FuturePhase.call: 'assets/cinema/music/hope.mp3',
    FuturePhase.conflict: 'assets/cinema/music/conflict.mp3',
    FuturePhase.mirror: 'assets/cinema/music/hope.mp3',
    FuturePhase.mentor: 'assets/cinema/music/hope.mp3',
    FuturePhase.task: 'assets/cinema/music/hope.mp3',
    FuturePhase.path: 'assets/cinema/music/hope.mp3',
    FuturePhase.promise: 'assets/cinema/music/promise.mp3',
  }[this]!;

  Color get gradientStart => {
    FuturePhase.call: const Color(0xFF0ea5e9),
    FuturePhase.conflict: const Color(0xFF0f172a),
    FuturePhase.mirror: const Color(0xFF1e293b),
    FuturePhase.mentor: const Color(0xFF7c3aed),
    FuturePhase.task: const Color(0xFFd97706),
    FuturePhase.path: const Color(0xFF059669),
    FuturePhase.promise: const Color(0xFFD4AF37),
  }[this]!;

  Color get gradientEnd => {
    FuturePhase.call: const Color(0xFF22d3ee),
    FuturePhase.conflict: const Color(0xFF1f2937),
    FuturePhase.mirror: const Color(0xFF334155),
    FuturePhase.mentor: const Color(0xFFa855f7),
    FuturePhase.task: const Color(0xFFf59e0b),
    FuturePhase.path: const Color(0xFF10b981),
    FuturePhase.promise: const Color(0xFFFFC857),
  }[this]!;
}
```

---

## IMPLEMENT cinematic_phase_scene.dart:

**This is the CORE widget that handles the 3-step flow:**

```dart
import 'package:flutter/material.dart';
import 'cinematic_intro.dart';
import 'cinematic_chat.dart';
import 'chapter_display.dart';
import 'cinematic_particles.dart';
import 'audio_controller.dart';
import 'phase_model.dart';
import '../services/api_client.dart';

enum PhaseState { intro, chat, chapter, complete }

class CinematicPhaseScene extends StatefulWidget {
  final FuturePhase phase;
  final AudioController audioController;
  final VoidCallback onComplete;

  const CinematicPhaseScene({
    super.key,
    required this.phase,
    required this.audioController,
    required this.onComplete,
  });

  @override
  State<CinematicPhaseScene> createState() => _CinematicPhaseSceneState();
}

class _CinematicPhaseSceneState extends State<CinematicPhaseScene> {
  PhaseState _state = PhaseState.intro;
  List<Map<String, String>> _conversation = [];
  Map<String, dynamic>? _generatedChapter;

  @override
  void initState() {
    super.initState();
    widget.audioController.playMusic(widget.phase.musicAsset);
  }

  void _onIntroComplete() {
    setState(() {
      _state = PhaseState.chat;
    });
  }

  Future<void> _onChatComplete(List<Map<String, String>> conversation) async {
    setState(() {
      _conversation = conversation;
      _state = PhaseState.chapter;
    });

    // Generate chapter from conversation
    try {
      final response = await ApiClient.generateChapter(
        phase: widget.phase.apiName,
        title: widget.phase.title,
        body: _buildTranscript(conversation),
      );

      if (response.success && response.data != null) {
        setState(() {
          _generatedChapter = response.data!['chapter'];
        });
      }
    } catch (e) {
      debugPrint('❌ Chapter generation failed: $e');
      // Fallback to mock
      setState(() {
        _generatedChapter = {
          'title': widget.phase.title,
          'bodyMd': 'Your personal chapter will appear here...',
          'words': 0,
        };
      });
    }
  }

  String _buildTranscript(List<Map<String, String>> convo) {
    return convo
        .map((msg) => '${msg['role']}: ${msg['text']}')
        .join('\n\n');
  }

  void _onChapterComplete() {
    setState(() {
      _state = PhaseState.complete;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.phase.gradientStart.withOpacity(0.3),
                  widget.phase.gradientEnd.withOpacity(0.3),
                  Colors.black,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Particles
          const CinematicParticles(),

          // Content based on state
          SafeArea(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case PhaseState.intro:
        return CinematicIntro(
          phase: widget.phase,
          audioController: widget.audioController,
          onComplete: _onIntroComplete,
        );

      case PhaseState.chat:
        return CinematicChat(
          phase: widget.phase,
          onComplete: _onChatComplete,
        );

      case PhaseState.chapter:
        if (_generatedChapter == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Generating your chapter...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ChapterDisplay(
          chapter: _generatedChapter!,
          audioController: widget.audioController,
          onComplete: _onChapterComplete,
        );

      case PhaseState.complete:
        return Center(
          child: ElevatedButton(
            onPressed: widget.onComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.phase.gradientEnd,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Next Chapter →',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        );
    }
  }
}
```

---

## IMPLEMENT cinematic_intro.dart:

**Typing animation + TTS for phase intro:**

```dart
import 'package:flutter/material.dart';
import 'phase_model.dart';
import 'audio_controller.dart';

class CinematicIntro extends StatefulWidget {
  final FuturePhase phase;
  final AudioController audioController;
  final VoidCallback onComplete;

  const CinematicIntro({
    super.key,
    required this.phase,
    required this.audioController,
    required this.onComplete,
  });

  @override
  State<CinematicIntro> createState() => _CinematicIntroState();
}

class _CinematicIntroState extends State<CinematicIntro> {
  int _visibleChars = 0;
  bool _done = false;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
    _startTTS();
  }

  void _startTyping() async {
    final text = widget.phase.introText;
    final chars = text.length;
    
    for (int i = 0; i <= chars; i++) {
      if (_skipped) break;
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) {
        setState(() {
          _visibleChars = i;
        });
      }
    }

    setState(() {
      _done = true;
    });
  }

  void _startTTS() {
    widget.audioController.speak(widget.phase.introText);
  }

  void _skip() {
    setState(() {
      _skipped = true;
      _visibleChars = widget.phase.introText.length;
      _done = true;
    });
    widget.audioController.stopTTS();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _done ? null : _skip,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.phase.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 32),

            // Intro text
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.phase.introText.substring(0, _visibleChars),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.8,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),

            // Continue button
            if (_done)
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                  child: const Text(
                    'Continue →',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## IMPLEMENT cinematic_chat.dart:

**AI conversation interface:**

```dart
import 'package:flutter/material.dart';
import 'phase_model.dart';
import '../services/api_client.dart';

class CinematicChat extends StatefulWidget {
  final FuturePhase phase;
  final Function(List<Map<String, String>>) onComplete;

  const CinematicChat({
    super.key,
    required this.phase,
    required this.onComplete,
  });

  @override
  State<CinematicChat> createState() => _CinematicChatState();
}

class _CinematicChatState extends State<CinematicChat> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  Future<void> _startConversation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.enginePhaseStart(
        phase: widget.phase.apiName,
      );

      if (response.success && response.data != null) {
        final coachMsg = response.data!['coach'] as String?;
        if (coachMsg != null) {
          setState(() {
            _messages.add({'role': 'coach', 'text': coachMsg});
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Phase start failed: $e');
      // Fallback
      setState(() {
        _messages.add({
          'role': 'coach',
          'text': 'Tell me about your experience with ${widget.phase.title.toLowerCase()}.'
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });

    _controller.clear();

    try {
      final response = await ApiClient.enginePhaseStart(
        phase: widget.phase.apiName,
        scenes: _messages,
      );

      if (response.success && response.data != null) {
        final coachMsg = response.data!['coach'] as String?;
        final shouldGenerate = response.data!['shouldGenerateChapter'] as bool? ?? false;

        if (coachMsg != null) {
          setState(() {
            _messages.add({'role': 'coach', 'text': coachMsg});
          });
        }

        if (shouldGenerate) {
          // Phase complete!
          widget.onComplete(_messages);
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ Message send failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isCoach = msg['role'] == 'coach';
              return Align(
                alignment: isCoach ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isCoach
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    msg['text']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Input
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: Colors.white),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _sendMessage(_controller.text),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## IMPLEMENT chapter_display.dart:

**Shows generated chapter with typing effect:**

```dart
import 'package:flutter/material.dart';
import 'audio_controller.dart';

class ChapterDisplay extends StatefulWidget {
  final Map<String, dynamic> chapter;
  final AudioController audioController;
  final VoidCallback onComplete;

  const ChapterDisplay({
    super.key,
    required this.chapter,
    required this.audioController,
    required this.onComplete,
  });

  @override
  State<ChapterDisplay> createState() => _ChapterDisplayState();
}

class _ChapterDisplayState extends State<ChapterDisplay> {
  int _visibleChars = 0;
  bool _done = false;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
    _startTTS();
  }

  void _startTyping() async {
    final text = widget.chapter['bodyMd'] as String;
    final chars = text.length;

    for (int i = 0; i <= chars; i++) {
      if (_skipped) break;
      await Future.delayed(const Duration(milliseconds: 20));
      if (mounted) {
        setState(() {
          _visibleChars = i;
        });
      }
    }

    setState(() {
      _done = true;
    });
  }

  void _startTTS() {
    widget.audioController.speak(widget.chapter['bodyMd'] as String);
  }

  void _skip() {
    setState(() {
      _skipped = true;
      _visibleChars = (widget.chapter['bodyMd'] as String).length;
      _done = true;
    });
    widget.audioController.stopTTS();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.chapter['bodyMd'] as String;

    return GestureDetector(
      onTap: _done ? null : _skip,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.chapter['title'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 32),

            // Chapter text
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  text.substring(0, _visibleChars),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.8,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),

            // Complete button
            if (_done)
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                  child: const Text(
                    'Complete Chapter ✓',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## IMPLEMENT cinematic_screen.dart:

**Main screen with PageView:**

```dart
import 'package:flutter/material.dart';
import 'cinematic_phase_scene.dart';
import 'cinematic_book.dart';
import 'audio_controller.dart';
import 'phase_model.dart';

class CinematicScreen extends StatefulWidget {
  const CinematicScreen({super.key});

  @override
  State<CinematicScreen> createState() => _CinematicScreenState();
}

class _CinematicScreenState extends State<CinematicScreen> {
  late final AudioController _audioController;
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _audioController = AudioController();
    _audioController.init();
    _pageController = PageController();
  }

  void _nextPhase() {
    if (_currentIndex < FuturePhase.values.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentIndex++;
      });
    } else {
      // All phases complete → show book
      _showBook();
    }
  }

  Future<void> _showBook() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CinematicBook(audioController: _audioController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: FuturePhase.values.length,
      itemBuilder: (context, index) {
        return CinematicPhaseScene(
          phase: FuturePhase.values[index],
          audioController: _audioController,
          onComplete: _nextPhase,
        );
      },
    );
  }

  @override
  void dispose() {
    _audioController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
```

---

## IMPLEMENT cinematic_book.dart:

**Book compilation and display:**

```dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'audio_controller.dart';
import 'package:share_plus/share_plus.dart';

class CinematicBook extends StatefulWidget {
  final AudioController audioController;

  const CinematicBook({super.key, required this.audioController});

  @override
  State<CinematicBook> createState() => _CinematicBookState();
}

class _CinematicBookState extends State<CinematicBook> {
  bool _loading = true;
  String _bookContent = '';

  @override
  void initState() {
    super.initState();
    _compileBook();
  }

  Future<void> _compileBook() async {
    try {
      // Request compilation
      await ApiClient.compileBook();

      // Fetch latest book
      final response = await ApiClient.getLatestBook();

      if (response.success && response.data != null) {
        setState(() {
          _bookContent = response.data!['bodyMd'] as String;
          _loading = false;
        });
      } else {
        throw Exception('Failed to fetch book');
      }
    } catch (e) {
      debugPrint('❌ Book compilation failed: $e');
      setState(() {
        _bookContent = 'Your personal book will appear here...';
        _loading = false;
      });
    }
  }

  void _shareBook() {
    Share.share(_bookContent, subject: 'My Book of Purpose');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'The Book of Purpose',
          style: TextStyle(
            color: Colors.black87,
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _shareBook,
            icon: const Icon(Icons.share, color: Colors.black87),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Text(
                _bookContent,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.8,
                  color: Colors.black87,
                  fontFamily: 'serif',
                ),
              ),
            ),
    );
  }
}
```

---

## IMPLEMENT audio_controller.dart:

```dart
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioController {
  final _musicPlayer = AudioPlayer();
  final _tts = FlutterTts();
  double _baseVolume = 0.6;
  double _duckVolume = 0.2;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> playMusic(String asset) async {
    try {
      await _musicPlayer.setAsset(asset);
      await _musicPlayer.setVolume(_baseVolume);
      await _musicPlayer.setLoopMode(LoopMode.one);
      _musicPlayer.play();
    } catch (e) {
      // Silent fail for missing assets
    }
  }

  Future<void> speak(String text) async {
    try {
      // Duck music
      await _musicPlayer.setVolume(_duckVolume);

      // Speak
      await _tts.speak(text);

      // Wait for completion
      await Future.delayed(Duration(seconds: text.length ~/ 20));

      // Restore music
      await _musicPlayer.setVolume(_baseVolume);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> stopTTS() async {
    await _tts.stop();
    await _musicPlayer.setVolume(_baseVolume);
  }

  Future<void> dispose() async {
    await _musicPlayer.dispose();
  }
}
```

---

## IMPLEMENT cinematic_particles.dart:

```dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CinematicParticles extends StatelessWidget {
  const CinematicParticles({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.3,
        child: Lottie.asset(
          'assets/cinema/anims/particles.json',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
```

---

## IMPLEMENT cinematic_entry.dart:

```dart
import 'package:flutter/material.dart';
import 'cinematic_screen.dart';

class CinematicEntry extends StatelessWidget {
  const CinematicEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return const CinematicScreen();
  }
}
```

---

## UPDATE lib/main.dart (ADD ROUTE ONLY):

```dart
routes: {
  '/settings': (context) => const SettingsScreen(),
  '/cinematic': (context) => const CinematicEntry(), // ADD THIS
},
```

---

## THAT'S IT.

This is the REAL cinematic experience:
✅ Beautiful intro for each phase
✅ AI conversation that digs deep
✅ Custom chapter generation about THE USER
✅ All 7 phases
✅ Compiled book at the end
✅ Full backend integration
✅ Offline fallbacks

Build it exactly like this.

