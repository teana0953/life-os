import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/notifications/domain/medication_reminder.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_medication_reminder_repository.dart';

void main() {
  group('HttpMedicationReminderRepository', () {
    test(
      'list GETs {baseUrl}/api/reminders/medication with a bearer token and '
      'parses the {reminders: [...]} envelope',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        String? capturedAuthHeader;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedAuthHeader = request.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'reminders': [
                {
                  'id': 'rem-1',
                  'label': 'Metformin',
                  'times': ['08:00', '20:00'],
                  'days_of_week': [1, 3, 5],
                  'week_interval': 2,
                  'anchor_date': '2026-07-20',
                  'enabled': true,
                },
              ],
            }),
            200,
          );
        });
        final repository = HttpMedicationReminderRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final reminders = await repository.list('token-123');

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/reminders/medication'),
        );
        expect(capturedMethod, 'GET');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(reminders, hasLength(1));
        expect(reminders.single.id, 'rem-1');
        expect(reminders.single.label, 'Metformin');
        expect(reminders.single.times, ['08:00', '20:00']);
        expect(reminders.single.daysOfWeek, [1, 3, 5]);
        expect(reminders.single.weekInterval, 2);
        expect(reminders.single.anchorDate, DateTime(2026, 7, 20));
        expect(reminders.single.enabled, isTrue);
      },
    );

    test(
      'create POSTs {baseUrl}/api/reminders/medication with a bearer token '
      'and a snake_case body, sending anchor_date as YYYY-MM-DD (design D4b)',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        String? capturedAuthHeader;
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedAuthHeader = request.headers['Authorization'];
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 201);
        });
        final repository = HttpMedicationReminderRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.create(
          'token-123',
          MedicationReminderDraft(
            label: 'Metformin',
            times: const ['08:00'],
            daysOfWeek: const [1, 3, 5],
            weekInterval: 1,
            // A DateTime with a non-zero time component: the sent body must
            // still be date-only, never `toIso8601String()`.
            anchorDate: DateTime(2026, 7, 20, 13, 45),
            enabled: true,
          ),
        );

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/reminders/medication'),
        );
        expect(capturedMethod, 'POST');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(capturedBody, {
          'label': 'Metformin',
          'times': ['08:00'],
          'days_of_week': [1, 3, 5],
          'week_interval': 1,
          'anchor_date': '2026-07-20',
          'enabled': true,
        });
        expect(
          capturedBody!['anchor_date'],
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
        );
      },
    );

    test(
      'update PATCHes {baseUrl}/api/reminders/medication/{id} sending only '
      'the non-null fields',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 204);
        });
        final repository = HttpMedicationReminderRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.update(
          'token-123',
          'rem-1',
          const MedicationReminderUpdate(enabled: false),
        );

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/reminders/medication/rem-1'),
        );
        expect(capturedMethod, 'PATCH');
        expect(capturedBody, {'enabled': false});
      },
    );

    test(
      'update sends every field (still date-only anchor_date) when the form '
      'submits a full edit',
      () async {
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 204);
        });
        final repository = HttpMedicationReminderRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.update(
          'token-123',
          'rem-1',
          MedicationReminderUpdate(
            label: 'Metformin',
            times: const ['09:00'],
            daysOfWeek: const [0, 6],
            weekInterval: 2,
            anchorDate: DateTime(2026, 8, 1),
            enabled: true,
          ),
        );

        expect(capturedBody, {
          'label': 'Metformin',
          'times': ['09:00'],
          'days_of_week': [0, 6],
          'week_interval': 2,
          'anchor_date': '2026-08-01',
          'enabled': true,
        });
      },
    );

    test(
      'delete DELETEs {baseUrl}/api/reminders/medication/{id} with a bearer '
      'token',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        String? capturedAuthHeader;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedAuthHeader = request.headers['Authorization'];
          return http.Response('', 204);
        });
        final repository = HttpMedicationReminderRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.delete('token-123', 'rem-1');

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/reminders/medication/rem-1'),
        );
        expect(capturedMethod, 'DELETE');
        expect(capturedAuthHeader, 'Bearer token-123');
      },
    );

    test(
      'setTimezone PUTs {baseUrl}/api/user/timezone with a bearer token and '
      'a {timezone} body',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 204);
        });
        final repository = HttpMedicationReminderRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.setTimezone('token-123', 'Asia/Taipei');

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/user/timezone'),
        );
        expect(capturedMethod, 'PUT');
        expect(capturedBody, {'timezone': 'Asia/Taipei'});
      },
    );

    test('throws ReminderReauthRequired on 401 for every endpoint', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpMedicationReminderRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.list('token-123'),
        throwsA(isA<ReminderReauthRequired>()),
      );
      expect(
        () => repository.create(
          'token-123',
          MedicationReminderDraft(
            label: 'X',
            times: const ['08:00'],
            daysOfWeek: const [1],
            weekInterval: 1,
            anchorDate: DateTime(2026, 7, 20),
            enabled: true,
          ),
        ),
        throwsA(isA<ReminderReauthRequired>()),
      );
      expect(
        () => repository.update(
          'token-123',
          'rem-1',
          const MedicationReminderUpdate(enabled: false),
        ),
        throwsA(isA<ReminderReauthRequired>()),
      );
      expect(
        () => repository.delete('token-123', 'rem-1'),
        throwsA(isA<ReminderReauthRequired>()),
      );
      expect(
        () => repository.setTimezone('token-123', 'Asia/Taipei'),
        throwsA(isA<ReminderReauthRequired>()),
      );
    });

    test('throws ReminderRequestFailed on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpMedicationReminderRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.list('token-123'),
        throwsA(isA<ReminderRequestFailed>()),
      );
    });

    test(
      'throws ReminderRequestFailed (not a crash) on a network error',
      () async {
        final client = MockClient(
          (request) async => throw Exception('offline'),
        );
        final repository = HttpMedicationReminderRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        expect(
          () => repository.list('token-123'),
          throwsA(isA<ReminderRequestFailed>()),
        );
      },
    );

    test(
      'throws ReminderRequestFailed on an unparseable success body',
      () async {
        final client = MockClient(
          (request) async => http.Response('not json', 200),
        );
        final repository = HttpMedicationReminderRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        expect(
          () => repository.list('token-123'),
          throwsA(isA<ReminderRequestFailed>()),
        );
      },
    );
  });
}
