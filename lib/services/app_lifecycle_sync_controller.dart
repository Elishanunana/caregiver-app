import 'package:flutter/widgets.dart';

import 'sync_engine.dart';

/// Wires the SyncEngine to the app lifecycle.
///
/// Lifecycle policy:
///   • App becomes foregrounded (resumed) → start the engine.
///   • App is paused / backgrounded / detached → stop the engine.
///
/// This implements the "lifecycle-aware" sync trigger model described
/// in Section 3.5.4 of the project report: the engine runs only when
/// the caregiver is actively using the app, conserving battery and
/// avoiding ghost background activity.
class AppLifecycleSyncController with WidgetsBindingObserver {
  final SyncEngine engine;

  AppLifecycleSyncController({required this.engine});

  void register() {
    WidgetsBinding.instance.addObserver(this);
    // Start immediately — we are already in resumed state when app
    // boots. The SyncEngine.start() runs an initial cycle right away.
    engine.start();
  }

  void unregister() {
    WidgetsBinding.instance.removeObserver(this);
    engine.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        engine.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        engine.stop();
        break;
    }
  }
}
