import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/api_constants.dart';

/// Persistent store for hub connection credentials.
///
/// Uses Android Keystore (via flutter_secure_storage) so the pairing
/// token is encrypted at rest. The hub URL is also stored here for
/// convenience; in production this would be auto-discovered via the
/// AP's mDNS or DHCP option, but for the dev environment we let the
/// caregiver enter it manually.
///
/// This is intentionally separate from the Hive entity store: a Hive
/// box wipe (e.g., during pharmacist-mode reset) must not lose the
/// device's hub authentication.
class SecureSettingsService {
  static const _keyHubUrl       = 'hub_url';
  static const _keyPairingToken = 'pairing_token';

  final FlutterSecureStorage _storage;

  SecureSettingsService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Persist the hub's base URL (e.g., 'http://10.0.2.2:5000').
  Future<void> setHubUrl(String url) =>
      _storage.write(key: _keyHubUrl, value: url);

  /// Read the configured hub URL, falling back to the dev default.
  Future<String> getHubUrl() async {
    return await _storage.read(key: _keyHubUrl) ??
        ApiConstants.defaultHubUrl;
  }

  /// Persist the pairing token. Stored encrypted at rest.
  Future<void> setPairingToken(String token) =>
      _storage.write(key: _keyPairingToken, value: token);

  /// Read the pairing token, falling back to the dev placeholder.
  Future<String> getPairingToken() async {
    return await _storage.read(key: _keyPairingToken) ??
        ApiConstants.defaultPairingToken;
  }

  /// Wipe both keys. Used when the caregiver re-pairs to a different hub.
  Future<void> reset() async {
    await _storage.delete(key: _keyHubUrl);
    await _storage.delete(key: _keyPairingToken);
  }
}
