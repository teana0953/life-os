import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_exceptions.dart';
import 'package:life_os/contexts/menstrual/infrastructure/http_menstrual_repository.dart';

http.Response _json(Object body, int status) => http.Response(
  body is String ? body : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('HttpMenstrualRepository', () {
    test('getOverview GETs /api/menstrual with a bearer token and maps it',
        () async {
      Uri? capturedUri;
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuth = request.headers['Authorization'];
        return _json({
          'periods': [
            {'id': 'p1', 'start_date': '2026-05-01', 'end_date': '2026-05-05'},
          ],
          'stats': {
            'average_cycle_days': 28,
            'average_period_days': 5,
            'predicted_next_start': '2026-07-24',
          },
          'last_period': {
            'id': 'p1',
            'start_date': '2026-05-01',
            'end_date': '2026-05-05',
          },
        }, 200);
      });
      final repo = HttpMenstrualRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final overview = await repo.getOverview('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/menstrual'));
      expect(capturedAuth, 'Bearer token-123');
      expect(overview.periods.single.id, 'p1');
      expect(overview.stats.averageCycleDays, 28);
      expect(overview.lastPeriod!.id, 'p1');
    });

    test('addPeriod POSTs start_date (and end_date only when set)', () async {
      String? capturedMethod;
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(
          {'id': 'p9', 'start_date': '2026-06-01', 'end_date': null},
          200,
        );
      });
      final repo = HttpMenstrualRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final period = await repo.addPeriod('tok', startDate: DateTime(2026, 6, 1));

      expect(capturedMethod, 'POST');
      expect(capturedUri, Uri.parse('https://example.test/api/menstrual'));
      expect(capturedBody, {'start_date': '2026-06-01'});
      expect(period.id, 'p9');
    });

    test('updatePeriod PATCHes only the end_date when only the end changed',
        () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(
          {'id': 'p1', 'start_date': '2026-05-01', 'end_date': '2026-05-06'},
          200,
        );
      });
      final repo = HttpMenstrualRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repo.updatePeriod('tok', 'p1', endDate: DateTime(2026, 5, 6));

      expect(capturedMethod, 'PATCH');
      expect(capturedUri, Uri.parse('https://example.test/api/menstrual/p1'));
      expect(capturedBody, {'end_date': '2026-05-06'});
    });

    test('updatePeriod PATCHes only the start_date when only the start changed',
        () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(
          {'id': 'p1', 'start_date': '2026-05-02', 'end_date': '2026-05-05'},
          200,
        );
      });
      final repo = HttpMenstrualRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repo.updatePeriod('tok', 'p1', startDate: DateTime(2026, 5, 2));

      expect(capturedBody, {'start_date': '2026-05-02'});
    });

    test('updatePeriod PATCHes end_date: null to clear the end date', () async {
      Map<String, dynamic>? capturedBody;
      var containsEndDate = false;
      final client = MockClient((request) async {
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        capturedBody = decoded;
        containsEndDate = decoded.containsKey('end_date');
        return _json(
          {'id': 'p1', 'start_date': '2026-05-01', 'end_date': null},
          200,
        );
      });
      final repo = HttpMenstrualRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repo.updatePeriod('tok', 'p1', clearEndDate: true);

      expect(containsEndDate, isTrue);
      expect(capturedBody, {'end_date': null});
    });

    test('deletePeriod DELETEs /api/menstrual/:id and returns the flag',
        () async {
      String? capturedMethod;
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return _json({'deleted': true}, 200);
      });
      final repo = HttpMenstrualRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final deleted = await repo.deletePeriod('tok', 'p1');

      expect(capturedMethod, 'DELETE');
      expect(capturedUri, Uri.parse('https://example.test/api/menstrual/p1'));
      expect(deleted, isTrue);
    });

    test('a non-200 response throws MenstrualFetchFailure', () async {
      final client = MockClient((request) async => _json({'error': 'boom'}, 500));
      final repo = HttpMenstrualRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repo.getOverview('tok'),
        throwsA(isA<MenstrualFetchFailure>()),
      );
    });

    test('a 401 throws MenstrualReauthenticationRequired', () async {
      final client = MockClient((request) async => _json({'error': 'x'}, 401));
      final repo = HttpMenstrualRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repo.getOverview('tok'),
        throwsA(isA<MenstrualReauthenticationRequired>()),
      );
    });
  });
}
