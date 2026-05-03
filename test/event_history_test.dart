import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:caregiver_app/core/constants/hive_boxes.dart';
import 'package:caregiver_app/data/entities/elder_profile.dart';
import 'package:caregiver_app/data/entities/event_log_entry.dart';
import 'package:caregiver_app/data/entities/medication_schedule.dart';
import 'package:caregiver_app/data/entities/sync_queue_entry.dart';
import 'package:caregiver_app/data/repositories/event_log_repository.dart';
import 'package:caregiver_app/data/values/event_type_meta.dart';

Future<void> _setUpHive() async {
  Hive.init('.test_hive_${DateTime.now().microsecondsSinceEpoch}');
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ElderProfileAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MedicationScheduleAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(EventLogEntryAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SyncQueueEntryAdapter());
  await Hive.openBox<ElderProfile>(HiveBoxes.elderProfiles);
  await Hive.openBox<MedicationSchedule>(HiveBoxes.medicationSchedules);
  await Hive.openBox<EventLogEntry>(HiveBoxes.eventLogEntries);
  await Hive.openBox<SyncQueueEntry>(HiveBoxes.syncQueueEntries);
}

Future<void> _tearDownHive() async {
  // Close all open boxes first so Windows releases the file handles
  // before we try to delete the directory. On Windows, deleteFromDisk
  // alone races with the OS's lock-release timing.
  await Hive.close();
  // Best-effort cleanup; Windows occasionally still holds a handle for
  // a few ms after close. The empty-directory residue is gitignored.
  try {
    await Hive.deleteFromDisk();
  } catch (_) {
    // Tolerate residual file-lock; subsequent tests use a unique path.
  }
}

void main() {
  group('EventLogRepository.listInRange', () {
    late EventLogRepository repo;

    setUp(() async {
      await _setUpHive();
      repo = EventLogRepository();

      // Seed events spanning three days for boundary testing.
      Future<void> add(int id, String day, int h) async {
        await repo.insertFromHub(EventLogEntry(
          eventId: id,
          eventType: 'reminder_dose_due',
          timestamp: '2026-04-${day.padLeft(2, "0")}T${h.toString().padLeft(2, "0")}:00:00.000Z',
          syncedFlag: 1,
        ));
      }
      await add(1, '28', 8);
      await add(2, '29', 8);
      await add(3, '29', 14);
      await add(4, '30', 8);
    });
    tearDown(_tearDownHive);

    test('returns only events within bounds, newest first', () {
      final result = repo.listInRange(
        start: DateTime.utc(2026, 4, 29, 0, 0),
        end: DateTime.utc(2026, 4, 30, 0, 0),
      );
      expect(result.length, 2);
      expect(result.first.eventId, 3); // 14:00 newer than 08:00
      expect(result.last.eventId, 2);
    });

    test('end bound is exclusive', () {
      final result = repo.listInRange(
        start: DateTime.utc(2026, 4, 29, 14, 0),
        end: DateTime.utc(2026, 4, 30, 8, 0),
      );
      // Includes 4-29 14:00, excludes 4-30 08:00
      expect(result.map((e) => e.eventId).toList(), [3]);
    });

    test('returns empty list when no events match', () {
      final result = repo.listInRange(
        start: DateTime.utc(2026, 5, 1),
        end: DateTime.utc(2026, 5, 2),
      );
      expect(result, isEmpty);
    });
  });

  group('EventTypeMeta', () {
    test('returns specific metadata for known types', () {
      final meta = EventTypeMeta.forType('dose_confirmed');
      expect(meta.label, 'Dose taken');
      expect(meta.icon, isNotNull);
    });

    test('falls back to neutral System event for unknown types', () {
      final meta = EventTypeMeta.forType('totally_made_up_event_xyz');
      expect(meta.label, 'System event');
    });

    test('orderedKnown lists sos_triggered first (highest priority)', () {
      expect(EventTypeMeta.orderedKnown.first.key, 'sos_triggered');
    });

    test('all known types resolve to non-null icons', () {
      for (final entry in EventTypeMeta.orderedKnown) {
        expect(entry.value.icon, isNotNull,
            reason: 'icon missing for ${entry.key}');
      }
    });
  });
}
