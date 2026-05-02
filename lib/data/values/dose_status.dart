/// Per-schedule dose status for a given day.
///
/// Computed by correlating MedicationSchedule records against the day's
/// EventLog entries (Section 3.5.5 of the project report). The four
/// states match the visible status badges on the Today's Overview
/// screen and are deliberately small to keep the rendering logic
/// trivial.
enum DoseStatus {
  /// The scheduled time has not yet arrived. Render as a neutral
  /// "Pending" chip — no urgency, no action needed.
  pending,

  /// A reminder fired and the elder confirmed the dose. Render as a
  /// green "Taken" chip with a check icon.
  taken,

  /// A reminder fired three times without confirmation; the hub
  /// recorded a definitive missed-dose event. Render as a red
  /// "Missed" chip — the most attention-getting state on the screen.
  missed,

  /// The scheduled time has passed but neither a confirmation nor a
  /// definitive missed-dose event has been observed. Render as an
  /// amber "Awaiting" chip — the elder may still confirm.
  awaiting,
}

/// Display label for each status. Kept here, not in the screen, so
/// any future locale work can swap in translated labels by entity.
extension DoseStatusLabel on DoseStatus {
  String get label {
    switch (this) {
      case DoseStatus.pending:  return 'Pending';
      case DoseStatus.taken:    return 'Taken';
      case DoseStatus.missed:   return 'Missed';
      case DoseStatus.awaiting: return 'Awaiting';
    }
  }
}
