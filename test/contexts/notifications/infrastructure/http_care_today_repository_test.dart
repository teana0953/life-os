import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_care_today_repository.dart';

Map<String, dynamic> _slotJson({
  String careItemId = 'care-1',
  String careScheduleId = 'sch-1',
  String category = 'medication',
  String title = 'Metformin',
  String? note = 'take with food',
  String? dose = '500mg',
  String timeOfDay = '08:00',
  String localDate = '2026-07-22',
  String status = 'pending',
  String? doneTime,
  num doseQuantity = 1,
}) => {
  'care_item_id': careItemId,
  'care_schedule_id': careScheduleId,
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
  group('HttpCareTodayRepository.getToday', () {
    test(
      'GETs {baseUrl}/api/care/today with a bearer token and parses the '
      '{date, items: [...]} envelope (design D1 — not a bare array)',
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
              'date': '2026-07-22',
              'items': [_slotJson()],
            }),
            200,
          );
        });
        final repository = HttpCareTodayRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final today = await repository.getToday('token-123');

        expect(capturedUri, Uri.parse('https://example.test/api/care/today'));
        expect(capturedMethod, 'GET');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(today.date, '2026-07-22');
        expect(today.slots, hasLength(1));
        final slot = today.slots.single;
        expect(slot.careItemId, 'care-1');
        expect(slot.careScheduleId, 'sch-1');
        expect(slot.category, CareCategory.medication);
        expect(slot.title, 'Metformin');
        expect(slot.note, 'take with food');
        expect(slot.dose, '500mg');
        expect(slot.timeOfDay, '08:00');
        expect(slot.localDate, '2026-07-22');
        expect(slot.status, CareTodayStatus.pending);
        expect(slot.doneTime, isNull);
        expect(slot.doseQuantity, 1);
      },
    );

    test('parses every status value and nullable note/dose/done_time', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'date': '2026-07-22',
            'items': [
              _slotJson(
                careScheduleId: 'sch-2',
                status: 'done',
                note: null,
                dose: null,
                doneTime: '08:05',
              ),
            ],
          }),
          200,
        );
      });
      final repository = HttpCareTodayRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final today = await repository.getToday('token-123');

      final slot = today.slots.single;
      expect(slot.status, CareTodayStatus.done);
      expect(slot.note, isNull);
      expect(slot.dose, isNull);
      expect(slot.doneTime, '08:05');
    });
  });

  group('HttpCareTodayRepository.logSlot', () {
    test(
      'POSTs {baseUrl}/api/care/log with a bearer token and a snake_case body',
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
          return http.Response(jsonEncode({'id': 'log-1'}), 201);
        });
        final repository = HttpCareTodayRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.logSlot(
          'token-123',
          careScheduleId: 'sch-1',
          localDate: '2026-07-22',
          timeOfDay: '08:00',
          status: CareLogStatus.done,
        );

        expect(capturedUri, Uri.parse('https://example.test/api/care/log'));
        expect(capturedMethod, 'POST');
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
        return http.Response(jsonEncode({'id': 'log-1'}), 201);
      });
      final repository = HttpCareTodayRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.logSlot(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.skipped,
      );

      expect(capturedBody!['status'], 'skipped');
    });
  });

  group('HttpCareTodayRepository error handling', () {
    test('throws CareReauthRequired on 401 for both endpoints', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpCareTodayRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getToday('token-123'),
        throwsA(isA<CareReauthRequired>()),
      );
      expect(
        () => repository.logSlot(
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
      final repository = HttpCareTodayRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getToday('token-123'),
        throwsA(isA<CareRequestFailed>()),
      );
      expect(
        () => repository.logSlot(
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
      final repository = HttpCareTodayRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getToday('token-123'),
        throwsA(isA<CareRequestFailed>()),
      );
    });

    test('throws CareRequestFailed on an unparseable success body', () async {
      final client = MockClient(
        (request) async => http.Response('not json', 200),
      );
      final repository = HttpCareTodayRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getToday('token-123'),
        throwsA(isA<CareRequestFailed>()),
      );
    });
  });
}
