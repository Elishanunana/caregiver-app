import '../../core/constants/hive_boxes.dart';
import '../entities/sync_queue_entry.dart';
import '../values/values.dart';
import 'base_repository.dart';

/// Repository for the bidirectional sync change ledger.
///
/// Each entry represents one pending or completed change being
/// transported between hub and app. The `direction` field encodes
/// whether the change originated on the hub or on the app, and the
/// `transport` field encodes which pathway carries (or carried) it
/// — Wi-Fi REST or SMS payload (Section 3.5.4 of the project report).
class SyncQueueRepository extends BaseRepository<SyncQueueEntry> {
  @override
  String get boxName => HiveBoxes.syncQueueEntries;

  /// Look up a change by its UUID4 `changeId`.
  /// Critical for idempotency: if a payload arrives twice, the second
  /// insert is a no-op because the changeId is already present.
  SyncQueueEntry? getByChangeId(String changeId) {
    return box.values.cast<SyncQueueEntry?>().firstWhere(
          (e) => e?.changeId == changeId,
          orElse: () => null,
        );
  }

  /// Pending App→Hub changes that need to be transmitted.
  /// The Wi-Fi or SMS pathway pulls from this list when a sync window opens.
  List<SyncQueueEntry> listPendingAppToHub() {
    return box.values
        .where((e) =>
            e.syncState == SyncState.pending &&
            e.direction == SyncDirection.appToHub)
        .toList(growable: false);
  }

  /// Pending Hub→App changes (e.g., events that arrived but haven't yet
  /// been folded into their target entity boxes by the sync engine).
  List<SyncQueueEntry> listPendingHubToApp() {
    return box.values
        .where((e) =>
            e.syncState == SyncState.pending &&
            e.direction == SyncDirection.hubToApp)
        .toList(growable: false);
  }

  /// Insert a new change. The changeId is the Hive key, guaranteeing
  /// idempotency under retransmission.
  Future<void> insert(SyncQueueEntry entry) async {
    if (entry.changeId.isEmpty) {
      throw ArgumentError('SyncQueueEntry.changeId must be set before insert');
    }
    await box.put(entry.changeId, entry);
  }

  /// Update the sync state of a change after a transport attempt.
  /// Returns true if the record existed and was updated.
  Future<bool> updateState(String changeId, String newState) async {
    if (!SyncState.isValid(newState)) {
      throw ArgumentError('Invalid sync state: $newState');
    }
    final entry = box.get(changeId);
    if (entry == null) return false;
    entry.syncState = newState;
    if (newState == SyncState.failed || newState == SyncState.inFlight) {
      entry.attempts++;
    }
    await entry.save();
    return true;
  }

  /// Remove all successfully-synced changes older than [retainCount].
  /// Keeps the queue small over the lifetime of a deployment.
  Future<int> pruneSynced({int retainCount = 200}) async {
    final synced = box.values
        .where((e) => e.syncState == SyncState.synced)
        .toList(growable: true)
      ..sort((a, b) => (b.timestamp ?? '').compareTo(a.timestamp ?? ''));

    if (synced.length <= retainCount) return 0;

    final toDelete = synced.skip(retainCount).toList();
    for (final entry in toDelete) {
      await box.delete(entry.changeId);
    }
    return toDelete.length;
  }
}
