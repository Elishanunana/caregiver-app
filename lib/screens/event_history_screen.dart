import 'package:flutter/material.dart';

import '../data/entities/event_log_entry.dart';
import '../data/repositories/event_log_repository.dart';
import '../data/values/event_type_meta.dart';
import '../data/values/values.dart';
import '../services/secure_settings_service.dart';
import '_app_bar_actions.dart';
/// Event History — a chronological, filterable audit log of all events
/// the app has received from the hub.
///
/// Section 3.5.5 of the project report calls for this screen to display:
///   • Originating timestamp
///   • Event type
///   • Synchronisation pathway through which the record arrived
///   • Filters by event type and date range
///
/// Day grouping is rendered with sticky headers (Today / Yesterday /
/// "<day> <month>") to make the date axis visible at a glance.
///
/// Per-row transport pathway (Wi-Fi vs SMS) is currently rendered as
/// 'Wi-Fi' for every event because Task 17's HubApiClient is the only
/// pathway feeding events into the local store. Task 21 introduces the
/// SMS pathway and per-event transport tracking; the badge will stay
/// in place and start showing accurate per-event values then.
class EventHistoryScreen extends StatefulWidget {
  final EventLogRepository eventRepo;
  final SecureSettingsService settings;

  const EventHistoryScreen({
    super.key,
    required this.eventRepo,
    required this.settings,
  });

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  Set<String> _enabledTypes = {};
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _enabledTypes = EventTypeMeta.orderedKnown.map((e) => e.key).toSet();
  }

  bool get _isFiltered =>
      _dateRange != null ||
      _enabledTypes.length != EventTypeMeta.orderedKnown.length;

  List<EventLogEntry> _filteredEvents() {
    final all = _dateRange == null
        ? widget.eventRepo.listNewestFirst()
        : widget.eventRepo.listInRange(
            start: _dateRange!.start,
            end: _dateRange!.end.add(const Duration(days: 1)),
          );
    if (_enabledTypes.length == EventTypeMeta.orderedKnown.length) {
      return all;
    }
    return all.where((e) => _enabledTypes.contains(e.eventType)).toList();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        initialTypes: _enabledTypes,
        initialRange: _dateRange,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _enabledTypes = result.types;
      _dateRange = result.range;
    });
  }

  void _clearFilters() {
    setState(() {
      _enabledTypes = EventTypeMeta.orderedKnown.map((e) => e.key).toSet();
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final events = _filteredEvents();
    final groups = _groupByDay(events);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event History'),
        actions: [
          if (_isFiltered)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded),
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: Icon(_isFiltered
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined),
            tooltip: 'Filter',
            onPressed: _openFilters,
          ),
          CommonAppBarActions(settings: widget.settings),
        ],
      ),
      body: events.isEmpty
          ? _EmptyState(isFiltered: _isFiltered, colors: colors, text: text)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: groups.length,
              itemBuilder: (_, i) => _DaySection(
                day: groups[i].day,
                events: groups[i].events,
                colors: colors,
                text: text,
              ),
            ),
    );
  }

  /// Bucket events into per-day groups, preserving newest-first order.
  List<_DayGroup> _groupByDay(List<EventLogEntry> events) {
    final map = <String, List<EventLogEntry>>{};
    for (final e in events) {
      final key = (e.timestamp ?? '').substring(0, 10); // YYYY-MM-DD
      map.putIfAbsent(key, () => []).add(e);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys
        .map((k) => _DayGroup(day: k, events: map[k]!))
        .toList(growable: false);
  }
}

class _DayGroup {
  final String day;
  final List<EventLogEntry> events;
  const _DayGroup({required this.day, required this.events});
}

// ── Day section ────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  final String day;
  final List<EventLogEntry> events;
  final ColorScheme colors;
  final TextTheme text;

  const _DaySection({
    required this.day,
    required this.events,
    required this.colors,
    required this.text,
  });

  String _humanizedDay() {
    if (day.isEmpty || day.length < 10) return 'Unknown date';
    final parts = day.split('-');
    if (parts.length != 3) return day;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return day;
    final date = DateTime(y, m, d);
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final diff = t.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '$d ${months[m - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          color: colors.surface,
          child: Row(
            children: [
              Text(
                _humanizedDay(),
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${events.length}',
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...events.map((e) =>
            _EventTile(event: e, colors: colors, text: text)),
      ],
    );
  }
}

// ── Event tile ─────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final EventLogEntry event;
  final ColorScheme colors;
  final TextTheme text;

  const _EventTile({
    required this.event,
    required this.colors,
    required this.text,
  });

  String _hhmm(String? ts) {
    if (ts == null || ts.length < 16) return '--:--';
    return ts.substring(11, 16);
  }

  @override
  Widget build(BuildContext context) {
    final meta = EventTypeMeta.forType(event.eventType);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: meta.accentBackground(colors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                meta.icon,
                color: meta.accentForeground(colors),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meta.label,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _hhmm(event.timestamp),
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if ((event.details ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.details!,
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _TransportBadge(transport: SyncTransport.wifiRest, colors: colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transport badge ────────────────────────────────────────────────

class _TransportBadge extends StatelessWidget {
  final String transport;
  final ColorScheme colors;

  const _TransportBadge({required this.transport, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isWifi = transport == SyncTransport.wifiRest;
    final label = isWifi ? 'Wi-Fi' : 'SMS';
    final icon = isWifi ? Icons.wifi_rounded : Icons.sms_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  final ColorScheme colors;
  final TextTheme text;

  const _EmptyState({
    required this.isFiltered,
    required this.colors,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered
                  ? Icons.filter_alt_outlined
                  : Icons.event_note_rounded,
              size: 56,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No events match the filters.' : 'No events yet.',
              style: text.titleMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 6),
              Text(
                "Events will appear here as they sync from the hub.",
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Filter sheet ───────────────────────────────────────────────────

class _FilterResult {
  final Set<String> types;
  final DateTimeRange? range;
  const _FilterResult({required this.types, required this.range});
}

class _FilterSheet extends StatefulWidget {
  final Set<String> initialTypes;
  final DateTimeRange? initialRange;

  const _FilterSheet({
    required this.initialTypes,
    required this.initialRange,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _types;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _types = Set.of(widget.initialTypes);
    _range = widget.initialRange;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Event types',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EventTypeMeta.orderedKnown.map((entry) {
              final selected = _types.contains(entry.key);
              return FilterChip(
                label: Text(entry.value.label),
                avatar: Icon(entry.value.icon, size: 16),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _types.add(entry.key);
                  } else {
                    _types.remove(entry.key);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('Date range',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(_range == null
                      ? 'Any date'
                      : '${_fmtDate(_range!.start)} → ${_fmtDate(_range!.end)}'),
                ),
              ),
              if (_range != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear range',
                  onPressed: () => setState(() => _range = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _FilterResult(types: _types, range: _range),
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
