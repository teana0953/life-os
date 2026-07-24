import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_care_repository.dart';

Map<String, dynamic> _scheduleJson({
  String id = 'sch-1',
  String timeOfDay = '08:00',
  List<int> repeatDays = const [1, 3, 5],
  int weekInterval = 1,
  String startDate = '2026-07-20',
  String? endDate,
  num doseQuantity = 1,
  int nagIntervalMinutes = 0,
  bool enabled = true,
}) => {
  'id': id,
  'time_of_day': timeOfDay,
  'repeat_days': repeatDays,
  'week_interval': weekInterval,
  'start_date': startDate,
  'end_date': endDate,
  'dose_quantity': doseQuantity,
  'nag_interval_minutes': nagIntervalMinutes,
  'enabled': enabled,
};

Map<String, dynamic> _itemJson({
  String id = 'care-1',
  String category = 'medication',
  String title = 'Metformin',
  String? note = 'take with food',
  String? dose = '500mg',
  num? stock = 30,
  num? stockAlert = 5,
  List<Map<String, dynamic>>? schedules,
}) => {
  'id': id,
  'category': category,
  'title': title,
  'note': note,
  'dose': dose,
  'stock': stock,
  'stock_alert': stockAlert,
  'schedules': schedules ?? [_scheduleJson()],
};

void main() {
  group('HttpCareRepository.list', () {
    test(
      'GETs {baseUrl}/api/care/items with a bearer token and parses the '
      '{items: [...]} envelope including nested schedules',
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
              'items': [_itemJson()],
            }),
            200,
          );
        });
        final repository = HttpCareRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final items = await repository.list('token-123');

        expect(capturedUri, Uri.parse('https://example.test/api/care/items'));
        expect(capturedMethod, 'GET');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(items, hasLength(1));
        final item = items.single;
        expect(item.id, 'care-1');
        expect(item.category, CareCategory.medication);
        expect(item.title, 'Metformin');
        expect(item.note, 'take with food');
        expect(item.dose, '500mg');
        expect(item.stock, 30);
        expect(item.stockAlert, 5);
        expect(item.schedules, hasLength(1));
        final schedule = item.schedules.single;
        expect(schedule.id, 'sch-1');
        expect(schedule.timeOfDay, '08:00');
        expect(schedule.repeatDays, [1, 3, 5]);
        expect(schedule.weekInterval, 1);
        expect(schedule.startDate, DateTime(2026, 7, 20));
        expect(schedule.endDate, isNull);
        expect(schedule.doseQuantity, 1);
        expect(schedule.nagIntervalMinutes, 0);
        expect(schedule.enabled, isTrue);
      },
    );

    test('parses a non-medication item with null dose/stock/stockAlert', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              _itemJson(
                id: 'care-2',
                category: 'rehab',
                dose: null,
                stock: null,
                stockAlert: null,
              ),
            ],
          }),
          200,
        );
      });
      final repository = HttpCareRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final items = await repository.list('token-123');

      expect(items.single.category, CareCategory.rehab);
      expect(items.single.dose, isNull);
      expect(items.single.stock, isNull);
      expect(items.single.stockAlert, isNull);
    });

    test('parses a schedule with an end date', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              _itemJson(
                schedules: [_scheduleJson(endDate: '2026-08-20')],
              ),
            ],
          }),
          200,
        );
      });
      final repository = HttpCareRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final items = await repository.list('token-123');

      expect(items.single.schedules.single.endDate, DateTime(2026, 8, 20));
    });
  });

  group('HttpCareRepository.create', () {
    test(
      'POSTs {baseUrl}/api/care/items with a bearer token and a snake_case '
      'body, sending the category wire enum (not a localized label)',
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
          return http.Response(jsonEncode(_itemJson()), 201);
        });
        final repository = HttpCareRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final created = await repository.create(
          'token-123',
          CareItemDraft(
            category: CareCategory.medication,
            title: 'Metformin',
            note: 'take with food',
            dose: '500mg',
            stock: 30,
            stockAlert: 5,
            schedules: [
              CareSchedule(
                timeOfDay: '08:00',
                repeatDays: const [1, 3, 5],
                weekInterval: 1,
                // A DateTime with a non-zero time component: the sent body
                // must still be date-only, never `toIso8601String()`.
                startDate: DateTime(2026, 7, 20, 13, 45),
                doseQuantity: 2,
                nagIntervalMinutes: 10,
                enabled: true,
              ),
            ],
          ),
        );

        expect(capturedUri, Uri.parse('https://example.test/api/care/items'));
        expect(capturedMethod, 'POST');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(capturedBody!['category'], 'medication');
        expect(capturedBody!['title'], 'Metformin');
        expect(capturedBody!['note'], 'take with food');
        expect(capturedBody!['dose'], '500mg');
        expect(capturedBody!['stock'], 30);
        expect(capturedBody!['stock_alert'], 5);
        final schedules = capturedBody!['schedules'] as List;
        expect(schedules, hasLength(1));
        final scheduleBody = schedules.single as Map<String, dynamic>;
        expect(scheduleBody['time_of_day'], '08:00');
        expect(scheduleBody['repeat_days'], [1, 3, 5]);
        expect(scheduleBody['week_interval'], 1);
        expect(scheduleBody['start_date'], '2026-07-20');
        expect(
          scheduleBody['start_date'],
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
        );
        expect(scheduleBody['dose_quantity'], 2);
        expect(scheduleBody['nag_interval_minutes'], 10);
        expect(scheduleBody['enabled'], isTrue);
        expect(scheduleBody.containsKey('id'), isFalse);
        // Parses the bare returned item (not an envelope) — design D1.
        expect(created.id, 'care-1');
      },
    );

    test(
      'always serializes dose_quantity AND start_date on a schedule even '
      'when the category is non-medication (the backend requires both '
      'regardless of category — the Slice-2b trap)',
      () async {
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(_itemJson(category: 'rehab', dose: null, stock: null, stockAlert: null)),
            201,
          );
        });
        final repository = HttpCareRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.create(
          'token-123',
          CareItemDraft(
            category: CareCategory.rehab,
            title: 'Stretching',
            schedules: [
              CareSchedule(
                timeOfDay: '09:00',
                repeatDays: const [],
                weekInterval: 1,
                startDate: DateTime(2026, 7, 21),
                doseQuantity: 1,
                nagIntervalMinutes: 0,
                enabled: true,
              ),
            ],
          ),
        );

        // Item-level dose/stock/stock_alert are omitted for non-medication.
        expect(capturedBody!.containsKey('dose'), isFalse);
        expect(capturedBody!.containsKey('stock'), isFalse);
        expect(capturedBody!.containsKey('stock_alert'), isFalse);
        // But every schedule still carries both backend-required fields.
        final scheduleBody =
            (capturedBody!['schedules'] as List).single as Map<String, dynamic>;
        expect(scheduleBody['dose_quantity'], 1);
        expect(scheduleBody['start_date'], '2026-07-21');
      },
    );

    test('sends an empty repeatDays list as-is (backend treats it as every day)', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_itemJson()), 201);
      });
      final repository = HttpCareRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.create(
        'token-123',
        CareItemDraft(
          category: CareCategory.custom,
          title: 'Custom reminder',
          schedules: [
            CareSchedule(
              timeOfDay: '09:00',
              repeatDays: const [],
              weekInterval: 1,
              startDate: DateTime(2026, 7, 21),
              doseQuantity: 1,
              nagIntervalMinutes: 0,
              enabled: true,
            ),
          ],
        ),
      );

      final scheduleBody =
          (capturedBody!['schedules'] as List).single as Map<String, dynamic>;
      expect(scheduleBody['repeat_days'], isEmpty);
    });

    test('sends end_date as YYYY-MM-DD when present', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_itemJson()), 201);
      });
      final repository = HttpCareRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.create(
        'token-123',
        CareItemDraft(
          category: CareCategory.medication,
          title: 'Metformin',
          schedules: [
            CareSchedule(
              timeOfDay: '09:00',
              repeatDays: const [1],
              weekInterval: 1,
              startDate: DateTime(2026, 7, 21),
              endDate: DateTime(2026, 12, 25, 23, 59),
              doseQuantity: 1,
              nagIntervalMinutes: 0,
              enabled: true,
            ),
          ],
        ),
      );

      final scheduleBody =
          (capturedBody!['schedules'] as List).single as Map<String, dynamic>;
      expect(scheduleBody['end_date'], '2026-12-25');
    });
  });

  group('HttpCareRepository.update', () {
    test(
      'PATCHes {baseUrl}/api/care/items/{id}, round-trips an existing '
      'schedule id, and parses the bare returned item',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_itemJson(title: 'Metformin XR')), 200);
        });
        final repository = HttpCareRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final updated = await repository.update(
          'token-123',
          'care-1',
          CareItemUpdate(
            category: CareCategory.medication,
            title: 'Metformin XR',
            note: 'take with food',
            dose: '500mg',
            stock: 30,
            stockAlert: 5,
            schedules: [
              // Existing schedule: id round-trips.
              CareSchedule(
                id: 'sch-1',
                timeOfDay: '08:00',
                repeatDays: const [1, 3, 5],
                weekInterval: 1,
                startDate: DateTime(2026, 7, 20),
                doseQuantity: 1,
                nagIntervalMinutes: 0,
                enabled: true,
              ),
              // A newly added schedule: no id.
              CareSchedule(
                timeOfDay: '20:00',
                repeatDays: const [1, 3, 5],
                weekInterval: 1,
                startDate: DateTime(2026, 7, 20),
                doseQuantity: 1,
                nagIntervalMinutes: 0,
                enabled: true,
              ),
            ],
          ),
        );

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/care/items/care-1'),
        );
        expect(capturedMethod, 'PATCH');
        final schedules = capturedBody!['schedules'] as List;
        expect(schedules, hasLength(2));
        expect((schedules[0] as Map<String, dynamic>)['id'], 'sch-1');
        expect(
          (schedules[1] as Map<String, dynamic>).containsKey('id'),
          isFalse,
        );
        expect(updated.title, 'Metformin XR');
      },
    );
  });

  group('HttpCareRepository.delete', () {
    test(
      'DELETEs {baseUrl}/api/care/items/{id} with a bearer token',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        String? capturedAuthHeader;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedAuthHeader = request.headers['Authorization'];
          return http.Response(jsonEncode({'deleted': true}), 200);
        });
        final repository = HttpCareRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.delete('token-123', 'care-1');

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/care/items/care-1'),
        );
        expect(capturedMethod, 'DELETE');
        expect(capturedAuthHeader, 'Bearer token-123');
      },
    );
  });

  group('HttpCareRepository error handling', () {
    test('throws CareReauthRequired on 401 for every endpoint', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpCareRepository(
        baseUrl: 'https://example.test',
        client: client,
      );
      final draft = CareItemDraft(
        category: CareCategory.medication,
        title: 'X',
        schedules: [
          CareSchedule(
            timeOfDay: '08:00',
            repeatDays: const [1],
            weekInterval: 1,
            startDate: DateTime(2026, 7, 20),
            doseQuantity: 1,
            nagIntervalMinutes: 0,
            enabled: true,
          ),
        ],
      );

      expect(
        () => repository.list('token-123'),
        throwsA(isA<CareReauthRequired>()),
      );
      expect(
        () => repository.create('token-123', draft),
        throwsA(isA<CareReauthRequired>()),
      );
      expect(
        () => repository.update(
          'token-123',
          'care-1',
          CareItemUpdate(
            category: draft.category,
            title: draft.title,
            schedules: draft.schedules,
          ),
        ),
        throwsA(isA<CareReauthRequired>()),
      );
      expect(
        () => repository.delete('token-123', 'care-1'),
        throwsA(isA<CareReauthRequired>()),
      );
    });

    test('throws CareRequestFailed on other non-2xx responses (incl. a PATCH 404)', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode({'error': 'not_found'}), 404),
      );
      final repository = HttpCareRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.list('token-123'),
        throwsA(isA<CareRequestFailed>()),
      );
      expect(
        () => repository.update(
          'token-123',
          'missing',
          CareItemUpdate(
            category: CareCategory.medication,
            title: 'X',
            schedules: const [],
          ),
        ),
        throwsA(isA<CareRequestFailed>()),
      );
    });

    test('throws CareRequestFailed (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpCareRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.list('token-123'),
        throwsA(isA<CareRequestFailed>()),
      );
    });

    test('throws CareRequestFailed on an unparseable success body', () async {
      final client = MockClient(
        (request) async => http.Response('not json', 200),
      );
      final repository = HttpCareRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.list('token-123'),
        throwsA(isA<CareRequestFailed>()),
      );
    });
  });
}
