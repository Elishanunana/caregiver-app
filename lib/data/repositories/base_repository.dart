import 'package:hive/hive.dart';

/// Base contract for all local repositories.
///
/// Mirrors the shape of the hub's `BaseRepository` (Python) but adapted
/// for Hive's box-based storage model. Each concrete subclass binds to
/// a single Hive box and exposes typed CRUD operations.
///
/// The generic parameter [T] is the Hive-persisted entity type. All such
/// entities extend HiveObject, which gives them a `key` property managed
/// by Hive itself (do not confuse with our domain-level IDs like
/// `scheduleId` or `eventId`).
abstract class BaseRepository<T extends HiveObject> {
  /// Name of the Hive box this repository operates on.
  /// Must be one of the constants in `HiveBoxes`.
  String get boxName;

  /// The underlying Hive box, looked up on each access.
  /// Hive caches box references internally, so this is effectively free.
  Box<T> get box => Hive.box<T>(boxName);

  /// Number of records currently stored.
  int get count => box.length;

  /// True if the box has no records.
  bool get isEmpty => box.isEmpty;

  /// Iterate all records in insertion order.
  /// For ordered queries use the entity-specific helpers in subclasses.
  List<T> listAll() => box.values.toList(growable: false);

  /// Remove every record. Used by the dev seeder and by tests.
  /// Never call this on a production device — there is no recovery.
  Future<void> clear() => box.clear();
}
