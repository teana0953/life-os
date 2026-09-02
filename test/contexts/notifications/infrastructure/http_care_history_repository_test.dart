import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_care_history_repository.dart';

Map<String, dynamic> _slotJson({
  String? careItemId = 'care-1',
  String? careScheduleId = 'sch-1',
  bool itemDeleted = false,
  String category = 'medication',
  String title = 'Metformin',
  String? note = 'take with food',
  String? dose = '500mg',
  String timeOfDay = '08:00',
  String localDate = '2026-07-22',
  String status = 'done',
  String? doneTime,
  num doseQuantity = 1,
}) => {
  'care_item_id': careItemId,
  'care_schedule_id': careScheduleId,
  'item_deleted': itemDeleted,
  'category': category,
  'title': title,
  'note': note,
  'dose': dose,
  'time_of_day': timeOfDay,
  'local_date': localDate,
  'status': status,
  'done_time': doneTime,
  'dose_quantity': doseQuantity,
};

void main() {
  group('HttpCareHistoryRepository.getRange', () {
    test('GETs {baseUrl}/api/care/range?from=&to= with a bearer token and '
        'parses the {from,to,days:[{date,items:[...]}]} envelope', () async {
      Uri? capturedUri;
      String? capturedMethod;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'from': '2026-07-16',
            'to': '2026-07-22',
            'days': [
              {'date': '2026-07-21', 'items': []},
              {
                'date': '2026-07-22',
                'items': [_slotJson()],
              },
            ],
          }),
          200,
        );
      });
      final repository = HttpCareHistoryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final days = await repository.getRange(
        'token-123',
        '2026-07-16',
        '2026-07-22',
      );

      expect(
        capturedUri,
        Uri.parse(
          'https://example.test/api/care/range?from=2026-07-16&to=2026-07-22',
        ),
      );
      expect(capturedMethod, 'GET');
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(days, hasLength(2));
      expect(days[0].date, '2026-07-21');
      expect(days[0].slots, isEmpty);
      expect(days[1].date, '2026-07-22');
      final slot = days[1].slots.single;
      expect(slot.careItemId, 'care-1');
      expect(slot.careScheduleId, 'sch-1');
      expect(slot.category, CareCategory.medication);
      expect(slot.title, 'Metformin');
      expect(slot.note, 'take with food');
      expect(slot.dose, '500mg');
      expect(slot.timeOfDay, '08:00');
      expect(slot.localDate, '2026-07-22');
      expect(slot.status, CareTodayStatus.done);
      expect(slot.doseQuantity, 1);
    });

    test('parses every status value', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'from': '2026-07-22',
            'to': '2026-07-22',
            'days': [
              {
                'date': '2026-07-22',
                'items': [_slotJson(status: 'missed', doneTime: null)],
              },
            ],
          }),
          200,
        );
      });
      final repository = HttpCareHistoryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final days = await repository.getRange(
        'token-123',
        '2026-07-22',
        '2026-07-22',
      );

      expect(days.single.slots.single.status, CareTodayStatus.missed);
    });

    test('preserves an orphan record with null ids and its snapshot', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'from': '2026-07-22',
            'to': '2026-07-22',
            'days': [
              {
                'date': '2026-07-22',
                'items': [
                  _slotJson(
                    careItemId: null,
                    careScheduleId: null,
                    itemDeleted: true,
                    title: 'Deleted snapshot',
                  ),
                ],
              },
            ],
          }),
          200,
        ),
      );
      final repository = HttpCareHistoryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final slot = (await repository.getRange(
        'token-123',
        '2026-07-22',
        '2026-07-22',
      )).single.slots.single;

      expect(slot.careItemId, isNull);
      expect(slot.careScheduleId, isNull);
      expect(slot.itemDeleted, isTrue);
      expect(slot.title, 'Deleted snapshot');
    });
  });

  group('HttpCareHistoryRepository.editSlot', () {
    test(
      'PUTs {baseUrl}/api/care/log with a bearer token and a snake_case body',
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
          return http.Response(jsonEncode({'id': 'log-1'}), 200);
        });
        final repository = HttpCareHistoryRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.editSlot(
          'token-123',
          careScheduleId: 'sch-1',
          localDate: '2026-07-22',
          timeOfDay: '08:00',
          status: CareLogStatus.done,
        );

        expect(capturedUri, Uri.parse('https://example.test/api/care/log'));
        expect(capturedMethod, 'PUT');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(capturedBody, {
          'care_schedule_id': 'sch-1',
          'local_date': '2026-07-22',
          'time_of_day': '08:00',
          'status': 'done',
        });
      },
    );

    test('sends status "skipped" for a skip', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'id': 'log-1'}), 200);
      });
      final repository = HttpCareHistoryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.editSlot(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.skipped,
      );

      expect(capturedBody!['status'], 'skipped');
    });

    test(
      'includes done_time as a UTC ISO string when doneTime is given',
      () async {
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 'log-1'}), 200);
        });
        final repository = HttpCareHistoryRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.editSlot(
          'token-123',
          careScheduleId: 'sch-1',
          localDate: '2026-07-22',
          timeOfDay: '08:00',
          status: CareLogStatus.done,
          doneTime: DateTime.utc(2026, 7, 22, 4, 58),
        );

        expect(capturedBody!['done_time'], '2026-07-22T04:58:00.000Z');
      },
    );

    test(
      'omits done_time entirely when not given (not a null value)',
      () async {
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 'log-1'}), 200);
        });
        final repository = HttpCareHistoryRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.editSlot(
          'token-123',
          careScheduleId: 'sch-1',
          localDate: '2026-07-22',
          timeOfDay: '08:00',
          status: CareLogStatus.done,
        );

        expect(capturedBody!.containsKey('done_time'), isFalse);
      },
    );

    test(
      'omits done_time for a skipped status even when doneTime is given',
      () async {
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 'log-1'}), 200);
        });
        final repository = HttpCareHistoryRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.editSlot(
          'token-123',
          careScheduleId: 'sch-1',
          localDate: '2026-07-22',
          timeOfDay: '08:00',
          status: CareLogStatus.skipped,
          doneTime: DateTime.utc(2026, 7, 22, 4, 58),
        );

        expect(capturedBody!.containsKey('done_time'), isFalse);
      },
    );
  });

  group('HttpCareHistoryRepository error handling', () {
    test('throws CareReauthRequired on 401 for both endpoints', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpCareHistoryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getRange('token-123', '2026-07-16', '2026-07-22'),
        throwsA(isA<CareReauthRequired>()),
      );
      expect(
        () => repository.editSlot(
          'token-123',
          careScheduleId: 'sch-1',
          localDate: '2026-07-22',
          timeOfDay: '08:00',
          status: CareLogStatus.done,
        ),
        throwsA(isA<CareReauthRequired>()),
      );
    });

    test('throws CareRequestFailed on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Server error', 500),
      );
      final repository = HttpCareHistoryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getRange('token-123', '2026-07-16', '2026-07-22'),
        throwsA(isA<CareRequestFailed>()),
      );
      expect(
        () => repository.editSlot(
          'token-123',
          careScheduleId: 'sch-1',
          localDate: '2026-07-22',
          timeOfDay: '08:00',
          status: CareLogStatus.done,
        ),
        throwsA(isA<CareRequestFailed>()),
      );
    });

    test('throws CareRequestFailed (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpCareHistoryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getRange('token-123', '2026-07-16', '2026-07-22'),
        throwsA(isA<CareRequestFailed>()),
      );
    });

    test('throws CareRequestFailed on an unparseable success body', () async {
      final client = MockClient(
        (request) async => http.Response('not json', 200),
      );
      final repository = HttpCareHistoryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getRange('token-123', '2026-07-16', '2026-07-22'),
        throwsA(isA<CareRequestFailed>()),
      );
    });
  });
}
