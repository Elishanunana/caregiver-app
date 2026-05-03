import 'package:flutter/material.dart';

import '../data/repositories/elder_profile_repository.dart';
import '../data/repositories/event_log_repository.dart';
import '../data/repositories/medication_schedule_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../services/secure_settings_service.dart';
import 'event_history_screen.dart';
import 'pharmacist_entry_screen.dart';
import 'today_screen.dart';

/// Main app shell after pairing is complete.
///
/// Three tabs: Today / History / Pharmacist. Hub Connection is reached
/// via a settings icon in the app bar (it's not a primary surface — most
/// caregivers visit it once during pairing and rarely afterwards).
class MainScaffold extends StatefulWidget {
  final ElderProfileRepository elderRepo;
  final MedicationScheduleRepository scheduleRepo;
  final EventLogRepository eventRepo;
  final SyncQueueRepository syncRepo;
  final SecureSettingsService settings;

  const MainScaffold({
    super.key,
    required this.elderRepo,
    required this.scheduleRepo,
    required this.eventRepo,
    required this.syncRepo,
    required this.settings,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      TodayScreen(
        elderRepo: widget.elderRepo,
        scheduleRepo: widget.scheduleRepo,
        eventRepo: widget.eventRepo,
        settings: widget.settings,
      ),
      EventHistoryScreen(
        eventRepo: widget.eventRepo,
        settings: widget.settings,
      ),

      PharmacistEntryScreen(
        elderRepo: widget.elderRepo,
        scheduleRepo: widget.scheduleRepo,
        syncRepo: widget.syncRepo,
        settings: widget.settings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_outlined),
            selectedIcon: Icon(Icons.local_pharmacy_rounded),
            label: 'Pharmacist',
          ),
        ],
      ),
    );
  }
}
