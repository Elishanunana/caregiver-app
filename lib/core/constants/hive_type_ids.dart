/// Hive TypeAdapter ID registry.
///
/// IDs are an immutable contract — once assigned, never reuse or renumber.
/// Hive uses the typeId to identify which adapter deserializes binary data;
/// renumbering would corrupt every existing local store on upgrade.
class HiveTypeIds {
  static const int elderProfile       = 0;
  static const int medicationSchedule = 1;
  static const int eventLogEntry      = 2;
  static const int syncQueueEntry     = 3;
  // Reserve 4–9 for future entities.

  HiveTypeIds._();
}
