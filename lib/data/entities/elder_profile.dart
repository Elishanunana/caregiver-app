import 'package:hive/hive.dart';

import '../../core/constants/hive_type_ids.dart';

part 'elder_profile.g.dart';

/// Mirrors `ElderProfile` from the hub's `data_management/repositories.py`.
///
/// All field positions, types, and JSON keys match the backend's SQLite
/// schema and REST contract to guarantee bidirectional sync correctness
/// across both transport pathways (Wi-Fi REST, SMS payload).
@HiveType(typeId: HiveTypeIds.elderProfile)
class ElderProfile extends HiveObject {
  @HiveField(0)
  int? elderId;

  @HiveField(1)
  String name;

  @HiveField(2)
  String language;

  @HiveField(3)
  String caregiverPhones;        // Comma-separated list

  @HiveField(4)
  String? createdAt;             // ISO-8601 UTC

  @HiveField(5)
  String? lastModified;          // ISO-8601 UTC

  ElderProfile({
    this.elderId,
    this.name = '',
    this.language = 'twi',
    this.caregiverPhones = '',
    this.createdAt,
    this.lastModified,
  });

  /// Construct from the JSON shape the hub's REST API returns.
  factory ElderProfile.fromJson(Map<String, dynamic> json) => ElderProfile(
        elderId: json['elder_id'] as int?,
        name: (json['name'] as String?) ?? '',
        language: (json['language'] as String?) ?? 'twi',
        caregiverPhones: (json['caregiver_phones'] as String?) ?? '',
        createdAt: json['created_at'] as String?,
        lastModified: json['last_modified'] as String?,
      );

  /// Serialize to the JSON shape the hub's REST API expects.
  Map<String, dynamic> toJson() => {
        'elder_id': elderId,
        'name': name,
        'language': language,
        'caregiver_phones': caregiverPhones,
        'created_at': createdAt,
        'last_modified': lastModified,
      };
}
