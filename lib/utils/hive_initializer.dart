import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/hive_boxes.dart';
import '../data/entities/elder_profile.dart';
import '../data/entities/event_log_entry.dart';
import '../data/entities/medication_schedule.dart';
import '../data/entities/sync_queue_entry.dart';

/// Centralised Hive bootstrap.
///
/// Called once at application startup, before runApp(). Registers all
/// TypeAdapters and opens the four primary boxes that mirror the hub's
/// SQLite tables (Section 3.5.5 of the project report).
///
/// Idempotent — safe to call multiple times. Adapter registration is
/// guarded against duplicates; openBox is a no-op for already-open boxes.
class HiveInitializer {
  /// Initialise Hive, register adapters, and open all boxes.
  static Future<void> init() async {
    await Hive.initFlutter();
    _registerAdapters();
    await _openBoxes();
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ElderProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MedicationScheduleAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(EventLogEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(SyncQueueEntryAdapter());
    }
  }

  static Future<void> _openBoxes() async {
    await Future.wait([
      Hive.openBox<ElderProfile>(HiveBoxes.elderProfiles),
      Hive.openBox<MedicationSchedule>(HiveBoxes.medicationSchedules),
      Hive.openBox<EventLogEntry>(HiveBoxes.eventLogEntries),
      Hive.openBox<SyncQueueEntry>(HiveBoxes.syncQueueEntries),
    ]);
  }

  /// Close all boxes cleanly. Useful for tests and on app shutdown.
  static Future<void> close() async => Hive.close();
}
