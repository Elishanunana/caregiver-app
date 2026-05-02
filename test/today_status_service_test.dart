import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:caregiver_app/core/constants/hive_boxes.dart';
import 'package:caregiver_app/data/entities/elder_profile.dart';
import 'package:caregiver_app/data/entities/event_log_entry.dart';
import 'package:caregiver_app/data/entities/medication_schedule.dart';
import 'package:caregiver_app/data/entities/sync_queue_entry.dart';
import 'package:caregiver_app/data/repositories/event_log_repository.dart';
import 'package:caregiver_app/data/repositories/medication_schedule_repository.dart';
import 'package:caregiver_app/data/values/dose_status.dart';
import 'package:caregiver_app/services/today_status_service.dart';

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

Future<void> _tearDownHive() async => await Hive.deleteFromDisk();

String _isoAt(DateTime day, int h, int m) {
  final t = DateTime(day.year, day.month, day.day, h, m);
  return t.toIso8601String();
}

void main() {
  late MedicationScheduleRepository scheduleRepo;
  late EventLogRepository eventRepo;
  late TodayStatusService service;
  late DateTime today;

  setUp(() async {
    await _setUpHive();
    scheduleRepo = MedicationScheduleRepository();
    eventRepo = EventLogRepository();
    service = TodayStatusService(
      scheduleRepo: scheduleRepo,
      eventRepo: eventRepo,
    );
    today = DateTime.now();
  });
  tearDown(_tearDownHive);

  Future<void> _addSchedule(int id, String drug, String dose, String time,
      {String days = 'DAILY'}) async {
    await scheduleRepo.upsert(MedicationSchedule(
      scheduleId: id,
      elderId: 1,
      drugName: drug,
      dosage: dose,
      timeDue: time,
      daysOfWeek: days,
      active: 1,
    ));
  }

  Future<void> _addEvent(int id, String type, String details, int h, int m) async {
    await eventRepo.insertFromHub(EventLogEntry(
      eventId: id,
      eventType: type,
      timestamp: _isoAt(today, h, m),
      details: details,
      syncedFlag: 1,
    ));
  }

  test('confirmed dose is reported as Taken', () async {
    await _addSchedule(1, 'Amlodipine', '5 mg', '07:30');
    await _addEvent(100, 'reminder_dose_due', 'Amlodipine 5 mg', 7, 30);
    await _addEvent(101, 'dose_confirmed', 'Amlodipine 5 mg', 7, 32);

    final rows = service.computeRows(elderId: 1, forDate: today);
    expect(rows.length, 1);
    expect(rows.first.status, DoseStatus.taken);
  });

  test('definitive missed dose is reported as Missed', () async {
    await _addSchedule(1, 'Metformin', '500 mg', '08:00');
    await _addEvent(100, 'reminder_dose_due', 'Metformin 500 mg', 8, 0);
    await _addEvent(101, 'dose_missed',
        'Metformin 500 mg — no confirmation after 3 prompts', 8, 30);

    final rows = service.computeRows(elderId: 1, forDate: today);
    expect(rows.first.status, DoseStatus.missed);
  });

  test('reminder fired but no resolution → Awaiting', () async {
    await _addSchedule(1, 'Diclofenac', '50 mg', '13:00');
    await _addEvent(100, 'reminder_dose_due', 'Diclofenac 50 mg', 13, 0);

    final rows = service.computeRows(elderId: 1, forDate: today);
    expect(rows.first.status, DoseStatus.awaiting);
  });

  test('no related events → Pending', () async {
    await _addSchedule(1, 'Lisinopril', '10 mg', '20:00');

    final rows = service.computeRows(elderId: 1, forDate: today);
    expect(rows.first.status, DoseStatus.pending);
  });

  test('row order is by timeDue ascending', () async {
    await _addSchedule(1, 'B', '1 mg', '20:00');
    await _addSchedule(2, 'A', '1 mg', '07:00');
    final rows = service.computeRows(elderId: 1, forDate: today);
    expect(rows.map((r) => r.schedule.drugName).toList(), ['A', 'B']);
  });

  test('schedules with daysOfWeek that exclude today are filtered out',
      () async {
    // Compute the day-of-week opposite to today's.
    const shortNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final todayName = shortNames[(today.weekday - 1).clamp(0, 6)];
    final excludingToday = shortNames.where((d) => d != todayName).join(',');

    await _addSchedule(1, 'OnlyOtherDays', '1 mg', '07:00',
        days: excludingToday);
    final rows = service.computeRows(elderId: 1, forDate: today);
    expect(rows, isEmpty);
  });
}
