import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:caregiver_app/services/hub_api_client.dart';

import 'hub_api_client_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  const baseUrl = 'http://test.local:5000';
  const token = 'test-token';

  group('HubApiClient.checkHealth', () {
    test('returns healthy on 200 with status=ok', () async {
      final mock = MockClient();
      when(mock.get(any)).thenAnswer((_) async => http.Response(
            jsonEncode({
              'status': 'ok',
              'api_version': 'v1',
              'server_time': '2026-05-01T10:19:08.447Z',
              'system': 'geriatric_hub',
            }),
            200,
          ));
      final client = HubApiClient(
          baseUrl: baseUrl, pairingToken: token, client: mock);

      final result = await client.checkHealth();

      expect(result.isHealthy, isTrue);
      expect(result.apiVersion, 'v1');
      expect(result.serverTime, '2026-05-01T10:19:08.447Z');
    });

    test('returns unhealthy on non-200', () async {
      final mock = MockClient();
      when(mock.get(any))
          .thenAnswer((_) async => http.Response('Server error', 500));
      final client = HubApiClient(
          baseUrl: baseUrl, pairingToken: token, client: mock);

      final result = await client.checkHealth();

      expect(result.isHealthy, isFalse);
      expect(result.errorMessage, contains('500'));
    });

    test('returns unhealthy when status field != ok', () async {
      final mock = MockClient();
      when(mock.get(any))
          .thenAnswer((_) async => http.Response(
                jsonEncode({'status': 'degraded'}),
                200,
              ));
      final client = HubApiClient(
          baseUrl: baseUrl, pairingToken: token, client: mock);

      final result = await client.checkHealth();
      expect(result.isHealthy, isFalse);
    });
  });

  group('HubApiClient auth', () {
    test('authenticated requests include Bearer header', () async {
      final mock = MockClient();
      when(mock.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({'count': 0, 'limit': 100, 'events': []}),
                200,
              ));
      final client = HubApiClient(
          baseUrl: baseUrl, pairingToken: token, client: mock);

      await client.fetchUnsyncedEvents();

      final captured =
          verify(mock.get(any, headers: captureAnyNamed('headers'))).captured;
      final headers = captured.first as Map<String, String>;
      expect(headers['Authorization'], 'Bearer $token');
    });

    test('throws unauthorized on HTTP 401', () async {
      final mock = MockClient();
      when(mock.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response('Unauthorized', 401));
      final client = HubApiClient(
          baseUrl: baseUrl, pairingToken: token, client: mock);

      expect(
        () async => await client.fetchUnsyncedEvents(),
        throwsA(isA<HubApiException>().having(
          (e) => e.kind,
          'kind',
          HubApiErrorKind.unauthorized,
        )),
      );
    });

    test('throws serverError on HTTP 500', () async {
      final mock = MockClient();
      when(mock.post(any,
              headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => http.Response('Internal error', 500));
      final client = HubApiClient(
          baseUrl: baseUrl, pairingToken: token, client: mock);

      expect(
        () async => await client.ackEvents([1, 2, 3]),
        throwsA(isA<HubApiException>().having(
          (e) => e.kind,
          'kind',
          HubApiErrorKind.serverError,
        )),
      );
    });
  });

  group('HubApiClient response handling', () {
    test('fetchUnsyncedEvents returns event list', () async {
      final mock = MockClient();
      when(mock.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({
                  'count': 2,
                  'limit': 100,
                  'events': [
                    {'event_id': 1, 'event_type': 'reminder_dose_due'},
                    {'event_id': 2, 'event_type': 'dose_confirmed'},
                  ]
                }),
                200,
              ));
      final client = HubApiClient(
          baseUrl: baseUrl, pairingToken: token, client: mock);

      final response = await client.fetchUnsyncedEvents();
      expect(response.events.length, 2);
      expect(response.events.first['event_id'], 1);
      expect(response.count, 2);
      expect(response.limit, 100);
      expect(response.hasMore, isFalse);
    });

    test('fetchUnsyncedEvents throws malformed on missing events array',
        () async {
      final mock = MockClient();
      when(mock.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({'wrong_key': []}),
                200,
              ));
      final client = HubApiClient(
          baseUrl: baseUrl, pairingToken: token, client: mock);

      expect(
        () async => await client.fetchUnsyncedEvents(),
        throwsA(isA<HubApiException>().having(
          (e) => e.kind,
          'kind',
          HubApiErrorKind.malformedResponse,
        )),
      );
    });
  });
}
