import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/event_log_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import 'connectivity_arbiter.dart';
import 'hub_api_client.dart';
import 'hub_to_app_applier.dart';
import 'secure_settings_service.dart';
import 'sync_state_notifier.dart';

/// Orchestrates the bidirectional Wi-Fi sync loop.
///
/// On each cycle:
///   1. Ask the arbiter whether to proceed (hub reachable? not in cooldown?)
///   2. If yes, fetch the unsynced batch from /events/unsynced
///   3. Apply via HubToAppApplier (idempotent inserts + ack-for-change-id detection)
///   4. POST the event_ids to /events/ack
///   5. If the response indicates more available, drain in a follow-up cycle
///   6. Update the SyncStateNotifier so the UI reflects the outcome
///
/// Error handling:
///   • Hub unreachable → arbiter records failure; cycle returns Skipped
///   • HTTP/parse error → cycle marked Error, error message surfaced to UI
///   • Apply errors → cycle marked Error; the SyncQueue is left intact for retry
class SyncEngine {
  final SecureSettingsService _settings;
  final EventLogRepository _eventRepo;
  final SyncQueueRepository _syncRepo;
  final ConnectivityArbiter _arbiter;
  final SyncStateNotifier _stateNotifier;

  /// Optional override for testing: the factory used to construct the
  /// HTTP client per cycle. In production, each cycle creates a fresh
  /// HubApiClient using the latest settings; in tests we inject a mock.
  final HubApiClient Function(String baseUrl, String pairingToken)?
      clientFactory;

  Duration pollInterval;
  Timer? _timer;
  bool _disposed = false;

  /// True if a cycle is in flight — used to prevent overlapping syncs
  /// when the timer fires while a previous cycle is still running.
  bool _inFlight = false;

  SyncEngine({
    required SecureSettingsService settings,
    required EventLogRepository eventRepo,
    required SyncQueueRepository syncRepo,
    required ConnectivityArbiter arbiter,
    required SyncStateNotifier stateNotifier,
    this.pollInterval = const Duration(seconds: 30),
    this.clientFactory,
  })  : _settings = settings,
        _eventRepo = eventRepo,
        _syncRepo = syncRepo,
        _arbiter = arbiter,
        _stateNotifier = stateNotifier;

  /// Begin periodic syncing. The first cycle fires immediately so the
  /// caregiver doesn't wait 30 seconds after foregrounding the app.
  void start() {
    if (_disposed) return;
    _timer?.cancel();
    runOnce(); // immediate
    _timer = Timer.periodic(pollInterval, (_) => runOnce());
  }

  /// Stop periodic syncing. Idempotent.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Permanent shutdown. The engine cannot be restarted after dispose.
  void dispose() {
    stop();
    _disposed = true;
  }

  /// Run a sync cycle now, bypassing any cooldown. Used by pull-to-refresh
  /// where the user explicitly demands a fresh attempt.
  Future<void> clearCooldownAndRunNow() async {
    _arbiter.clearCooldown();
    await runOnce();
  }

  /// Run one sync cycle. Returns when the cycle completes (or skips).
  ///
  /// Exposed publicly so screens can trigger pull-to-refresh sync
  /// directly. Internally guarded against overlapping cycles.
  Future<void> runOnce() async {
    if (_disposed || _inFlight) return;
    _inFlight = true;
    _stateNotifier.beginSync();

    try {
      final url   = await _settings.getHubUrl();
      final token = await _settings.getPairingToken();
      final client = (clientFactory ??
              (b, t) => HubApiClient(baseUrl: b, pairingToken: t))(url, token);

      try {
        final verdict = await _arbiter.shouldSync(client);

        switch (verdict) {
          case ArbiterVerdict.cooldown:
            _stateNotifier.endSync(outcome: SyncOutcome.cooldown);
            return;
          case ArbiterVerdict.skip:
            _stateNotifier.endSync(
              outcome: SyncOutcome.skipped,
              errorMessage: 'Hub unreachable.',
            );
            return;
          case ArbiterVerdict.proceedWifi:
            await _runWifiCycle(client);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _stateNotifier.endSync(
        outcome: SyncOutcome.error,
        errorMessage: e.toString(),
      );
      if (kDebugMode) {
        debugPrint('[SyncEngine] cycle failed: $e');
      }
    } finally {
      _inFlight = false;
    }
  }

  /// Drain the hub's unsynced queue via Wi-Fi REST. Pages until empty
  /// or the safety limit is hit (we cap at 5 pages per cycle to avoid
  /// monopolising the foreground app on a long backlog — the next
  /// cycle will pick up the rest).
  Future<void> _runWifiCycle(HubApiClient client) async {
    final applier = HubToAppApplier(
      eventRepo: _eventRepo,
      syncRepo: _syncRepo,
    );

    int totalApplied = 0;
    int totalSkipped = 0;

    for (var page = 0; page < 5; page++) {
      final response = await client.fetchUnsyncedEvents();
      if (response.events.isEmpty) break;

      final result = await applier.applyBatch(response.events);
      totalApplied += result.inserted;
      totalSkipped += result.skipped;

      if (result.ackEventIds.isNotEmpty) {
        await client.ackEvents(result.ackEventIds);
      }

      // If the page wasn't full, the queue is drained.
      if (!response.hasMore) break;
    }

    _stateNotifier.endSync(
      outcome: SyncOutcome.success,
      applied: totalApplied,
      skipped: totalSkipped,
    );
  }
}
