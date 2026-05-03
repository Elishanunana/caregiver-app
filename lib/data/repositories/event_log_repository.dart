import '../../core/constants/hive_boxes.dart';
import '../entities/event_log_entry.dart';
import 'base_repository.dart';

/// Repository for the append-only event log.
///
/// On the app side, EventLog records are mirror copies of authoritative
/// records on the hub. We never originate EventLog entries locally —
/// they always arrive via Hub→App sync and are inserted in receipt order.
///
/// Notable absences (deliberate, matching the hub's design):
///   • No update method — events are immutable once stored.
///   • No deleteById — events are never removed (audit-trail integrity).
class EventLogRepository extends BaseRepository<EventLogEntry> {
  @override
  String get boxName => HiveBoxes.eventLogEntries;

  /// Find an event by its hub-assigned `eventId`.
  EventLogEntry? getById(int eventId) {
    return box.values
        .cast<EventLogEntry?>()
        .firstWhere((e) => e?.eventId == eventId, orElse: () => null);
  }

  /// All events newest-first (descending timestamp).
  /// Canonical query for the Event History screen.
  List<EventLogEntry> listNewestFirst() {
    final result = box.values.toList(growable: true);
    result.sort((a, b) {
      final tsA = a.timestamp ?? '';
      final tsB = b.timestamp ?? '';
      return tsB.compareTo(tsA); // descending
    });
    return result;
  }

  /// Filter by event type. The `eventType` field uses the same string
  /// constants the hub emits (e.g., 'reminder_dose_due', 'sos_triggered',
  /// 'dose_confirmed', 'dose_missed'). We do not enumerate them on the
  /// app side — we treat them as opaque strings, matching the hub's
  /// own treatment and avoiding coupling to the hub's evolving event
  /// taxonomy.
  List<EventLogEntry> listByType(String eventType) {
    return box.values
        .where((e) => e.eventType == eventType)
        .toList(growable: false);
  }

  /// Events whose timestamp falls within [start, end] inclusive of [start]
  /// and exclusive of [end]. Both bounds are interpreted as UTC.
  /// Returns newest-first; safe on empty boxes.
  List<EventLogEntry> listInRange({
    required DateTime start,
    required DateTime end,
  }) {
    final startIso = start.toUtc().toIso8601String();
    final endIso   = end.toUtc().toIso8601String();
    final result = box.values
        .where((e) {
          final ts = e.timestamp;
          if (ts == null || ts.isEmpty) return false;
          return ts.compareTo(startIso) >= 0 && ts.compareTo(endIso) < 0;
        })
        .toList(growable: true);
    result.sort((a, b) => (b.timestamp ?? '').compareTo(a.timestamp ?? ''));
    return result;
  }

  /// Insert a record arrived from the hub. The hub-assigned `eventId`
  /// becomes the Hive key, so a duplicate transmission overwrites
  /// rather than creating a second copy — this is the idempotency
  /// guarantee for at-least-once delivery semantics on either pathway.
  Future<void> insertFromHub(EventLogEntry entry) async {
    if (entry.eventId == null) {
      throw ArgumentError('insertFromHub requires a hub-assigned eventId');
    }
    await box.put(entry.eventId, entry);
  }
}
