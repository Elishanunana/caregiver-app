import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/elder_profile_repository.dart';
import 'data/repositories/event_log_repository.dart';
import 'data/repositories/medication_schedule_repository.dart';
import 'data/repositories/sync_queue_repository.dart';
import 'screens/main_scaffold.dart';
import 'screens/pairing_screen.dart';
import 'services/secure_settings_service.dart';
import 'services/sync_engine.dart';
import 'services/sync_state_notifier.dart';

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
        home: _RootRouter(
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

/// Root-level router. Decides between the pairing flow (first launch
/// or after a Reset) and the main scaffold (paired state).
class _RootRouter extends StatefulWidget {
  final ElderProfileRepository elderRepo;
  final MedicationScheduleRepository scheduleRepo;
  final EventLogRepository eventRepo;
  final SyncQueueRepository syncRepo;
  final SecureSettingsService settings;

  const _RootRouter({
    required this.elderRepo,
    required this.scheduleRepo,
    required this.eventRepo,
    required this.syncRepo,
    required this.settings,
  });

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool? _isPaired;

  @override
  void initState() {
    super.initState();
    _checkPairing();
  }

  Future<void> _checkPairing() async {
    final paired = await widget.settings.isPaired();
    if (!mounted) return;
    setState(() => _isPaired = paired);
  }

  void _onPaired() {
    setState(() => _isPaired = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isPaired == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isPaired == false) {
      return PairingScreen(
        settings: widget.settings,
        onPaired: _onPaired,
      );
    }

    return MainScaffold(
      elderRepo: widget.elderRepo,
      scheduleRepo: widget.scheduleRepo,
      eventRepo: widget.eventRepo,
      syncRepo: widget.syncRepo,
      settings: widget.settings,
    );
  }
}
