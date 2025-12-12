import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'messages_service.dart';
import 'offline_queue.dart';
import 'api_client.dart';
import '../models/habit.dart';

class SyncService {
  // Singleton
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Configuration
  static const Duration _messageSyncInterval = Duration(minutes: 15);
  static const int _maxCompletionsPerBatch = 50;
  
  String? get _userId => ApiClient.userId;

  // State
  Timer? _messageSyncTimer;
  bool _isInitialized = false;
  bool _isSyncingCompletions = false;
  
  // Completion queue (in-memory)
  final List<HabitCompletion> _pendingCompletions = [];

  /// Initialize sync service
  Future<void> init() async {
    if (_isInitialized) return;

    debugPrint('🔄 Initializing Sync Service...');

    await offlineQueue.init();
    await messagesService.init();

    // Ensure user exists on backend (auto-create)
    await _ensureUserExists();

    // Start periodic message sync
    startPeriodicMessageSync();

    // Replay offline queue
    await replayOfflineQueue();

    _isInitialized = true;
    debugPrint('✅ Sync Service initialized');
  }

  /// Ensure user exists on backend (creates if not exists)
  Future<void> _ensureUserExists() async {
    // Skip if no user is authenticated
    final userId = _userId;
    if (userId == null) {
      debugPrint('⚠️ Skipping user sync - no authenticated user');
      return;
    }
    
    try {
      debugPrint('👤 Ensuring user exists on backend: $userId');
      
      final response = await http.post(
        Uri.parse('https://futureyou-production.up.railway.app/api/v1/users'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId,
        },
        body: jsonEncode({}), // Send empty JSON body (Fastify requirement)
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final created = data['created'] ?? false;
        if (created) {
          debugPrint('✅ User created on backend: $userId');
        } else {
          debugPrint('✓ User already exists: $userId');
        }
      } else {
        debugPrint('⚠️ Failed to ensure user exists: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ User creation check failed: $e (will retry later)');
      // Don't throw - app works offline
    }
  }

  /// Start periodic message sync (every 15 minutes)
  void startPeriodicMessageSync() {
    _messageSyncTimer?.cancel();
    _messageSyncTimer = Timer.periodic(_messageSyncInterval, (timer) {
      debugPrint('⏰ Periodic message sync triggered');
      syncMessages();
    });
    debugPrint('✓ Started periodic message sync (${_messageSyncInterval.inMinutes}min interval)');
    
    // Don't sync immediately - let screens control when to sync to prevent blocking UI
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _messageSyncTimer?.cancel();
    debugPrint('⏸️ Stopped periodic message sync');
  }

  /// Sync messages from backend
  Future<void> syncMessages() async {
    final userId = _userId;
    if (userId == null) {
      debugPrint('⚠️ Skipping message sync - no authenticated user');
      return;
    }
    
    try {
      await messagesService.syncMessages(userId);
    } catch (e) {
      debugPrint('❌ Message sync error: $e');
      // Don't throw - let the app continue working offline
    }
  }

  /// Queue a habit completion for sync
  void queueCompletion(HabitCompletion completion) {
    _pendingCompletions.add(completion);
    debugPrint('📝 Queued completion: ${completion.habitId} (${completion.done ? "done" : "undone"})');

    // Trigger batch sync if queue is getting large
    if (_pendingCompletions.length >= 10) {
      syncCompletions();
    }
  }

  /// Sync pending completions to backend
  Future<bool> syncCompletions() async {
    if (_isSyncingCompletions) {
      debugPrint('⏭️ Completion sync already in progress');
      return false;
    }

    if (_pendingCompletions.isEmpty) {
      debugPrint('✓ No completions to sync');
      return true;
    }

    _isSyncingCompletions = true;

    try {
      // Take batch
      final batch = _pendingCompletions.take(_maxCompletionsPerBatch).toList();
      
      debugPrint('🔄 Syncing ${batch.length} completions to backend...');

      final result = await ApiClient.syncCoachData([], batch);

      if (result.success) {
        // Remove synced items from queue
        _pendingCompletions.removeRange(0, batch.length);
        debugPrint('✅ Synced ${batch.length} completions');
        _isSyncingCompletions = false;
        return true;
      } else {
        throw Exception(result.error);
      }
    } on SocketException {
      debugPrint('❌ No internet - queueing for offline sync');
      // Add to offline queue
      await _queueCompletionsOffline(_pendingCompletions);
      _pendingCompletions.clear();
      _isSyncingCompletions = false;
      return false;
    } on TimeoutException {
      debugPrint('❌ Sync timeout');
      _isSyncingCompletions = false;
      return false;
    } catch (e) {
      debugPrint('❌ Completion sync error: $e');
      _isSyncingCompletions = false;
      return false;
    }
  }

  /// Queue completions for offline sync
  Future<void> _queueCompletionsOffline(List<HabitCompletion> completions) async {
    if (completions.isEmpty) return;

    await offlineQueue.enqueue(
      endpoint: '/api/v1/coach/sync',
      method: 'POST',
      body: {
        'completions': completions.map((c) => c.toJson()).toList(),
      },
    );
  }

  /// Replay offline queue when network returns
  Future<void> replayOfflineQueue() async {
    final pending = offlineQueue.getPending();
    if (pending.isEmpty) return;

    debugPrint('🔁 Replaying ${pending.length} offline requests...');

    for (final request in pending) {
      try {
        // Attempt to send
        if (request.method == 'POST' && request.endpoint == '/api/v1/coach/sync') {
          final completionsJson = request.body['completions'] as List;
          final completions = completionsJson
              .map((json) => HabitCompletion.fromJson(json as Map<String, dynamic>))
              .toList();

          final result = await ApiClient.syncCoachData([], completions);

          if (result.success) {
            await offlineQueue.markProcessed(request.id);
            debugPrint('✓ Replayed offline request: ${request.id}');
          } else {
            await offlineQueue.incrementRetry(request.id);
            debugPrint('⚠️ Offline replay failed: ${request.id}');
          }
        }
      } catch (e) {
        await offlineQueue.incrementRetry(request.id);
        debugPrint('❌ Error replaying ${request.id}: $e');
      }
    }

    // Clean up old/failed requests
    await offlineQueue.cleanup();
  }

  /// Manual sync trigger (for pull-to-refresh, etc.)
  Future<void> syncAll() async {
    debugPrint('🔄 Manual sync triggered');
    await Future.wait([
      syncMessages(),
      syncCompletions(),
      replayOfflineQueue(),
    ]);
  }

  /// Get sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'lastMessageSync': messagesService.lastSyncTime,
      'isSyncingMessages': messagesService.isSyncing,
      'lastSyncError': messagesService.lastSyncError,
      'pendingCompletions': _pendingCompletions.length,
      'offlineQueueSize': offlineQueue.getPendingCount(),
    };
  }

  /// Dispose resources
  void dispose() {
    _messageSyncTimer?.cancel();
    debugPrint('🛑 Sync Service disposed');
  }
}

// Global instance
final syncService = SyncService();

