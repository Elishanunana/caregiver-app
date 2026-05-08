import 'package:flutter/material.dart';

/// Display metadata for hub-emitted event_type strings.
///
/// The hub sends opaque snake_case identifiers (e.g., 'dose_confirmed').
/// This module is the single place we map those strings to caregiver-
/// facing labels, semantic icons, and accent colors.
///
/// Unknown event types fall through to a neutral "System event" label
/// rather than throwing — the hub may emit new event types in future
/// firmware versions and the app should degrade gracefully.
class EventTypeMeta {
  final String label;
  final IconData icon;
  final _AccentRole accentRole;
  final bool defaultVisible;

  const EventTypeMeta._({
    required this.label,
    required this.icon,
    required this.accentRole,
    this.defaultVisible = true,
  });

  /// Resolve [colors] for this event type. Kept as a method so theme
  /// changes (e.g., dark mode) propagate without rebuilding the lookup.
  Color accentColor(ColorScheme colors) {
    switch (accentRole) {
      case _AccentRole.success: return colors.primary;
      case _AccentRole.danger:  return colors.error;
      case _AccentRole.warn:    return colors.tertiary;
      case _AccentRole.neutral: return colors.onSurfaceVariant;
    }
  }

  Color accentBackground(ColorScheme colors) {
    switch (accentRole) {
      case _AccentRole.success: return colors.primaryContainer;
      case _AccentRole.danger:  return colors.errorContainer;
      case _AccentRole.warn:    return colors.tertiaryContainer;
      case _AccentRole.neutral: return colors.surfaceContainerHigh;
    }
  }

  Color accentForeground(ColorScheme colors) {
    switch (accentRole) {
      case _AccentRole.success: return colors.onPrimaryContainer;
      case _AccentRole.danger:  return colors.onErrorContainer;
      case _AccentRole.warn:    return colors.onTertiaryContainer;
      case _AccentRole.neutral: return colors.onSurfaceVariant;
    }
  }

  /// All event types with first-class display support, in the order
  /// they should appear in filter UIs (most actionable first).
  static const List<MapEntry<String, EventTypeMeta>> orderedKnown = [
    // ─── Caregiver-relevant (visible by default) ───
    MapEntry('sos_triggered', EventTypeMeta._(
      label: 'SOS triggered',
      icon: Icons.warning_amber_rounded,
      accentRole: _AccentRole.danger,
    )),
    MapEntry('dose_missed', EventTypeMeta._(
      label: 'Dose missed',
      icon: Icons.cancel_rounded,
      accentRole: _AccentRole.danger,
    )),
    MapEntry('dose_confirmed', EventTypeMeta._(
      label: 'Dose taken',
      icon: Icons.check_circle_rounded,
      accentRole: _AccentRole.success,
    )),
    MapEntry('reminder_dose_due', EventTypeMeta._(
      label: 'Reminder fired',
      icon: Icons.notifications_active_rounded,
      accentRole: _AccentRole.warn,
    )),
    MapEntry('appliance_command', EventTypeMeta._(
      label: 'Appliance command',
      icon: Icons.lightbulb_outline_rounded,
      accentRole: _AccentRole.neutral,
    )),
    MapEntry('power_state_change', EventTypeMeta._(
      label: 'Power state change',
      icon: Icons.power_rounded,
      accentRole: _AccentRole.neutral,
    )),

    // ─── System / diagnostic (hidden by default — opt-in via filter) ───
    MapEntry('system_boot', EventTypeMeta._(
      label: 'Hub started',
      icon: Icons.power_settings_new_rounded,
      accentRole: _AccentRole.neutral,
      defaultVisible: false,
    )),
    MapEntry('system_shutdown', EventTypeMeta._(
      label: 'Hub stopped',
      icon: Icons.power_off_rounded,
      accentRole: _AccentRole.neutral,
      defaultVisible: false,
    )),
    MapEntry('system_fault', EventTypeMeta._(
      label: 'Hub fault',
      icon: Icons.error_outline_rounded,
      accentRole: _AccentRole.danger,
      defaultVisible: false,
    )),
    MapEntry('tts_repeated', EventTypeMeta._(
      label: 'Prompt repeated',
      icon: Icons.replay_rounded,
      accentRole: _AccentRole.neutral,
      defaultVisible: false,
    )),
    MapEntry('schedule_read_aloud', EventTypeMeta._(
      label: 'Schedule read aloud',
      icon: Icons.record_voice_over_rounded,
      accentRole: _AccentRole.neutral,
      defaultVisible: false,
    )),
    MapEntry('sos_dispatch_complete', EventTypeMeta._(
      label: 'SOS dispatch result',
      icon: Icons.send_rounded,
      accentRole: _AccentRole.warn,
      defaultVisible: false,
    )),
    MapEntry('sos_acknowledged', EventTypeMeta._(
      label: 'SOS acknowledged',
      icon: Icons.task_alt_rounded,
      accentRole: _AccentRole.success,
      defaultVisible: false,
    )),
    MapEntry('sms_payload_accepted', EventTypeMeta._(
      label: 'SMS accepted',
      icon: Icons.sms_rounded,
      accentRole: _AccentRole.neutral,
      defaultVisible: false,
    )),
    MapEntry('sms_payload_rejected', EventTypeMeta._(
      label: 'SMS rejected',
      icon: Icons.sms_failed_rounded,
      accentRole: _AccentRole.danger,
      defaultVisible: false,
    )),
    MapEntry('sms_outbound_dispatched', EventTypeMeta._(
      label: 'SMS sent to caregivers',
      icon: Icons.outbox_rounded,
      accentRole: _AccentRole.neutral,
      defaultVisible: false,
    )),
    MapEntry('schedule_synced_via_wifi', EventTypeMeta._(
      label: 'Schedule synced',
      icon: Icons.cloud_done_rounded,
      accentRole: _AccentRole.neutral,
      defaultVisible: false,
    )),
  ];

  /// Keys that should be enabled in the History filter on first display.
  static Set<String> get defaultVisibleKeys =>
      orderedKnown
          .where((e) => e.value.defaultVisible)
          .map((e) => e.key)
          .toSet();

  static const EventTypeMeta _unknown = EventTypeMeta._(
    label: 'System event',
    icon: Icons.event_note_rounded,
    accentRole: _AccentRole.neutral,
  );

  /// Look up display metadata for an event_type string.
  /// Falls back to a neutral "System event" for unknown types.
  static EventTypeMeta forType(String eventType) {
    for (final entry in orderedKnown) {
      if (entry.key == eventType) return entry.value;
    }
    return _unknown;
  }
}

enum _AccentRole { success, danger, warn, neutral }
