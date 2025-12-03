import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔊 TTS PLAYBACK SERVICE
/// Handles text-to-speech audio playback with auto-play tracking
class TTSPlaybackService {
  static final AudioPlayer _player = AudioPlayer();
  static String? _currentlyPlaying;
  static bool _isPlaying = false;

  /// Play audio from URL
  static Future<void> playAudio(String audioUrl) async {
    try {
      debugPrint('🔊 Playing audio: $audioUrl');
      
      // Stop any currently playing audio
      await stopAudio();
      
      _currentlyPlaying = audioUrl;
      _isPlaying = true;

      // Load and play
      await _player.setUrl(audioUrl);
      await _player.play();

      // Listen for completion
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _currentlyPlaying = null;
          debugPrint('✅ Audio playback completed');
        }
      });

    } catch (e) {
      debugPrint('❌ Failed to play audio: $e');
      _isPlaying = false;
      _currentlyPlaying = null;
    }
  }

  /// Stop currently playing audio
  static Future<void> stopAudio() async {
    try {
      if (_isPlaying) {
        await _player.stop();
        _isPlaying = false;
        _currentlyPlaying = null;
        debugPrint('⏹️ Audio stopped');
      }
    } catch (e) {
      debugPrint('❌ Failed to stop audio: $e');
    }
  }

  /// Check if audio is currently playing
  static bool isPlaying() => _isPlaying;

  /// Get currently playing audio URL
  static String? getCurrentlyPlaying() => _currentlyPlaying;

  // ═══════════════════════════════════════════════════════
  // AUTO-PLAY TRACKING (Local Storage)
  // ═══════════════════════════════════════════════════════

  static const String _autoPlayedKey = 'tts_auto_played_messages';

  /// Mark a message as auto-played
  static Future<void> markAsAutoPlayed(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoPlayed = prefs.getStringList(_autoPlayedKey) ?? [];
      
      if (!autoPlayed.contains(messageId)) {
        autoPlayed.add(messageId);
        await prefs.setStringList(_autoPlayedKey, autoPlayed);
        debugPrint('✅ Marked as auto-played: $messageId');
      }
    } catch (e) {
      debugPrint('❌ Failed to mark as auto-played: $e');
    }
  }

  /// Check if a message has been auto-played
  static Future<bool> hasAutoPlayed(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoPlayed = prefs.getStringList(_autoPlayedKey) ?? [];
      return autoPlayed.contains(messageId);
    } catch (e) {
      debugPrint('❌ Failed to check auto-played status: $e');
      return false;
    }
  }

  /// Clear auto-played history (for testing or reset)
  static Future<void> clearAutoPlayedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_autoPlayedKey);
      debugPrint('🗑️ Cleared auto-played history');
    } catch (e) {
      debugPrint('❌ Failed to clear auto-played history: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // AUTO-PLAY LOGIC
  // ═══════════════════════════════════════════════════════

  /// Auto-play audio if not played before
  /// Returns true if audio was auto-played, false if already played
  static Future<bool> autoPlayIfNeeded(String messageId, String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) {
      debugPrint('⚠️ No audio URL provided for message: $messageId');
      return false;
    }

    final alreadyPlayed = await hasAutoPlayed(messageId);
    
    if (!alreadyPlayed) {
      debugPrint('🔊 Auto-playing message: $messageId');
      await playAudio(audioUrl);
      await markAsAutoPlayed(messageId);
      return true;
    } else {
      debugPrint('⏭️ Message already auto-played: $messageId');
      return false;
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await _player.dispose();
      debugPrint('🗑️ TTS player disposed');
    } catch (e) {
      debugPrint('❌ Failed to dispose player: $e');
    }
  }
}

