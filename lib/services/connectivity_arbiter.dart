import 'hub_api_client.dart';

/// The arbiter's verdict on whether sync should be attempted.
enum ArbiterVerdict {
  /// Hub is reachable; proceed with sync over Wi-Fi REST.
  proceedWifi,

  /// Hub is not reachable — skip this cycle. SMS-pathway dispatch is
  /// reserved for explicit user actions (Pharmacist Entry), not used
  /// for routine bulk sync (per Section 3.5.4: "this pathway is
  /// reserved for high-priority schedule and configuration updates
  /// rather than bulk historical synchronisation").
  skip,

  /// Sync attempt was made too recently — back off.
  cooldown,
}

/// Decides whether a sync attempt should proceed at any given moment.
///
/// Implements the report's pathway-aware sync policy (Section 3.5.4):
///   • Wi-Fi REST is the preferred channel for bulk synchronisation.
///   • The SMS pathway is reserved for explicit, high-priority
///     transmissions (e.g., pharmacist-entered schedules) and is NOT
///     used for routine event polling.
///   • A cooldown prevents thundering-herd retries when the hub is
///     consistently unreachable.
class ConnectivityArbiter {
  /// Minimum interval between two failed-attempt cycles.
  /// After a failure, we back off for this long before trying again.
  static const Duration failureCooldown = Duration(seconds: 15);

  /// Last attempt timestamp + outcome, for cooldown enforcement.
  DateTime? _lastFailureAt;

  /// Decide whether to attempt sync now.
  ///
  /// [client] is used to probe /health — a fast, auth-free sanity check
  /// that the hub is reachable before we commit to the full pull-and-ack
  /// roundtrip.
  Future<ArbiterVerdict> shouldSync(HubApiClient client) async {
    if (_lastFailureAt != null) {
      final since = DateTime.now().difference(_lastFailureAt!);
      if (since < failureCooldown) {
        return ArbiterVerdict.cooldown;
      }
    }

    final health = await client.checkHealth();
    if (!health.isHealthy) {
      _lastFailureAt = DateTime.now();
      return ArbiterVerdict.skip;
    }

    // Reset failure timer on a healthy probe.
    _lastFailureAt = null;
    return ArbiterVerdict.proceedWifi;
  }

  /// Reset the cooldown timer manually (e.g., when the user pulls
  /// to refresh — the user explicitly wants a fresh attempt).
  void clearCooldown() {
    _lastFailureAt = null;
  }
}
