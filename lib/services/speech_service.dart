import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_client.dart';

/// 🎤 SPEECH SERVICE
/// Handles audio recording and transcription using OpenAI Whisper
class SpeechService {
  static final AudioRecorder _recorder = AudioRecorder();
  static String? _currentRecordingPath;
  static bool _isRecording = false;

  /// Check if STT is supported on this platform
  static bool get isSupported => true; // Enable STT on all platforms for testing

  /// Check if currently recording
  static bool get isRecording => _isRecording;

  /// Start audio recording
  static Future<bool> startRecording() async {
    // Platform check
    if (!isSupported) {
      debugPrint('⚠️ STT not supported on this platform');
      return false;
    }
    
    try {
      // Check and request permission
      if (await _recorder.hasPermission()) {
        // Get temporary directory
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${tempDir.path}/audio_$timestamp.m4a';

        // Start recording
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        _currentRecordingPath = filePath;
        _isRecording = true;
        
        debugPrint('🎤 Recording started: $filePath');
        return true;
      } else {
        debugPrint('❌ Microphone permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      return false;
    }
  }

  /// Stop audio recording and return the file
  static Future<File?> stopRecording() async {
    try {
      if (!_isRecording) {
        debugPrint('⚠️ Not currently recording');
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null && path.isNotEmpty) {
        debugPrint('✅ Recording stopped: $path');
        final file = File(path);
        
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('📁 File size: ${(size / 1024).toStringAsFixed(2)} KB');
          return file;
        }
      }

      debugPrint('❌ Recording file not found');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without saving
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
        
        // Delete the file if it exists
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint('🗑️ Recording cancelled and deleted');
          }
        }
        
        _currentRecordingPath = null;
      }
    } catch (e) {
      debugPrint('❌ Failed to cancel recording: $e');
    }
  }

  /// Transcribe audio file using backend Whisper API
  static Future<String?> transcribeAudio(File audioFile) async {
    try {
      debugPrint('📤 Uploading audio for transcription...');

      // Get Firebase user ID for headers
      final userId = ApiClient.userId;
      if (userId == null) {
        debugPrint('❌ No user ID available');
        return null;
      }
      
      // Create multipart request
      const baseUrl = 'https://futureyou-production.up.railway.app';
      final uri = Uri.parse('$baseUrl/api/v1/speech/transcribe');
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers with user ID
      request.headers['x-user-id'] = userId;
      request.headers['Content-Type'] = 'multipart/form-data';
      
      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          filename: 'audio.m4a',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String?;
        
        debugPrint('✅ Transcription successful: "$text"');
        
        // Clean up audio file
        if (await audioFile.exists()) {
          await audioFile.delete();
          debugPrint('🗑️ Audio file deleted');
        }
        
        return text;
      } else {
        debugPrint('❌ Transcription failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Transcription error: $e');
      return null;
    }
  }

  /// Record audio and return transcription
  /// This is a convenience method that handles the full flow
  static Future<String?> recordAndTranscribe() async {
    try {
      // Start recording
      final started = await startRecording();
      if (!started) return null;

      // Wait for user to stop (handled by UI)
      // This method assumes stopRecording() will be called separately
      
      return null; // Transcription happens after stopRecording()
    } catch (e) {
      debugPrint('❌ Record and transcribe error: $e');
      return null;
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
      }
      await _recorder.dispose();
    } catch (e) {
      debugPrint('❌ Failed to dispose recorder: $e');
    }
  }
}

