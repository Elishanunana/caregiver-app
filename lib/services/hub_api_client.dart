import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';

/// Result of a connectivity probe against the hub's /health endpoint.
class HealthCheckResult {
  final bool isHealthy;
  final String? apiVersion;
  final String? serverTime;
  final String? errorMessage;

  const HealthCheckResult.healthy({
    required this.apiVersion,
    required this.serverTime,
  })  : isHealthy = true,
        errorMessage = null;

  const HealthCheckResult.unhealthy(this.errorMessage)
      : isHealthy = false,
        apiVersion = null,
        serverTime = null;
}

/// Categorised error type emitted by HubApiClient operations.
///
/// We expose the category, not just a message string, so the UI can
/// render distinct affordances (retry, re-pair, warn caregiver about
/// network) without having to parse error text.
enum HubApiErrorKind {
  /// Hub unreachable — DNS, no route, or connection refused.
  connectionFailed,

  /// Hub responded but took longer than the timeout.
  timeout,

  /// Hub responded with HTTP 401 — pairing token rejected.
  unauthorized,

  /// Hub responded with a 4xx that wasn't 401.
  badRequest,

  /// Hub responded with a 5xx — internal hub fault.
  serverError,

  /// Response body wasn't the expected JSON shape.
  malformedResponse,
}

/// Exception type thrown by all HubApiClient methods.
class HubApiException implements Exception {
  final HubApiErrorKind kind;
  final String message;
  final int? statusCode;

  const HubApiException(this.kind, this.message, {this.statusCode});

  @override
  String toString() => 'HubApiException(${kind.name}): $message'
      '${statusCode != null ? " [HTTP $statusCode]" : ""}';
}

/// Typed REST client for the hub's LocalRestAPI.
///
/// Endpoints (Section 3.5.4 of the project report):
///   GET  /api/v1/health          — connectivity probe (no auth)
///   GET  /api/v1/events/unsynced — pull Hub→App pending events
///   POST /api/v1/events/ack      — acknowledge applied events
///   POST /api/v1/schedule/sync   — push App→Hub schedule changes
///
/// Authentication: every endpoint except /health requires a bearer
/// token in the Authorization header. The token is the device-pairing
/// token established during initial setup.
class HubApiClient {
  final String baseUrl;
  final String pairingToken;
  final http.Client _client;

  HubApiClient({
    required this.baseUrl,
    required this.pairingToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Probe the hub's /health endpoint. Does not require auth.
  /// Returns a HealthCheckResult — never throws.
  Future<HealthCheckResult> checkHealth() async {
    final uri = Uri.parse('$baseUrl${ApiConstants.basePath}${ApiConstants.health}');
    try {
      final response = await _client
          .get(uri)
          .timeout(ApiConstants.healthTimeout);

      if (response.statusCode != 200) {
        return HealthCheckResult.unhealthy(
            'Hub returned HTTP ${response.statusCode}.');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'ok') {
        return HealthCheckResult.unhealthy(
            'Hub reports status=${body['status']}.');
      }

      return HealthCheckResult.healthy(
        apiVersion: body['api_version'] as String?,
        serverTime: body['server_time'] as String?,
      );
    } on TimeoutException {
      return const HealthCheckResult.unhealthy(
          'No response from hub within 3 seconds.');
    } catch (e) {
      return HealthCheckResult.unhealthy('Cannot reach hub: $e');
    }
  }

  /// Pull events the hub has marked as unsynced (Hub→App pathway).
  /// Returns the raw list of event JSON objects; the caller is
  /// responsible for inserting them into EventLogRepository.
  Future<List<Map<String, dynamic>>> fetchUnsyncedEvents() async {
    final uri = Uri.parse(
        '$baseUrl${ApiConstants.basePath}${ApiConstants.eventsUnsynced}');
    final response = await _authenticatedGet(uri);
    final body = _decodeJson(response);
    final list = body['events'];
    if (list is! List) {
      throw const HubApiException(
        HubApiErrorKind.malformedResponse,
        'Expected events array in response body.',
      );
    }
    return list.cast<Map<String, dynamic>>();
  }

  /// Acknowledge events the app has successfully applied.
  /// The hub flips their synced_flag = 1 server-side.
  Future<void> ackEvents(List<int> eventIds) async {
    final uri = Uri.parse(
        '$baseUrl${ApiConstants.basePath}${ApiConstants.eventsAck}');
    await _authenticatedPost(uri, {'event_ids': eventIds});
  }

  /// Push a batch of schedule changes from the app to the hub.
  /// Each entry is an App→Hub SyncQueue payload.
  Future<Map<String, dynamic>> syncScheduleBatch(
      List<Map<String, dynamic>> changes) async {
    final uri = Uri.parse(
        '$baseUrl${ApiConstants.basePath}${ApiConstants.scheduleSync}');
    final response = await _authenticatedPost(uri, {'changes': changes});
    return _decodeJson(response);
  }

  // ─────────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────────

  Map<String, String> get _authHeaders => {
        ApiConstants.headerContentType: ApiConstants.contentTypeJson,
        ApiConstants.headerAuthorization:
            '${ApiConstants.bearerPrefix}$pairingToken',
      };

  Future<http.Response> _authenticatedGet(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: _authHeaders)
          .timeout(ApiConstants.defaultTimeout);
      return _checkStatus(response);
    } on TimeoutException {
      throw const HubApiException(
          HubApiErrorKind.timeout, 'Request timed out.');
    } catch (e) {
      if (e is HubApiException) rethrow;
      throw HubApiException(
          HubApiErrorKind.connectionFailed, 'Connection failed: $e');
    }
  }

  Future<http.Response> _authenticatedPost(
      Uri uri, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(uri,
              headers: _authHeaders, body: jsonEncode(body))
          .timeout(ApiConstants.defaultTimeout);
      return _checkStatus(response);
    } on TimeoutException {
      throw const HubApiException(
          HubApiErrorKind.timeout, 'Request timed out.');
    } catch (e) {
      if (e is HubApiException) rethrow;
      throw HubApiException(
          HubApiErrorKind.connectionFailed, 'Connection failed: $e');
    }
  }

  http.Response _checkStatus(http.Response response) {
    final code = response.statusCode;
    if (code == 200 || code == 201) return response;
    if (code == 401) {
      throw const HubApiException(
        HubApiErrorKind.unauthorized,
        'Pairing token rejected. Re-pair via Settings.',
        statusCode: 401,
      );
    }
    if (code >= 500) {
      throw HubApiException(
        HubApiErrorKind.serverError,
        'Hub internal error.',
        statusCode: code,
      );
    }
    throw HubApiException(
      HubApiErrorKind.badRequest,
      'Bad request: ${response.body}',
      statusCode: code,
    );
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw HubApiException(
        HubApiErrorKind.malformedResponse,
        'Could not parse JSON response: $e',
      );
    }
  }

  /// Release any underlying HTTP resources. Call when the client is
  /// no longer needed (typically only on app shutdown).
  void close() => _client.close();
}
