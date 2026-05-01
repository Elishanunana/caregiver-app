import 'package:flutter/material.dart';

import 'data/repositories/elder_profile_repository.dart';
import 'data/repositories/event_log_repository.dart';
import 'data/repositories/medication_schedule_repository.dart';
import 'data/repositories/sync_queue_repository.dart';

/// Root application widget.
///
/// For Task 16, this renders an updated bootstrap screen that displays
/// live counts from each repository — proof that the seeder ran and
/// the data layer is functioning end-to-end. Subsequent tasks replace
/// this scaffold with the real navigation tree.
class CaregiverApp extends StatelessWidget {
  final ElderProfileRepository elderRepo;
  final MedicationScheduleRepository scheduleRepo;
  final EventLogRepository eventRepo;
  final SyncQueueRepository syncRepo;

  const CaregiverApp({
    super.key,
    required this.elderRepo,
    required this.scheduleRepo,
    required this.eventRepo,
    required this.syncRepo,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      ),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  final ElderProfileRepository elderRepo;
  final MedicationScheduleRepository scheduleRepo;
  final EventLogRepository eventRepo;

  const _BootstrapScreen({
    required this.elderRepo,
    required this.scheduleRepo,
    required this.eventRepo,
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
                Icon(
                  Icons.health_and_safety_rounded,
                  size: 72,
                  color: colors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Caregiver Companion',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'KNUST COE 497',
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                _StatusChip(
                  label: 'Local store ready',
                  icon: Icons.check_circle_rounded,
                  colors: colors,
                ),
                const SizedBox(height: 12),
                if (elder != null) ...[
                  _DataCard(
                    elderName: elder.name,
                    scheduleCount: scheduleRepo.count,
                    eventCount: eventRepo.count,
                    colors: colors,
                    text: text,
                  ),
                ] else
                  _StatusChip(
                    label: 'No elder profile yet',
                    icon: Icons.person_off_rounded,
                    colors: colors,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme colors;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  final String elderName;
  final int scheduleCount;
  final int eventCount;
  final ColorScheme colors;
  final TextTheme text;

  const _DataCard({
    required this.elderName,
    required this.scheduleCount,
    required this.eventCount,
    required this.colors,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded,
                  color: colors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                elderName,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _statRow(
            icon: Icons.medication_rounded,
            label: 'Schedules',
            value: '$scheduleCount',
          ),
          const SizedBox(height: 6),
          _statRow(
            icon: Icons.history_rounded,
            label: 'Events',
            value: '$eventCount',
          ),
        ],
      ),
    );
  }

  Widget _statRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label, style: text.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}
