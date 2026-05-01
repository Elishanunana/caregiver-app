import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repositories/elder_profile_repository.dart';
import 'data/repositories/event_log_repository.dart';
import 'data/repositories/medication_schedule_repository.dart';
import 'data/repositories/sync_queue_repository.dart';
import 'utils/dev_seeder.dart';
import 'utils/hive_initializer.dart';

/// Application entry point.
///
/// Boot sequence:
///   1. Initialise Flutter platform bindings.
///   2. Open the local Hive store (HiveInitializer.init).
///   3. Construct the repository layer.
///   4. Seed development data on a fresh install.
///   5. Mount the app with the repositories injected.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInitializer.init();

  // Repository layer — single instances per process, injected into the app.
  final elderRepo    = ElderProfileRepository();
  final scheduleRepo = MedicationScheduleRepository();
  final eventRepo    = EventLogRepository();
  final syncRepo     = SyncQueueRepository();

  // Dev-only: load representative data on first launch so screens have
  // content to render before the REST integration (Task 17+) is live.
  final seeder = DevSeeder(
    elderRepo: elderRepo,
    scheduleRepo: scheduleRepo,
    eventRepo: eventRepo,
    syncRepo: syncRepo,
  );
  final didSeed = await seeder.seedIfEmpty();
  if (didSeed) {
    debugPrint('[boot] Dev seed loaded on fresh install.');
  }

  runApp(CaregiverApp(
    elderRepo: elderRepo,
    scheduleRepo: scheduleRepo,
    eventRepo: eventRepo,
    syncRepo: syncRepo,
  ));
}
