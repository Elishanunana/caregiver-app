import 'package:flutter/foundation.dart';

/// Outcome of the most-recent sync attempt.
enum SyncOutcome {
  /// No sync has run yet in this app session.
  neverSynced,

  /// Sync completed successfully — hub reachable, events applied/acked.
  success,

  /// Sync was skipped — hub was unreachable.
  skipped,

  /// Sync was in cooldown after a recent failure.
  cooldown,

  /// Sync failed mid-pass with an unexpected error.
  error,
}

/// Publishes sync-related events the UI reacts to.
///
/// Used by Today's Overview to show "Last synced 2 minutes ago", to flip
/// a spinner during in-flight pull-to-refresh, and to communicate sync
/// outcomes via snackbars when the user manually triggers a sync.
class SyncStateNotifier extends ChangeNotifier {
  DateTime?    _lastSyncAt;
  SyncOutcome  _lastOutcome     = SyncOutcome.neverSynced;
  String?      _lastErrorMessage;
  int          _lastApplied     = 0;
  int          _lastSkipped     = 0;
  bool         _syncing         = false;

  DateTime?    get lastSyncAt        => _lastSyncAt;
  SyncOutcome  get lastOutcome       => _lastOutcome;
  String?      get lastErrorMessage  => _lastErrorMessage;
  int          get lastApplied       => _lastApplied;
  int          get lastSkipped       => _lastSkipped;
  bool         get isSyncing         => _syncing;

  /// Convenience for the Today's Overview footer.
  String get statusLabel {
    switch (_lastOutcome) {
      case SyncOutcome.neverSynced: return 'Never synced';
      case SyncOutcome.success:     return 'Synced';
      case SyncOutcome.skipped:     return 'Hub unreachable';
      case SyncOutcome.cooldown:    return 'Cooling down';
      case SyncOutcome.error:       return 'Sync failed';
    }
  }

  void beginSync() {
    _syncing = true;
    notifyListeners();
  }

  void endSync({
    required SyncOutcome outcome,
    int applied = 0,
    int skipped = 0,
    String? errorMessage,
  }) {
    _syncing = false;
    _lastSyncAt = DateTime.now();
    _lastOutcome = outcome;
    _lastApplied = applied;
    _lastSkipped = skipped;
    _lastErrorMessage = errorMessage;
    notifyListeners();
  }
}
