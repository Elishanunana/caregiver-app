import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:caregiver_app/core/constants/hive_boxes.dart';
import 'package:caregiver_app/data/entities/elder_profile.dart';
import 'package:caregiver_app/data/entities/event_log_entry.dart';
import 'package:caregiver_app/data/entities/medication_schedule.dart';
import 'package:caregiver_app/data/entities/sync_queue_entry.dart';
import 'package:caregiver_app/data/repositories/event_log_repository.dart';
import 'package:caregiver_app/data/repositories/sync_queue_repository.dart';
import 'package:caregiver_app/data/values/values.dart';
import 'package:caregiver_app/services/hub_to_app_applier.dart';

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
  await Hive.close();
  try {
    await Hive.deleteFromDisk();
  } catch (_) {}
}

void main() {
  group('HubToAppApplier', () {
    late EventLogRepository eventRepo;
    late SyncQueueRepository syncRepo;
    late HubToAppApplier applier;

    setUp(() async {
      await _setUpHive();
      eventRepo = EventLogRepository();
      syncRepo  = SyncQueueRepository();
      applier   = HubToAppApplier(eventRepo: eventRepo, syncRepo: syncRepo);
    });
    tearDown(_tearDownHive);

    test('inserts new events and queues their IDs for ack', () async {
      final result = await applier.applyBatch([
        {
          'event_id': 1,
          'event_type': 'reminder_dose_due',
          'timestamp': '2026-05-01T08:00:00.000Z',
          'details': {'drug_name': 'Amlodipine'},
        },
        {
          'event_id': 2,
          'event_type': 'dose_confirmed',
          'timestamp': '2026-05-01T08:02:00.000Z',
          'details': {'drug_name': 'Amlodipine'},
        },
      ]);

      expect(result.inserted, 2);
      expect(result.skipped, 0);
      expect(result.ackEventIds, [1, 2]);
      expect(eventRepo.getById(1)?.eventType, 'reminder_dose_due');
      expect(eventRepo.getById(2)?.syncedFlag, 1);
    });

    test('skips already-applied events but still queues them for ack',
        () async {
      // Pre-populate event 5.
      await eventRepo.insertFromHub(EventLogEntry(
        eventId: 5,
        eventType: 'sos_triggered',
        timestamp: '2026-05-01T09:00:00.000Z',
      ));

      final result = await applier.applyBatch([
        {
          'event_id': 5,
          'event_type': 'sos_triggered',
          'timestamp': '2026-05-01T09:00:00.000Z',
        },
        {
          'event_id': 6,
          'event_type': 'dose_missed',
          'timestamp': '2026-05-01T09:30:00.000Z',
        },
      ]);

      expect(result.inserted, 1);
      expect(result.skipped, 1);
      expect(result.ackEventIds, [5, 6],
          reason: 'Skipped events still ack — re-acks are harmless.');
    });

    test('serialises object details to JSON string for storage', () async {
      await applier.applyBatch([
        {
          'event_id': 10,
          'event_type': 'sos_dispatch_complete',
          'timestamp': '2026-05-01T10:00:00.000Z',
          'details': {
            'recipients_ok': 2,
            'sos_event_id': 9,
          },
        },
      ]);

      final stored = eventRepo.getById(10);
      expect(stored, isNotNull);
      expect(stored!.details, contains('"recipients_ok":2'));
      expect(stored.details, contains('"sos_event_id":9'));
    });

    test('marks App→Hub sync queue entry synced when ack arrives',
        () async {
      // Pre-populate an App→Hub change awaiting ack.
      await syncRepo.insert(SyncQueueEntry(
        changeId: 'c-123',
        entityType: 'MedicationSchedule',
        entityId: 1,
        changeType: ChangeType.insert,
        syncState: SyncState.pending,
        direction: SyncDirection.appToHub,
        transport: SyncTransport.sms,
        payload: 'MED|...',
      ));

      // Hub sends back an ack event.
      await applier.applyBatch([
        {
          'event_id': 99,
          'event_type': 'sms_payload_accepted',
          'timestamp': '2026-05-01T11:00:00.000Z',
          'details': {
            'ack_for_change_id': 'c-123',
            'schedule_id': 1,
            'ack': true,
          },
        },
      ]);

      expect(syncRepo.getByChangeId('c-123')?.syncState, SyncState.synced);
    });

    test('event with null details stores null', () async {
      await applier.applyBatch([
        {
          'event_id': 50,
          'event_type': 'system_boot',
          'timestamp': '2026-05-01T07:00:00.000Z',
          'details': null,
        },
      ]);

      expect(eventRepo.getById(50)?.details, isNull);
    });

    test('skips records missing event_id without raising', () async {
      final result = await applier.applyBatch([
        {'event_type': 'foo'}, // missing event_id
        {
          'event_id': 100,
          'event_type': 'reminder_dose_due',
          'timestamp': '2026-05-01T12:00:00.000Z',
        },
      ]);
      expect(result.inserted, 1);
      expect(result.ackEventIds, [100]);
    });
  });
}
