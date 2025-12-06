import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'local_storage.dart';

/// 🔊 ELEVENLABS TTS SERVICE
/// Handles text-to-speech using your paid ElevenLabs voices via backend
class ElevenLabsTTSService {
  static final AudioPlayer _player = AudioPlayer();
  static String? _currentlyPlaying;
  static bool _isPlaying = false;

  /// Generate voice using ElevenLabs and return audio URL
  static Future<String?> generateVoice({
    required String text,
    String voiceKey = 'marcus', // Default voice
  }) async {
    try {
      debugPrint('🔊 Generating ElevenLabs voice for: ${text.length > 50 ? text.substring(0, 50) + '...' : text}');
      
      // Call backend voice generation endpoint using the proper API method
      final apiResponse = await ApiClient.generateVoice(
        text: text,
        voiceKey: voiceKey,
      );

      if (apiResponse.success && apiResponse.data != null) {
        final audioUrl = apiResponse.data!['url'] as String?;
        
        if (audioUrl != null && audioUrl.isNotEmpty) {
          debugPrint('✅ ElevenLabs voice generated: $audioUrl');
          return audioUrl;
        } else {
          debugPrint('⚠️ No audio URL in response');
          return null;
        }
      } else {
        debugPrint('❌ Voice generation failed: ${apiResponse.error}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ ElevenLabs voice generation error: $e');
      return null;
    }
  }

  /// Play audio from ElevenLabs URL
  static Future<void> playAudio(String audioUrl) async {
    try {
      debugPrint('🔊 Playing ElevenLabs audio: $audioUrl');
      
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
          debugPrint('✅ ElevenLabs audio playback completed');
        }
      });

    } catch (e) {
      debugPrint('❌ Failed to play ElevenLabs audio: $e');
      _isPlaying = false;
      _currentlyPlaying = null;
    }
  }

  /// Generate and play voice in one call
  static Future<bool> speakText({
    required String text,
    String? voiceKey, // Made nullable to use user's selected voice
  }) async {
    try {
      // Use user's selected voice from settings if no specific voice provided
      final selectedVoice = voiceKey ?? LocalStorageService.getSelectedVoice();
      debugPrint('🔊 Using voice: $selectedVoice (user selected: ${LocalStorageService.getSelectedVoice()})');
      
      // Generate voice using ElevenLabs
      final audioUrl = await generateVoice(text: text, voiceKey: selectedVoice);
      
      if (audioUrl != null) {
        await playAudio(audioUrl);
        return true;
      } else {
        debugPrint('❌ No audio URL generated from ElevenLabs');
        return false;
      }
    } catch (e) {
      debugPrint('❌ ElevenLabs speak failed: $e');
      return false;
    }
  }

  /// Stop currently playing audio
  static Future<void> stopAudio() async {
    try {
      if (_isPlaying) {
        await _player.stop();
        _isPlaying = false;
        _currentlyPlaying = null;
        debugPrint('⏹️ ElevenLabs audio stopped');
      }
    } catch (e) {
      debugPrint('❌ Failed to stop ElevenLabs audio: $e');
    }
  }

  /// Check if audio is currently playing
  static bool isPlaying() => _isPlaying;

  /// Get currently playing audio URL
  static String? getCurrentlyPlaying() => _currentlyPlaying;

  // ═══════════════════════════════════════════════════════
  // AUTO-PLAY TRACKING (Local Storage)
  // ═══════════════════════════════════════════════════════

  static const String _autoPlayedKey = 'elevenlabs_auto_played_messages';

  /// Mark a message as auto-played
  static Future<void> markAsAutoPlayed(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoPlayed = prefs.getStringList(_autoPlayedKey) ?? [];
      
      if (!autoPlayed.contains(messageId)) {
        autoPlayed.add(messageId);
        await prefs.setStringList(_autoPlayedKey, autoPlayed);
        debugPrint('✅ Marked as auto-played (ElevenLabs): $messageId');
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

  /// Auto-play ElevenLabs voice if not played before
  /// Returns true if audio was auto-played, false if already played
  static Future<bool> autoPlayIfNeeded({
    required String messageId,
    required String text,
    String? voiceKey, // Made nullable to use user's selected voice
  }) async {
    final alreadyPlayed = await hasAutoPlayed(messageId);
    
    if (!alreadyPlayed) {
      debugPrint('🔊 Auto-playing ElevenLabs message: $messageId');
      final success = await speakText(text: text, voiceKey: voiceKey);
      if (success) {
        await markAsAutoPlayed(messageId);
        return true;
      }
    } else {
      debugPrint('⏭️ ElevenLabs message already auto-played: $messageId');
    }
    return false;
  }

  /// Clear auto-played history (for testing or reset)
  static Future<void> clearAutoPlayedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_autoPlayedKey);
      debugPrint('🗑️ Cleared ElevenLabs auto-played history');
    } catch (e) {
      debugPrint('❌ Failed to clear auto-played history: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await _player.dispose();
      debugPrint('🗑️ ElevenLabs TTS player disposed');
    } catch (e) {
      debugPrint('❌ Failed to dispose ElevenLabs player: $e');
    }
  }

  /// Get voice key based on message type for variety
  static String getVoiceForMessageType(String messageType) {
    switch (messageType.toLowerCase()) {
      case 'brief':
      case 'morning':
        return 'marcus'; // Energetic morning voice
      case 'debrief':
      case 'evening':
        return 'confucius'; // Wise evening voice
      case 'nudge':
      case 'reminder':
        return 'drill'; // Motivational nudge voice
      case 'letter':
      case 'weekly':
        return 'lincoln'; // Thoughtful letter voice
      case 'awakening':
      case '7day':
        return 'buddha'; // Spiritual awakening voice
      default:
        return 'marcus'; // Default voice
    }
  }
}
