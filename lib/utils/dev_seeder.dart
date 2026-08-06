import '../data/entities/elder_profile.dart';
import '../data/entities/event_log_entry.dart';
import '../data/entities/medication_schedule.dart';
import '../data/repositories/elder_profile_repository.dart';
import '../data/repositories/event_log_repository.dart';
import '../data/repositories/medication_schedule_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../data/values/values.dart';

/// Development-only seeder.
///
/// Populates the four Hive boxes with a realistic, defense-presentable
/// dataset so screens can be built and reviewed before/alongside the
/// REST sync integration.
///
/// The seed represents one elderly Ghanaian woman in Kumasi — Maame Akua
/// Owusu — managing hypertension (Amlodipine) and mild cognitive
/// impairment (Donepezil), with one adult child registered as caregiver.
/// This mirrors the hub's cleaned demo dataset exactly (same elder,
/// same two medications, same caregiver number) so the app and hub tell
/// one coherent story during the defense.
///
/// IMPORTANT: This seeder is invoked only when the elder profiles box
/// is empty (i.e., on a fresh install during development), or explicitly
/// via reseed(). It is never called in production builds.
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
  /// reset the app to a known state. Clears only the Hive data boxes —
  /// secure settings (pairing token, hub URL, hub SIM) are untouched.
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
      name: 'Maame Akua Owusu',
      language: 'twi',
      caregiverPhones: '+233200510903',
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
        dosage: '5mg',
        timeDue: '08:00',
        daysOfWeek: 'DAILY',
        active: 1,
        prescribedBy: PrescribedBy.pharmacist,
        syncMethod: SyncMethod.appWifi,
        lastModified: now,
      ),
      MedicationSchedule(
        scheduleId: 102,
        elderId: 1,
        drugName: 'Donepezil',
        dosage: '5mg',
        timeDue: '20:00',
        daysOfWeek: 'DAILY',
        active: 1,
        prescribedBy: PrescribedBy.pharmacist,
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

    final sosAt = at(14, 0);
    final ackAt = sosAt.add(const Duration(seconds: 3));

    final events = <EventLogEntry>[
      EventLogEntry(
        eventId: 5001,
        eventType: 'reminder_dose_due',
        timestamp: at(8, 0).toIso8601String(),
        details: 'Amlodipine 5mg',
        syncedFlag: 1,
      ),
      EventLogEntry(
        eventId: 5002,
        eventType: 'dose_confirmed',
        timestamp: at(8, 2).toIso8601String(),
        details: 'Amlodipine 5mg',
        syncedFlag: 1,
      ),
      EventLogEntry(
        eventId: 5003,
        eventType: 'sos_triggered',
        timestamp: sosAt.toIso8601String(),
        details: '{"source":"button","triggered_at":"${sosAt.toIso8601String()}"}',
        syncedFlag: 1,
        transport: SyncTransport.sms, // SMS fallback
      ),
      EventLogEntry(
        eventId: 5004,
        eventType: 'sos_acknowledged',
        timestamp: ackAt.toIso8601String(),
        details: '{"sos_event_id":5003,"acknowledged_at":"${ackAt.toIso8601String()}"}',
        syncedFlag: 1,
        transport: SyncTransport.sms, // SMS fallback
      ),
      EventLogEntry(
        eventId: 5005,
        eventType: 'reminder_dose_due',
        timestamp: at(20, 0).toIso8601String(),
        details: 'Donepezil 5mg',
        syncedFlag: 1,
      ),
      EventLogEntry(
        eventId: 5006,
        eventType: 'dose_missed',
        timestamp: at(20, 30).toIso8601String(),
        details: 'Donepezil 5mg — no confirmation after 3 prompts',
        syncedFlag: 1,
        transport: SyncTransport.sms, // SMS fallback
      ),
    ];

    for (final e in events) {
      await _eventRepo.insertFromHub(e);
    }
  }

  String _utcNowIso() => DateTime.now().toUtc().toIso8601String();
}
