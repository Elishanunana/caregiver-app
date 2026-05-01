import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repositories/elder_profile_repository.dart';
import 'data/repositories/event_log_repository.dart';
import 'data/repositories/medication_schedule_repository.dart';
import 'data/repositories/sync_queue_repository.dart';
import 'services/secure_settings_service.dart';
import 'utils/dev_seeder.dart';
import 'utils/hive_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInitializer.init();

  final elderRepo    = ElderProfileRepository();
  final scheduleRepo = MedicationScheduleRepository();
  final eventRepo    = EventLogRepository();
  final syncRepo     = SyncQueueRepository();

  final settings = SecureSettingsService();

  final seeder = DevSeeder(
    elderRepo: elderRepo,
    scheduleRepo: scheduleRepo,
    eventRepo: eventRepo,
    syncRepo: syncRepo,
  );
  if (await seeder.seedIfEmpty()) {
    debugPrint('[boot] Dev seed loaded on fresh install.');
  }

  runApp(CaregiverApp(
    elderRepo: elderRepo,
    scheduleRepo: scheduleRepo,
    eventRepo: eventRepo,
    syncRepo: syncRepo,
    settings: settings,
  ));
}
