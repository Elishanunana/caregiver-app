import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/entities/sync_queue_entry.dart';
import '../data/repositories/event_log_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../data/values/values.dart';
import 'connectivity_arbiter.dart';
import 'hub_api_client.dart';
import 'hub_to_app_applier.dart';
import 'secure_settings_service.dart';
import 'sync_state_notifier.dart';

/// Orchestrates the bidirectional Wi-Fi sync loop.
///
/// On each cycle:
///   1. Ask the arbiter whether to proceed (hub reachable? not in cooldown?)
///   2. Pull the unsynced Hub→App event batch from /events/unsynced,
///      apply via HubToAppApplier, and POST acks to /events/ack.
///   3. Push pending App→Hub schedule changes to /schedule/sync and mark
///      the confirmed ones synced locally.
///   4. Update the SyncStateNotifier so the UI reflects the outcome.
///
/// The App→Hub push is the Wi-Fi arm of the hybrid schedule-sync pathway
/// (Section 3.5.4). The SMS pathway remains the offline fallback; both
/// carry the same change_id, and the hub's idempotency check dedupes a
/// change that happens to arrive via both.
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
    this.pollInterval = const Duration(seconds: 5),
    this.clientFactory,
  })  : _settings = settings,
        _eventRepo = eventRepo,
        _syncRepo = syncRepo,
        _arbiter = arbiter,
        _stateNotifier = stateNotifier;

  /// Begin periodic syncing. The first cycle fires immediately so the
  /// caregiver doesn't wait a full poll interval after foregrounding
  /// the app. Subsequent cycles run every [pollInterval] (default 5s).
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

  /// One full Wi-Fi cycle: pull Hub→App events, then push App→Hub
  /// schedule changes.
  Future<void> _runWifiCycle(HubApiClient client) async {
    final applier = HubToAppApplier(
      eventRepo: _eventRepo,
      syncRepo: _syncRepo,
    );

    int totalApplied = 0;
    int totalSkipped = 0;

    // ── Phase 1: pull Hub→App events (paged, drains up to 5 pages) ──────
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

    // ── Phase 2: push pending App→Hub schedule changes over REST ───────
    final pushed = await _pushPendingSchedules(client);
    if (kDebugMode && pushed > 0) {
      debugPrint('[SyncEngine] pushed $pushed schedule change(s) to hub.');
    }

    _stateNotifier.endSync(
      outcome: SyncOutcome.success,
      applied: totalApplied,
      skipped: totalSkipped,
    );
  }

  /// Push every pending App→Hub schedule change to /schedule/sync.
  ///
  /// Each pending entry carries the same pipe-delimited canonical the SMS
  /// pathway signs (MED|type|change_id|elder_id|drug|dosage|time|days|
  /// active|timestamp|HMAC=...). We rebuild the REST change object from
  /// those fields — no HMAC needed on REST, since the bearer token
  /// authenticates the channel. Entries the hub confirms ('ok') or has
  /// already seen ('duplicate') are marked synced; anything else is left
  /// pending for the next cycle to retry.
  ///
  /// Returns the number of changes newly applied by the hub.
  Future<int> _pushPendingSchedules(HubApiClient client) async {
    final pending = _syncRepo.listPendingAppToHub();
    if (pending.isEmpty) return 0;

    final changes = <Map<String, dynamic>>[];
    for (final entry in pending) {
      final change = _changeFromEntry(entry);
      if (change != null) changes.add(change);
    }
    if (changes.isEmpty) return 0;

    final response = await client.syncScheduleBatch(changes);

    final results = response['results'];
    if (results is! List) return 0;

    int applied = 0;
    for (final r in results) {
      if (r is! Map) continue;
      final status = r['status'] as String?;
      final changeId = r['change_id'] as String?;
      if (changeId == null || changeId.isEmpty) continue;

      // 'ok' → newly applied; 'duplicate' → hub already has it. Both mean
      // the change is durably on the hub, so stop resending it.
      if (status == 'ok' || status == 'duplicate') {
        await _syncRepo.updateState(changeId, SyncState.synced);
        if (status == 'ok') applied++;
      }
    }
    return applied;
  }

  /// Rebuild a REST schedule-change object from a pending SyncQueue entry.
  /// Returns null (skipping the entry) if the payload isn't a recognised
  /// MED canonical string.
  Map<String, dynamic>? _changeFromEntry(SyncQueueEntry entry) {
    final parts = entry.payload.split('|');
    // MED|type|change_id|elder_id|drug|dosage|time|days|active|ts|HMAC=...
    if (parts.length < 10 || parts[0] != 'MED') return null;

    final elderId = int.tryParse(parts[3]);
    final active = int.tryParse(parts[8]);
    if (elderId == null || active == null) return null;

    return {
      'change_id':     entry.changeId.isNotEmpty ? entry.changeId : parts[2],
      'elder_id':      elderId,
      'drug_name':     parts[4],
      'dosage':        parts[5],
      'time_due':      parts[6],
      'days_of_week':  parts[7],
      'active':        active,
      'prescribed_by': PrescribedBy.pharmacist,
      'timestamp':     entry.timestamp ?? parts[9],
    };
  }
}
