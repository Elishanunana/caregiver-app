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
  static const _keyPharmacistPin = 'pharmacist_pin';
  static const _keyHubSimNumber  = 'hub_sim_number';
  static const _keyPairedFlag = 'paired_flag';

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
    await _storage.delete(key: _keyPharmacistPin);
    await _storage.delete(key: _keyHubSimNumber);
    await _storage.delete(key: _keyPairedFlag);
  }

  /// Persist the four-digit pharmacist PIN. Stored encrypted at rest.
  /// Section 3.5.5 of the project report specifies this gate as a
  /// protection against unauthorised modification of the schedule.
  Future<void> setPharmacistPin(String pin) =>
      _storage.write(key: _keyPharmacistPin, value: pin);

  /// Read the configured PIN. Returns null if no PIN has been set yet,
  /// in which case the Pharmacist Entry screen runs the first-time
  /// setup flow.
  Future<String?> getPharmacistPin() =>
      _storage.read(key: _keyPharmacistPin);

  /// True if a PIN has been configured. Convenience for the UI gate.
  Future<bool> hasPharmacistPin() async {
    final pin = await getPharmacistPin();
    return pin != null && pin.isNotEmpty;
  }

  /// Persist the hub's GSM module phone number. The Pharmacist Entry
  /// flow uses this as the SMS recipient. In a real deployment this is
  /// captured during pairing; for development we let the caregiver set
  /// it manually alongside the pairing token.
  Future<void> setHubSimNumber(String number) =>
      _storage.write(key: _keyHubSimNumber, value: number);

  /// Read the hub's GSM phone number.
  /// Falls back to a clearly-fake placeholder so a forgotten setup is
  /// obvious to the demo audience rather than failing silently.
  Future<String> getHubSimNumber() async {
    return await _storage.read(key: _keyHubSimNumber) ??
        '+233000000000'; // placeholder — see SettingsScreen.
  }

  /// True if the device has completed a successful pairing.
  /// False on first install or after a reset/re-pair action.
  Future<bool> isPaired() async {
    return await _storage.read(key: _keyPairedFlag) == 'true';
  }

  /// Mark the device as successfully paired. Set only after the pairing
  /// flow has verified the credentials against the live hub.
  Future<void> markPaired() =>
      _storage.write(key: _keyPairedFlag, value: 'true');
}
