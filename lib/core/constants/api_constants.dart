/// REST API contract constants.
///
/// These are the wire-level names the hub's `LocalRestAPI` exposes.
/// Mirroring them as constants on the app side avoids stringly-typed
/// path-and-header bugs and gives us a single place to update if the
/// hub's contract evolves.
class ApiConstants {
  // Path prefix
  static const String basePath = '/api/v1';

  // Endpoints (relative to baseUrl + basePath)
  static const String health         = '/health';
  static const String eventsUnsynced = '/events/unsynced';
  static const String eventsAck      = '/events/ack';
  static const String scheduleSync   = '/schedule/sync';

  // Headers
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType   = 'Content-Type';
  static const String contentTypeJson     = 'application/json';

  // Bearer prefix
  static const String bearerPrefix = 'Bearer ';

  // Timeouts
  static const Duration defaultTimeout = Duration(seconds: 8);
  static const Duration healthTimeout  = Duration(seconds: 3);

  // Default values for the dev environment (Android emulator → host loopback).
  static const String defaultHubUrl = 'http://10.0.2.2:5000';
  static const String defaultPairingToken = 'CHANGE_ME_ON_PAIRING';

  ApiConstants._();
}
