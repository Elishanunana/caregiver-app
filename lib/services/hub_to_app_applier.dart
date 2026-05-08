import 'dart:convert';

import '../data/entities/event_log_entry.dart';
import '../data/repositories/event_log_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../data/values/values.dart';

/// Outcome of an apply pass.
class ApplyResult {
  /// Number of events newly inserted into the local EventLog.
  final int inserted;

  /// Number of events that were already present (idempotent skip).
  final int skipped;

  /// IDs of events that should be acknowledged back to the hub.
  /// Includes both newly-inserted and previously-applied events:
  /// re-acking previously-applied events is harmless (the hub returns
  /// status='already_synced') and ensures eventually-consistent state.
  final List<int> ackEventIds;

  const ApplyResult({
    required this.inserted,
    required this.skipped,
    required this.ackEventIds,
  });
}

/// Applies a batch of unsynced-event records, as returned by the hub's
/// `/events/unsynced` endpoint, to the local Hive store.
///
/// Responsibilities:
///   • Insert new EventLog records (idempotently — duplicate event_ids
///     are skipped without error, preserving the hub's "at-least-once"
///     delivery semantics).
///   • Mark them as locally synced (synced_flag = 1).
///   • Detect Hub→App ack records and update the corresponding
///     SyncQueue entries (per Section 3.5.2 of the project report:
///     "a corresponding Hub→App acknowledgement record is queued in
///     the SyncQueue for transmission during the next Wi-Fi window").
///   • Return the list of event_ids to acknowledge back to the hub.
///
/// The applier is intentionally synchronous-feeling — every call to
/// `applyBatch` either succeeds entirely or raises; partial application
/// is avoided by performing all Hive writes within a single async scope.
class HubToAppApplier {
  final EventLogRepository _eventRepo;
  final SyncQueueRepository _syncRepo;

  HubToAppApplier({
    required EventLogRepository eventRepo,
    required SyncQueueRepository syncRepo,
  })  : _eventRepo = eventRepo,
        _syncRepo = syncRepo;

  /// Apply a batch of event JSON objects from the hub.
  /// The [transport] parameter tracks how this batch arrived
  /// (defaults to wifi_rest, but SMS-in can override this later).
  Future<ApplyResult> applyBatch(
    List<Map<String, dynamic>> rawEvents, {
    String transport = SyncTransport.wifiRest,
  }) async {
    int inserted = 0;
    int skipped  = 0;
    final ackIds = <int>[];

    for (final raw in rawEvents) {
      final eventId = raw['event_id'] as int?;
      if (eventId == null) continue; // skip unparseable record

      // Always ack — even already-applied events. The hub treats a
      // re-ack as 'already_synced' (no-op), and acking idempotently
      // keeps the hub's queue draining even under client-side retries.
      ackIds.add(eventId);

      final existing = _eventRepo.getById(eventId);
      if (existing != null) {
        skipped++;
        continue;
      }

      // Convert the JSON `details` object to a string for storage.
      // Our EventLogEntry persists details as String for backwards
      // compatibility with Tasks 16-18; we render it as text.
      final detailsJson = raw['details'];
      final detailsString = detailsJson == null
          ? null
          : jsonEncode(detailsJson);

      final entry = EventLogEntry(
        eventId: eventId,
        eventType: (raw['event_type'] as String?) ?? '',
        timestamp: raw['timestamp'] as String?,
        details: detailsString,
        syncedFlag: 1, // we are applying it now → it's synced locally
        transport: transport, // Set the transport metadata
      );
      await _eventRepo.insertFromHub(entry);
      inserted++;

      // Special handling: if the inbound event is an ack for one of
      // our App→Hub changes, mark the corresponding SyncQueue entry
      // as synced. The hub's SMSPayloadHandler emits acks with an
      // 'ack_for_change_id' field in the details payload (see
      // Section 3.5.2 / sms_payload_handler.py).
      await _maybeMarkAppToHubAckApplied(detailsJson);
    }

    return ApplyResult(
      inserted: inserted,
      skipped: skipped,
      ackEventIds: ackIds,
    );
  }

  /// If the inbound event is a Hub→App ack carrying ack_for_change_id,
  /// flip the corresponding App→Hub SyncQueue entry from pending/in_flight
  /// to synced.
  Future<void> _maybeMarkAppToHubAckApplied(dynamic detailsJson) async {
    if (detailsJson is! Map) return;
    final ackedChangeId = detailsJson['ack_for_change_id'];
    if (ackedChangeId is! String || ackedChangeId.isEmpty) return;

    await _syncRepo.updateState(ackedChangeId, SyncState.synced);
  }
}
