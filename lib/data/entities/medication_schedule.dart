import 'package:hive/hive.dart';

import '../../core/constants/hive_type_ids.dart';
import '../values/values.dart';

part 'medication_schedule.g.dart';

/// Mirrors `MedicationSchedule` from the hub's repositories.
///
/// `prescribedBy` and `syncMethod` carry the clinical traceability metadata
/// described in Section 3.5.2 of the project report — they record the
/// origin of each schedule entry (caregiver, pharmacist, or hub-local) and
/// the pathway that delivered it (app_wifi, app_sms, hub_local).
@HiveType(typeId: HiveTypeIds.medicationSchedule)
class MedicationSchedule extends HiveObject {
  @HiveField(0)
  int? scheduleId;

  @HiveField(1)
  int elderId;

  @HiveField(2)
  String drugName;

  @HiveField(3)
  String dosage;

  @HiveField(4)
  String timeDue;       // 'HH:MM' (24-hour)

  @HiveField(5)
  String daysOfWeek;    // 'DAILY' or 'MON,TUE,WED'

  @HiveField(6)
  int active;           // 0 | 1

  @HiveField(7)
  String prescribedBy;  // PrescribedBy.* values

  @HiveField(8)
  String syncMethod;    // SyncMethod.* values

  @HiveField(9)
  String? lastModified; // ISO-8601 UTC

  MedicationSchedule({
    this.scheduleId,
    this.elderId = 0,
    this.drugName = '',
    this.dosage = '',
    this.timeDue = '',
    this.daysOfWeek = 'DAILY',
    this.active = 1,
    this.prescribedBy = PrescribedBy.caregiver,
    this.syncMethod = SyncMethod.hubLocal,
    this.lastModified,
  });

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) =>
      MedicationSchedule(
        scheduleId: json['schedule_id'] as int?,
        elderId: (json['elder_id'] as int?) ?? 0,
        drugName: (json['drug_name'] as String?) ?? '',
        dosage: (json['dosage'] as String?) ?? '',
        timeDue: (json['time_due'] as String?) ?? '',
        daysOfWeek: (json['days_of_week'] as String?) ?? 'DAILY',
        active: (json['active'] as int?) ?? 1,
        prescribedBy: (json['prescribed_by'] as String?) ?? PrescribedBy.caregiver,
        syncMethod: (json['sync_method'] as String?) ?? SyncMethod.hubLocal,
        lastModified: json['last_modified'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'schedule_id': scheduleId,
        'elder_id': elderId,
        'drug_name': drugName,
        'dosage': dosage,
        'time_due': timeDue,
        'days_of_week': daysOfWeek,
        'active': active,
        'prescribed_by': prescribedBy,
        'sync_method': syncMethod,
        'last_modified': lastModified,
      };

  bool get isActive => active == 1;
}
