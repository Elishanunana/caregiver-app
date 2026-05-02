import '../data/entities/event_log_entry.dart';
import '../data/entities/medication_schedule.dart';
import '../data/repositories/event_log_repository.dart';
import '../data/repositories/medication_schedule_repository.dart';
import '../data/values/dose_status.dart';

/// Correlates today's medication schedules with today's event log to
/// produce a DoseStatus for each scheduled dose.
///
/// The hub emits opaque event-type strings (Section 3.5.2). We treat
/// them as wire literals here; if the hub's taxonomy evolves we update
/// these constants in one place. Mirrors the same loose-coupling
/// philosophy as the EventLogRepository's listByType.
class TodayStatusService {
  // Hub-emitted event_type literals we correlate against. Changing
  // these without updating the hub's emitter would silently break the
  // status display — covered by unit tests.
  static const String _evtReminderDue   = 'reminder_dose_due';
  static const String _evtDoseConfirmed = 'dose_confirmed';
  static const String _evtDoseMissed    = 'dose_missed';

  final MedicationScheduleRepository _scheduleRepo;
  final EventLogRepository _eventRepo;

  TodayStatusService({
    required MedicationScheduleRepository scheduleRepo,
    required EventLogRepository eventRepo,
  })  : _scheduleRepo = scheduleRepo,
        _eventRepo = eventRepo;

  /// One row per active schedule for [elderId], scheduled-time-ascending.
  /// Each row pairs the schedule with its computed status for [forDate].
  List<TodayRow> computeRows({required int elderId, required DateTime forDate}) {
    final schedules = _scheduleRepo.listActiveByElder(elderId);
    final todaysEvents = _eventsForDay(forDate);

    return schedules
        .where((s) => _isScheduledOn(s, forDate))
        .map((s) => TodayRow(
              schedule: s,
              status: _computeStatus(s, todaysEvents, forDate),
            ))
        .toList(growable: false);
  }

  // ──────────────────────────────────────────────────────────────────

  /// All events on the given day, in chronological order.
  List<EventLogEntry> _eventsForDay(DateTime day) {
    final dayKey = _yyyymmdd(day);
    return _eventRepo
        .listAll()
        .where((e) {
          final ts = e.timestamp;
          if (ts == null || ts.isEmpty) return false;
          return ts.startsWith(dayKey);
        })
        .toList(growable: false)
      ..sort((a, b) => (a.timestamp ?? '').compareTo(b.timestamp ?? ''));
  }

  /// True if [s] is scheduled to run on [date].
  /// Honors `daysOfWeek = 'DAILY'` and the comma-separated MON,TUE,...
  /// short-name format used by the hub's seeder (Section 3.5.3).
  bool _isScheduledOn(MedicationSchedule s, DateTime date) {
    final dow = s.daysOfWeek.trim().toUpperCase();
    if (dow.isEmpty || dow == 'DAILY') return true;
    final shortNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final today = shortNames[(date.weekday - 1).clamp(0, 6)];
    return dow.split(',').map((d) => d.trim()).contains(today);
  }

  DoseStatus _computeStatus(
    MedicationSchedule s,
    List<EventLogEntry> dayEvents,
    DateTime forDate,
  ) {
    // Match events to this schedule by drug-name+dosage substring in
    // the details field. The hub's reminder emitter writes details as
    // "<drug> <dosage>" (e.g., "Amlodipine 5 mg") — we tolerate any
    // trailing diagnostic text such as "no confirmation after 3 prompts".
    final tag = '${s.drugName} ${s.dosage}'.trim();
    final related = dayEvents
        .where((e) => (e.details ?? '').contains(tag))
        .toList(growable: false);

    final hasConfirmed = related.any((e) => e.eventType == _evtDoseConfirmed);
    if (hasConfirmed) return DoseStatus.taken;

    final hasMissed = related.any((e) => e.eventType == _evtDoseMissed);
    if (hasMissed) return DoseStatus.missed;

    final hasReminder = related.any((e) => e.eventType == _evtReminderDue);
    if (hasReminder) return DoseStatus.awaiting;

    // No related events yet. If the scheduled time hasn't passed, it's
    // simply Pending; if it has passed without a reminder firing the
    // elder is on the hub's grace window — we keep it Pending until
    // either a reminder fires or the scheduler logs a missed dose.
    final dueToday = _scheduledDateTime(s, forDate);
    if (dueToday == null) return DoseStatus.pending;
    return DoseStatus.pending;
  }

  /// Combine a schedule's HH:MM timeDue with [forDate]. Returns null
  /// if the time string is malformed (defensive — the hub validates
  /// the format on insertion, but the repository accepts any string).
  DateTime? _scheduledDateTime(MedicationSchedule s, DateTime forDate) {
    final parts = s.timeDue.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(forDate.year, forDate.month, forDate.day, h, m);
  }

  String _yyyymmdd(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}

/// One renderable row on the Today's Overview screen.
class TodayRow {
  final MedicationSchedule schedule;
  final DoseStatus status;

  const TodayRow({required this.schedule, required this.status});
}
