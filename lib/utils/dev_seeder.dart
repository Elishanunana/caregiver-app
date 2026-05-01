import '../data/entities/elder_profile.dart';
import '../data/entities/event_log_entry.dart';
import '../data/entities/medication_schedule.dart';
import '../data/entities/sync_queue_entry.dart';
import '../data/repositories/elder_profile_repository.dart';
import '../data/repositories/event_log_repository.dart';
import '../data/repositories/medication_schedule_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../data/values/values.dart';

/// Development-only seeder.
///
/// Populates the four Hive boxes with a realistic, defense-presentable
/// dataset so screens can be built and reviewed before the REST sync
/// integration (Task 17 onwards) is live.
///
/// The seed represents one elderly Ghanaian woman in Kumasi — Akua
/// Mensah — managing hypertension, diabetes, and arthritis medications,
/// with two adult children registered as caregivers. The event history
/// reflects a normal day's adherence pattern with one missed dose.
///
/// IMPORTANT: This seeder is invoked only when the elder profiles box
/// is empty (i.e., on a fresh install during development). It is never
/// called in production builds. We will gate this behind a compile-time
/// flag in Task 22.
class DevSeeder {
  final ElderProfileRepository _elderRepo;
  final MedicationScheduleRepository _scheduleRepo;
  final EventLogRepository _eventRepo;
  final SyncQueueRepository _syncRepo;

  DevSeeder({
    required ElderProfileRepository elderRepo,
    required MedicationScheduleRepository scheduleRepo,
    required EventLogRepository eventRepo,
    required SyncQueueRepository syncRepo,
  })  : _elderRepo = elderRepo,
        _scheduleRepo = scheduleRepo,
        _eventRepo = eventRepo,
        _syncRepo = syncRepo;

  /// Seed the local store with development data.
  /// No-op if the elder profiles box is already populated.
  Future<bool> seedIfEmpty() async {
    if (!_elderRepo.isEmpty) return false;
    await _seedElder();
    await _seedSchedules();
    await _seedEvents();
    return true;
  }

  /// Wipe and reseed unconditionally. Useful during development to
  /// reset the app to a known state.
  Future<void> reseed() async {
    await _elderRepo.clear();
    await _scheduleRepo.clear();
    await _eventRepo.clear();
    await _syncRepo.clear();
    await _seedElder();
    await _seedSchedules();
    await _seedEvents();
  }

  Future<void> _seedElder() async {
    final now = _utcNowIso();
    await _elderRepo.upsert(ElderProfile(
      elderId: 1,
      name: 'Akua Mensah',
      language: 'twi',
      caregiverPhones: '+233244000001,+233244000002',
      createdAt: now,
      lastModified: now,
    ));
  }

  Future<void> _seedSchedules() async {
    final now = _utcNowIso();
    final schedules = <MedicationSchedule>[
      MedicationSchedule(
        scheduleId: 101,
        elderId: 1,
        drugName: 'Amlodipine',
        dosage: '5 mg',
        timeDue: '07:30',
        daysOfWeek: 'DAILY',
        active: 1,
        prescribedBy: PrescribedBy.pharmacist,
        syncMethod: SyncMethod.appWifi,
        lastModified: now,
      ),
      MedicationSchedule(
        scheduleId: 102,
        elderId: 1,
        drugName: 'Metformin',
        dosage: '500 mg',
        timeDue: '08:00',
        daysOfWeek: 'DAILY',
        active: 1,
        prescribedBy: PrescribedBy.pharmacist,
        syncMethod: SyncMethod.appWifi,
        lastModified: now,
      ),
      MedicationSchedule(
        scheduleId: 103,
        elderId: 1,
        drugName: 'Metformin',
        dosage: '500 mg',
        timeDue: '20:00',
        daysOfWeek: 'DAILY',
        active: 1,
        prescribedBy: PrescribedBy.pharmacist,
        syncMethod: SyncMethod.appWifi,
        lastModified: now,
      ),
      MedicationSchedule(
        scheduleId: 104,
        elderId: 1,
        drugName: 'Diclofenac',
        dosage: '50 mg',
        timeDue: '13:00',
        daysOfWeek: 'MON,WED,FRI',
        active: 1,
        prescribedBy: PrescribedBy.caregiver,
        syncMethod: SyncMethod.appWifi,
        lastModified: now,
      ),
    ];

    for (final s in schedules) {
      await _scheduleRepo.upsert(s);
    }
  }

  Future<void> _seedEvents() async {
    final today = DateTime.now().toUtc();
    DateTime at(int h, int m) =>
        DateTime.utc(today.year, today.month, today.day, h, m);

    final events = <EventLogEntry>[
      EventLogEntry(
        eventId: 5001,
        eventType: 'reminder_dose_due',
        timestamp: at(7, 30).toIso8601String(),
        details: 'Amlodipine 5 mg',
        syncedFlag: 1,
      ),
      EventLogEntry(
        eventId: 5002,
        eventType: 'dose_confirmed',
        timestamp: at(7, 32).toIso8601String(),
        details: 'Amlodipine 5 mg',
        syncedFlag: 1,
      ),
      EventLogEntry(
        eventId: 5003,
        eventType: 'reminder_dose_due',
        timestamp: at(8, 0).toIso8601String(),
        details: 'Metformin 500 mg',
        syncedFlag: 1,
      ),
      EventLogEntry(
        eventId: 5004,
        eventType: 'dose_missed',
        timestamp: at(8, 30).toIso8601String(),
        details: 'Metformin 500 mg — no confirmation after 3 prompts',
        syncedFlag: 1,
      ),
      EventLogEntry(
        eventId: 5005,
        eventType: 'reminder_dose_due',
        timestamp: at(13, 0).toIso8601String(),
        details: 'Diclofenac 50 mg',
        syncedFlag: 1,
      ),
      EventLogEntry(
        eventId: 5006,
        eventType: 'dose_confirmed',
        timestamp: at(13, 5).toIso8601String(),
        details: 'Diclofenac 50 mg',
        syncedFlag: 1,
      ),
    ];

    for (final e in events) {
      await _eventRepo.insertFromHub(e);
    }
  }

  String _utcNowIso() => DateTime.now().toUtc().toIso8601String();
}
