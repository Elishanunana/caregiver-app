import 'package:flutter/widgets.dart';

/// In-memory session-scoped record of whether the pharmacist PIN has
/// been unlocked during the current foreground session.
///
/// Lifecycle policy (chosen for the geriatric-care use case):
///   • Unlock survives across rebuilds, navigation, and tab switches
///     within a single foreground session.
///   • Unlock is cleared automatically when the app is backgrounded.
///   • Unlock does not persist across process death (we never write it
///     to disk — the SecureSettingsService still owns the PIN itself).
///
/// Section 3.5.5 of the project report requires the PIN gate to
/// "prevent accidental edits and protect against unauthorised
/// modification of the schedule." Re-prompting on every State
/// recreation overshoots that goal — a memory-pressure activity
/// recreation is not an unauthorised access. Re-prompting on
/// backgrounding strikes the right balance.
///
/// This class implements WidgetsBindingObserver so the lifecycle hook
/// is self-contained — register() once at construction, dispose()
/// when the owning widget tears down.
class PinSessionService with WidgetsBindingObserver {
  bool _unlocked = false;

  /// True if the current session has unlocked the pharmacist PIN.
  bool get isUnlocked => _unlocked;

  /// Mark the session as unlocked. Called after a successful PIN entry.
  void markUnlocked() {
    _unlocked = true;
  }

  /// Force the session locked. Called automatically on backgrounding;
  /// also exposed for explicit "lock now" actions in future.
  void lock() {
    _unlocked = false;
  }

  /// Begin observing app lifecycle transitions. Call once.
  void register() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stop observing. Call from the owning widget's dispose().
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Any transition out of the foreground locks the session. The
    // user re-authenticates with the PIN when they return to the
    // Pharmacist tab.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        lock();
        break;
      case AppLifecycleState.resumed:
        // No-op — resume doesn't re-unlock; the user must enter the
        // PIN again.
        break;
    }
  }
}
