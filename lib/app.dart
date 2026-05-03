import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/elder_profile_repository.dart';
import 'data/repositories/event_log_repository.dart';
import 'data/repositories/medication_schedule_repository.dart';
import 'data/repositories/sync_queue_repository.dart';
import 'screens/settings_screen.dart';
import 'screens/today_screen.dart';
import 'services/secure_settings_service.dart';
import 'services/sync_state_notifier.dart';
import 'screens/event_history_screen.dart';
import 'screens/pharmacist_entry_screen.dart';
import 'services/sync_engine.dart';

class CaregiverApp extends StatelessWidget {
  final ElderProfileRepository elderRepo;
  final MedicationScheduleRepository scheduleRepo;
  final EventLogRepository eventRepo;
  final SyncQueueRepository syncRepo;
  final SecureSettingsService settings;
  final SyncEngine syncEngine;
  final SyncStateNotifier syncStateNotifier;

  const CaregiverApp({
    super.key,
    required this.elderRepo,
    required this.scheduleRepo,
    required this.eventRepo,
    required this.syncRepo,
    required this.settings,
    required this.syncEngine,
    required this.syncStateNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: syncStateNotifier),
        Provider<SyncEngine>.value(value: syncEngine),
      ],
      child: MaterialApp(
        title: 'Caregiver Companion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20),
            brightness: Brightness.light,
          ),
        ),
        home: _BootstrapScreen(
          elderRepo: elderRepo,
          scheduleRepo: scheduleRepo,
          eventRepo: eventRepo,
          syncRepo: syncRepo,
          settings: settings,
        ),
      ),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  final ElderProfileRepository elderRepo;
  final MedicationScheduleRepository scheduleRepo;
  final EventLogRepository eventRepo;
  final SyncQueueRepository syncRepo;
  final SecureSettingsService settings;

  const _BootstrapScreen({
    required this.elderRepo,
    required this.scheduleRepo,
    required this.eventRepo,
    required this.syncRepo,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final elder = elderRepo.getPrimary();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.health_and_safety_rounded,
                    size: 72, color: colors.primary),
                const SizedBox(height: 20),
                Text('Caregiver Companion',
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('KNUST COE 497',
                    style: text.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 36),
                if (elder != null)
                  Text(
                    'Caring for ${elder.name}',
                    style: text.titleMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 28),
                _LauncherButton(
                  icon: Icons.today_rounded,
                  label: "Today's Overview",
                  isPrimary: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TodayScreen(
                        elderRepo: elderRepo,
                        scheduleRepo: scheduleRepo,
                        eventRepo: eventRepo,
                        settings: settings,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _LauncherButton(
                  icon: Icons.history_rounded,
                  label: 'Event History',
                  isPrimary: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventHistoryScreen(eventRepo: eventRepo),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                _LauncherButton(
                  icon: Icons.local_pharmacy_rounded,
                  label: 'Pharmacist Entry',
                  isPrimary: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PharmacistEntryScreen(
                        elderRepo: elderRepo,
                        scheduleRepo: scheduleRepo,
                        syncRepo: syncRepo,
                        settings: settings,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                _LauncherButton(
                  icon: Icons.settings_rounded,
                  label: 'Hub Connection',
                  isPrimary: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(settings: settings),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LauncherButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _LauncherButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: isPrimary
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            )
          : FilledButton.tonalIcon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
    );
  }
}
