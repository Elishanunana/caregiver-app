import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/entities/event_log_entry.dart';
import '../data/repositories/elder_profile_repository.dart';
import '../data/repositories/event_log_repository.dart';
import '../data/repositories/medication_schedule_repository.dart';
import '../data/values/dose_status.dart';
import '../services/hub_api_client.dart';
import '../services/secure_settings_service.dart';
import '../services/sync_state_notifier.dart';
import '../services/today_status_service.dart';

/// Today's Overview — the caregiver's daily glance at the elder's
/// medication adherence and any unacknowledged emergencies.
///
/// Screen anatomy (top → bottom):
///   1. App bar with elder's name and a manual refresh action.
///   2. SOS banner — visible only when there is an unacknowledged
///      sos_triggered event in the EventLog. Designed to be the
///      single most prominent thing on the screen when present.
///   3. Schedule list — one row per active schedule for the day,
///      ordered by timeDue ascending, with a status badge per row.
///   4. Last-sync footer — small metadata strip showing the last
///      successful sync timestamp.
///
/// Pull-to-refresh hits /health on the configured hub. A real hub
/// pull (events/unsynced + ack) is wired in Task 21; for Task 18 we
/// only verify reachability so the user sees a recent timestamp.
class TodayScreen extends StatefulWidget {
  final ElderProfileRepository elderRepo;
  final MedicationScheduleRepository scheduleRepo;
  final EventLogRepository eventRepo;
  final SecureSettingsService settings;

  const TodayScreen({
    super.key,
    required this.elderRepo,
    required this.scheduleRepo,
    required this.eventRepo,
    required this.settings,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final TodayStatusService _statusService;

  @override
  void initState() {
    super.initState();
    _statusService = TodayStatusService(
      scheduleRepo: widget.scheduleRepo,
      eventRepo: widget.eventRepo,
    );
  }

  Future<void> _refresh() async {
    final notifier = context.read<SyncStateNotifier>();
    notifier.beginSync();

    final url   = await widget.settings.getHubUrl();
    final token = await widget.settings.getPairingToken();
    final client = HubApiClient(baseUrl: url, pairingToken: token);
    final result = await client.checkHealth();
    client.close();

    notifier.endSync(
      ok: result.isHealthy,
      message: result.errorMessage,
    );

    if (!mounted) return;
    if (!result.isHealthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Sync failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text   = Theme.of(context).textTheme;

    final elder = widget.elderRepo.getPrimary();
    if (elder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Today's Overview")),
        body: const Center(child: Text('No elder profile registered.')),
      );
    }

    final today = DateTime.now();
    final rows = _statusService.computeRows(
      elderId: elder.elderId ?? 0,
      forDate: today,
    );
    final pendingSos = _findUnackSos();

    return Scaffold(
      appBar: AppBar(
        title: Text("Today — ${elder.name}"),
        actions: [
          Consumer<SyncStateNotifier>(
            builder: (_, n, __) => IconButton(
              icon: n.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: 'Sync with hub',
              onPressed: n.isSyncing ? null : _refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            if (pendingSos != null)
              _SosBanner(event: pendingSos, colors: colors, text: text),
            _SectionHeader(label: _todayHeader(today), text: text),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No medications scheduled for today.'),
              )
            else
              ...rows.map((r) =>
                  _ScheduleTile(row: r, colors: colors, text: text)),
            const SizedBox(height: 24),
            _LastSyncFooter(),
          ],
        ),
      ),
    );
  }

  EventLogEntry? _findUnackSos() {
    final all = widget.eventRepo.listAll();
    final sosEvents = all.where((e) => e.eventType == 'sos_triggered').toList();
    if (sosEvents.isEmpty) return null;
    sosEvents.sort((a, b) =>
        (b.timestamp ?? '').compareTo(a.timestamp ?? ''));
    return sosEvents.first; // most recent; ack mechanism comes in Task 21
  }

  String _todayHeader(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return 'Today — ${d.day} ${months[d.month - 1]}';
  }
}

// ── Banner: unacknowledged SOS ─────────────────────────────────────

class _SosBanner extends StatelessWidget {
  final EventLogEntry event;
  final ColorScheme colors;
  final TextTheme text;

  const _SosBanner({
    required this.event,
    required this.colors,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: colors.onErrorContainer, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOS — Unacknowledged',
                  style: text.titleMedium?.copyWith(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.timestamp ?? 'no timestamp',
                  style: text.bodySmall?.copyWith(
                    color: colors.onErrorContainer.withValues(alpha: 0.8),
                    fontFamily: 'monospace',
                  ),
                ),
                if (event.details != null && event.details!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.details!,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final TextTheme text;

  const _SectionHeader({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Text(
        label,
        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Schedule tile ──────────────────────────────────────────────────

class _ScheduleTile extends StatelessWidget {
  final TodayRow row;
  final ColorScheme colors;
  final TextTheme text;

  const _ScheduleTile({
    required this.row,
    required this.colors,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Time
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              row.schedule.timeDue,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Drug + dosage
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.schedule.drugName,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                Text(row.schedule.dosage,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusBadge(status: row.status, colors: colors),
        ],
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final DoseStatus status;
  final ColorScheme colors;

  const _StatusBadge({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    final spec = _spec(colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 14, color: spec.fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: spec.fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeSpec _spec(ColorScheme c) {
    switch (status) {
      case DoseStatus.taken:
        return _BadgeSpec(
          bg: c.primaryContainer,
          fg: c.onPrimaryContainer,
          icon: Icons.check_rounded,
        );
      case DoseStatus.missed:
        return _BadgeSpec(
          bg: c.errorContainer,
          fg: c.onErrorContainer,
          icon: Icons.close_rounded,
        );
      case DoseStatus.awaiting:
        return _BadgeSpec(
          bg: c.tertiaryContainer,
          fg: c.onTertiaryContainer,
          icon: Icons.hourglass_bottom_rounded,
        );
      case DoseStatus.pending:
        return _BadgeSpec(
          bg: c.surfaceContainerHigh,
          fg: c.onSurfaceVariant,
          icon: Icons.schedule_rounded,
        );
    }
  }
}

class _BadgeSpec {
  final Color bg;
  final Color fg;
  final IconData icon;
  const _BadgeSpec({required this.bg, required this.fg, required this.icon});
}

// ── Last-sync footer ───────────────────────────────────────────────

class _LastSyncFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Consumer<SyncStateNotifier>(
      builder: (_, n, __) {
        final ts = n.lastSyncAt;
        final label = ts == null
            ? 'Never synced'
            : 'Last synced at ${_fmt(ts)} (${n.lastSyncResult ?? "—"})';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.cloud_sync_rounded,
                  size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
