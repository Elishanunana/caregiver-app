import '../../core/constants/hive_boxes.dart';
import '../entities/medication_schedule.dart';
import '../values/values.dart';
import 'base_repository.dart';

/// Repository for medication schedule records.
///
/// Schedules can originate from three sources, tracked via `prescribedBy`:
///   • caregiver  — manually entered by the caregiver
///   • pharmacist — entered through the PIN-secured pharmacist mode
///   • hub_local  — created on the hub (rare; usually the elder asking
///                  the hub to add a schedule via voice)
///
/// And arrive via three pathways, tracked via `syncMethod`:
///   • app_wifi  — pushed from app to hub over Wi-Fi REST
///   • app_sms   — pushed from app to hub via SMS payload (remote case)
///   • hub_local — originated on the hub itself (Hub→App sync direction)
class MedicationScheduleRepository extends BaseRepository<MedicationSchedule> {
  @override
  String get boxName => HiveBoxes.medicationSchedules;

  /// Find a schedule by its hub-assigned `scheduleId`.
  MedicationSchedule? getById(int scheduleId) {
    return box.values
        .cast<MedicationSchedule?>()
        .firstWhere((s) => s?.scheduleId == scheduleId, orElse: () => null);
  }

  /// All schedules belonging to a particular elder, regardless of active state.
  List<MedicationSchedule> listByElder(int elderId) {
    return box.values
        .where((s) => s.elderId == elderId)
        .toList(growable: false);
  }

  /// Active schedules for an elder, ordered by `timeDue` ascending.
  /// This is the canonical query for the Today's Overview screen.
  List<MedicationSchedule> listActiveByElder(int elderId) {
    final result = box.values
        .where((s) => s.elderId == elderId && s.isActive)
        .toList(growable: true);
    result.sort((a, b) => a.timeDue.compareTo(b.timeDue));
    return result;
  }

  /// Insert or replace a schedule.
  ///
  /// If `scheduleId` is set (record came from the hub), it is used as the
  /// Hive key — guaranteeing that subsequent updates from the hub overwrite
  /// the same record rather than creating a duplicate.
  ///
  /// If `scheduleId` is null (locally-entered, awaiting hub assignment),
  /// a Hive auto-key is used and the entity is updated in place once
  /// the hub returns its assigned id.
  Future<void> upsert(MedicationSchedule schedule) async {
    if (schedule.scheduleId != null) {
      await box.put(schedule.scheduleId, schedule);
    } else {
      await box.add(schedule);
    }
  }

  /// Soft-delete: mark inactive without removing the record.
  /// Matches the hub's `deactivate` behaviour for clinical traceability.
  Future<bool> deactivate(int scheduleId) async {
    final schedule = getById(scheduleId);
    if (schedule == null) return false;
    schedule.active = 0;
    schedule.lastModified = _utcNowIso();
    await schedule.save();
    return true;
  }

  /// Convenience builder for a pharmacist-entered schedule.
  /// Always sets `prescribedBy = pharmacist` and `syncMethod = appSms`
  /// (or `appWifi` if explicitly overridden).
  MedicationSchedule buildPharmacistEntry({
    required int elderId,
    required String drugName,
    required String dosage,
    required String timeDue,
    String daysOfWeek = 'DAILY',
    String syncMethod = SyncMethod.appSms,
  }) {
    return MedicationSchedule(
      scheduleId: null, // hub will assign on receipt
      elderId: elderId,
      drugName: drugName,
      dosage: dosage,
      timeDue: timeDue,
      daysOfWeek: daysOfWeek,
      active: 1,
      prescribedBy: PrescribedBy.pharmacist,
      syncMethod: syncMethod,
      lastModified: _utcNowIso(),
    );
  }

  /// UTC ISO-8601 with millisecond precision, matching the hub's format.
  String _utcNowIso() {
    final now = DateTime.now().toUtc();
    return now.toIso8601String();
  }
}
