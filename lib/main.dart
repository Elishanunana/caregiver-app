import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/repositories/elder_profile_repository.dart';
import 'data/repositories/event_log_repository.dart';
import 'data/repositories/medication_schedule_repository.dart';
import 'data/repositories/sync_queue_repository.dart';
import 'services/app_lifecycle_sync_controller.dart';
import 'services/connectivity_arbiter.dart';
import 'services/secure_settings_service.dart';
import 'services/sync_engine.dart';
import 'services/sync_state_notifier.dart';
import 'utils/dev_seeder.dart';
import 'utils/hive_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInitializer.init();

  // Force portrait — the app is designed for one-handed use; landscape
  // is a stale orientation that adds no value for a monitoring app.
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp]);

  final elderRepo    = ElderProfileRepository();
  final scheduleRepo = MedicationScheduleRepository();
  final eventRepo    = EventLogRepository();
  final syncRepo     = SyncQueueRepository();
  final settings     = SecureSettingsService();

  final seeder = DevSeeder(
    elderRepo: elderRepo,
    scheduleRepo: scheduleRepo,
    eventRepo: eventRepo,
    syncRepo: syncRepo,
  );
  if (await seeder.seedIfEmpty()) {
    debugPrint('[boot] Dev seed loaded on fresh install.');
  }

  // Sync subsystem — constructed once, lives for the app's lifetime.
  final stateNotifier = SyncStateNotifier();
  final arbiter       = ConnectivityArbiter();
  final syncEngine    = SyncEngine(
    settings: settings,
    eventRepo: eventRepo,
    syncRepo: syncRepo,
    arbiter: arbiter,
    stateNotifier: stateNotifier,
  );
  final lifecycleController =
      AppLifecycleSyncController(engine: syncEngine);
  lifecycleController.register();

  runApp(CaregiverApp(
    elderRepo: elderRepo,
    scheduleRepo: scheduleRepo,
    eventRepo: eventRepo,
    syncRepo: syncRepo,
    settings: settings,
    syncEngine: syncEngine,
    syncStateNotifier: stateNotifier,
  ));
}
