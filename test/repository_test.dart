import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:caregiver_app/core/constants/hive_boxes.dart';
import 'package:caregiver_app/data/entities/elder_profile.dart';
import 'package:caregiver_app/data/entities/event_log_entry.dart';
import 'package:caregiver_app/data/entities/medication_schedule.dart';
import 'package:caregiver_app/data/entities/sync_queue_entry.dart';
import 'package:caregiver_app/data/repositories/elder_profile_repository.dart';
import 'package:caregiver_app/data/repositories/event_log_repository.dart';
import 'package:caregiver_app/data/repositories/medication_schedule_repository.dart';
import 'package:caregiver_app/data/repositories/sync_queue_repository.dart';
import 'package:caregiver_app/data/values/values.dart';
import 'package:caregiver_app/utils/dev_seeder.dart';

/// In-memory Hive setup for repository tests.
/// No platform plugins, no emulator — pure Dart.
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
  group('ElderProfileRepository', () {
    late ElderProfileRepository repo;

    setUp(() async {
      await _setUpHive();
      repo = ElderProfileRepository();
    });
    tearDown(_tearDownHive);

    test('upsert and getById round-trip', () async {
      await repo.upsert(ElderProfile(elderId: 7, name: 'Test'));
      expect(repo.getById(7)?.name, 'Test');
    });

    test('getPrimary returns first profile', () async {
      await repo.upsert(ElderProfile(elderId: 1, name: 'A'));
      expect(repo.getPrimary()?.elderId, 1);
    });
  });

  group('MedicationScheduleRepository', () {
    late MedicationScheduleRepository repo;

    setUp(() async {
      await _setUpHive();
      repo = MedicationScheduleRepository();
    });
    tearDown(_tearDownHive);

    test('listActiveByElder is sorted by timeDue ascending', () async {
      await repo.upsert(MedicationSchedule(
          scheduleId: 1, elderId: 1, drugName: 'B', timeDue: '20:00'));
      await repo.upsert(MedicationSchedule(
          scheduleId: 2, elderId: 1, drugName: 'A', timeDue: '07:00'));
      final result = repo.listActiveByElder(1);
      expect(result.map((s) => s.drugName).toList(), ['A', 'B']);
    });

    test('deactivate sets active=0 and bumps last_modified', () async {
      await repo.upsert(MedicationSchedule(
          scheduleId: 5, elderId: 1, drugName: 'X', active: 1));
      final ok = await repo.deactivate(5);
      expect(ok, isTrue);
      expect(repo.getById(5)?.active, 0);
      expect(repo.getById(5)?.lastModified, isNotNull);
    });

    test('buildPharmacistEntry stamps the right metadata', () {
      final s = repo.buildPharmacistEntry(
        elderId: 1,
        drugName: 'Amlodipine',
        dosage: '5 mg',
        timeDue: '07:30',
      );
      expect(s.prescribedBy, PrescribedBy.pharmacist);
      expect(s.syncMethod, SyncMethod.appSms);
      expect(s.scheduleId, isNull); // hub assigns later
    });
  });

  group('EventLogRepository', () {
    late EventLogRepository repo;

    setUp(() async {
      await _setUpHive();
      repo = EventLogRepository();
    });
    tearDown(_tearDownHive);

    test('insertFromHub requires eventId', () async {
      expect(
        () => repo.insertFromHub(EventLogEntry(eventType: 'x')),
        throwsArgumentError,
      );
    });

    test('insertFromHub is idempotent on duplicate eventId', () async {
      await repo.insertFromHub(EventLogEntry(
          eventId: 100, eventType: 'a', timestamp: '2026-01-01T00:00:00Z'));
      await repo.insertFromHub(EventLogEntry(
          eventId: 100, eventType: 'a', timestamp: '2026-01-01T00:00:00Z'));
      expect(repo.count, 1);
    });

    test('listNewestFirst orders by timestamp descending', () async {
      await repo.insertFromHub(EventLogEntry(
          eventId: 1, eventType: 'a', timestamp: '2026-01-01T08:00:00Z'));
      await repo.insertFromHub(EventLogEntry(
          eventId: 2, eventType: 'b', timestamp: '2026-01-01T10:00:00Z'));
      final result = repo.listNewestFirst();
      expect(result.first.eventId, 2);
      expect(result.last.eventId, 1);
    });
  });

  group('SyncQueueRepository', () {
    late SyncQueueRepository repo;

    setUp(() async {
      await _setUpHive();
      repo = SyncQueueRepository();
    });
    tearDown(_tearDownHive);

    test('insert rejects empty changeId', () async {
      expect(
        () => repo.insert(SyncQueueEntry()),
        throwsArgumentError,
      );
    });

    test('updateState rejects invalid sync state', () async {
      expect(
        () => repo.updateState('any', 'bogus'),
        throwsArgumentError,
      );
    });

    test('updateState increments attempts on failed transition', () async {
      await repo.insert(SyncQueueEntry(
        changeId: 'cid-1',
        entityType: 'MedicationSchedule',
        entityId: 1,
        changeType: ChangeType.insert,
        syncState: SyncState.pending,
        direction: SyncDirection.appToHub,
        transport: SyncTransport.sms,
      ));
      await repo.updateState('cid-1', SyncState.failed);
      expect(repo.getByChangeId('cid-1')?.attempts, 1);
    });

    test('listPendingAppToHub filters correctly', () async {
      await repo.insert(SyncQueueEntry(
        changeId: 'a',
        syncState: SyncState.pending,
        direction: SyncDirection.appToHub,
      ));
      await repo.insert(SyncQueueEntry(
        changeId: 'b',
        syncState: SyncState.synced,
        direction: SyncDirection.appToHub,
      ));
      await repo.insert(SyncQueueEntry(
        changeId: 'c',
        syncState: SyncState.pending,
        direction: SyncDirection.hubToApp,
      ));
      final result = repo.listPendingAppToHub();
      expect(result.length, 1);
      expect(result.first.changeId, 'a');
    });
  });

  group('DevSeeder', () {
    late DevSeeder seeder;
    late ElderProfileRepository elderRepo;
    late MedicationScheduleRepository scheduleRepo;
    late EventLogRepository eventRepo;
    late SyncQueueRepository syncRepo;

    setUp(() async {
      await _setUpHive();
      elderRepo = ElderProfileRepository();
      scheduleRepo = MedicationScheduleRepository();
      eventRepo = EventLogRepository();
      syncRepo = SyncQueueRepository();
      seeder = DevSeeder(
        elderRepo: elderRepo,
        scheduleRepo: scheduleRepo,
        eventRepo: eventRepo,
        syncRepo: syncRepo,
      );
    });
    tearDown(_tearDownHive);

    test('seedIfEmpty populates all four boxes on a fresh store', () async {
      final didSeed = await seeder.seedIfEmpty();
      expect(didSeed, isTrue);
      expect(elderRepo.count, 1);
      expect(scheduleRepo.count, 4);
      expect(eventRepo.count, 8);
      expect(elderRepo.getPrimary()?.name, 'Akua Mensah');
    });

    test('seedIfEmpty is no-op when elder profile already present', () async {
      await elderRepo.upsert(ElderProfile(elderId: 99, name: 'Existing'));
      final didSeed = await seeder.seedIfEmpty();
      expect(didSeed, isFalse);
      expect(scheduleRepo.count, 0); // no schedules added
    });
  });
}
