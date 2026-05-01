import 'package:hive/hive.dart';

import '../../core/constants/hive_type_ids.dart';
import '../values/values.dart';

part 'sync_queue_entry.g.dart';

/// Mirrors `SyncQueueEntry` from the hub's repositories.
///
/// This is the bidirectional change ledger — the same shape used on the
/// hub for both Hub→App pushes and App→Hub uploads. The `direction` and
/// `transport` fields encode which way the change travels and which
/// pathway carries it (Section 3.5.4 of the project report).
@HiveType(typeId: HiveTypeIds.syncQueueEntry)
class SyncQueueEntry extends HiveObject {
  @HiveField(0)
  String changeId;       // UUID4 string — primary key

  @HiveField(1)
  String entityType;     // e.g. 'MedicationSchedule', 'EventLogEntry'

  @HiveField(2)
  int entityId;

  @HiveField(3)
  String changeType;     // ChangeType.* values

  @HiveField(4)
  String? timestamp;     // ISO-8601 UTC

  @HiveField(5)
  String syncState;      // SyncState.* values

  @HiveField(6)
  String direction;      // SyncDirection.* values

  @HiveField(7)
  String transport;      // SyncTransport.* values

  @HiveField(8)
  String payload;        // Serialized JSON (the change body)

  @HiveField(9)
  int attempts;

  SyncQueueEntry({
    this.changeId = '',
    this.entityType = '',
    this.entityId = 0,
    this.changeType = '',
    this.timestamp,
    this.syncState = SyncState.pending,
    this.direction = '',
    this.transport = '',
    this.payload = '',
    this.attempts = 0,
  });

  factory SyncQueueEntry.fromJson(Map<String, dynamic> json) => SyncQueueEntry(
        changeId: (json['change_id'] as String?) ?? '',
        entityType: (json['entity_type'] as String?) ?? '',
        entityId: (json['entity_id'] as int?) ?? 0,
        changeType: (json['change_type'] as String?) ?? '',
        timestamp: json['timestamp'] as String?,
        syncState: (json['sync_state'] as String?) ?? SyncState.pending,
        direction: (json['direction'] as String?) ?? '',
        transport: (json['transport'] as String?) ?? '',
        payload: (json['payload'] as String?) ?? '',
        attempts: (json['attempts'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'change_id': changeId,
        'entity_type': entityType,
        'entity_id': entityId,
        'change_type': changeType,
        'timestamp': timestamp,
        'sync_state': syncState,
        'direction': direction,
        'transport': transport,
        'payload': payload,
        'attempts': attempts,
      };
}
