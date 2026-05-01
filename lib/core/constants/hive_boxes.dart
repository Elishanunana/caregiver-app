/// Hive box name registry.
///
/// Box names are persisted in the on-disk file structure — renaming a box
/// orphans the existing data. Treat these as immutable identifiers.
class HiveBoxes {
  static const String elderProfiles       = 'elder_profiles';
  static const String medicationSchedules = 'medication_schedules';
  static const String eventLogEntries     = 'event_log_entries';
  static const String syncQueueEntries    = 'sync_queue_entries';

  HiveBoxes._();
}
