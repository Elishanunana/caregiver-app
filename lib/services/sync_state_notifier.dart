import 'package:flutter/foundation.dart';

/// Tiny ChangeNotifier that publishes sync-related events the UI can
/// react to. Used by Today's Overview to show "Last synced 2 minutes
/// ago" and to flip a spinner during in-flight pull-to-refresh.
///
/// Kept deliberately minimal in Task 18 — Task 21 will fold this into
/// the real SyncEngine. For now it just tracks timestamps and a busy
/// flag, both updated manually by whichever screen triggered the sync.
class SyncStateNotifier extends ChangeNotifier {
  DateTime? _lastSyncAt;
  String? _lastSyncResult;
  bool _syncing = false;

  DateTime? get lastSyncAt    => _lastSyncAt;
  String?   get lastSyncResult => _lastSyncResult;
  bool      get isSyncing      => _syncing;

  void beginSync() {
    _syncing = true;
    notifyListeners();
  }

  void endSync({required bool ok, String? message}) {
    _syncing = false;
    _lastSyncAt = DateTime.now();
    _lastSyncResult = ok ? 'ok' : (message ?? 'failed');
    notifyListeners();
  }
}
