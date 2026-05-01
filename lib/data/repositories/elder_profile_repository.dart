import '../../core/constants/hive_boxes.dart';
import '../entities/elder_profile.dart';
import 'base_repository.dart';

/// Repository for elder identity records.
///
/// In the typical deployment, the app holds exactly one ElderProfile —
/// the elder being cared for. The repository is structured to support
/// multiple profiles for forward compatibility (e.g., a caregiver
/// supporting multiple elderly parents on a single device).
class ElderProfileRepository extends BaseRepository<ElderProfile> {
  @override
  String get boxName => HiveBoxes.elderProfiles;

  /// Find a profile by its hub-assigned `elderId`.
  /// Returns null if no matching record exists.
  ElderProfile? getById(int elderId) {
    return box.values
        .cast<ElderProfile?>()
        .firstWhere((p) => p?.elderId == elderId, orElse: () => null);
  }

  /// Return the single primary profile, or null if none registered yet.
  /// Convenience for the typical single-elder deployment.
  ElderProfile? getPrimary() {
    return box.values.isEmpty ? null : box.values.first;
  }

  /// Insert or replace a profile.
  /// Uses `elderId` as the Hive key when present, otherwise a Hive
  /// auto-key (`add`).
  Future<void> upsert(ElderProfile profile) async {
    if (profile.elderId != null) {
      await box.put(profile.elderId, profile);
    } else {
      await box.add(profile);
    }
  }
}
