import 'package:hive/hive.dart';

import '../../core/constants/hive_type_ids.dart';

part 'event_log_entry.g.dart';

/// Mirrors `EventLogEntry` from the hub's repositories — append-only.
///
/// This is the immutable audit log of all hub events: reminders,
/// confirmations, SOS triggers, appliance commands, power-state
/// transitions, and inbound SMS payload validation outcomes.
/// On the app side we mirror records as they sync from the hub; we
/// never originate EventLog records locally.
@HiveType(typeId: HiveTypeIds.eventLogEntry)
class EventLogEntry extends HiveObject {
  @HiveField(0)
  int? eventId;

  @HiveField(1)
  String eventType;

  @HiveField(2)
  String? timestamp;     // ISO-8601 UTC, set by the hub

  @HiveField(3)
  String? details;       // Free-form text or JSON string

  @HiveField(4)
  int syncedFlag;        // 0 | 1

  EventLogEntry({
    this.eventId,
    this.eventType = '',
    this.timestamp,
    this.details,
    this.syncedFlag = 0,
  });

  factory EventLogEntry.fromJson(Map<String, dynamic> json) => EventLogEntry(
        eventId: json['event_id'] as int?,
        eventType: (json['event_type'] as String?) ?? '',
        timestamp: json['timestamp'] as String?,
        details: json['details'] as String?,
        syncedFlag: (json['synced_flag'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'event_type': eventType,
        'timestamp': timestamp,
        'details': details,
        'synced_flag': syncedFlag,
      };

  bool get isSynced => syncedFlag == 1;
}
