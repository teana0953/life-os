import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/import/domain/import_exceptions.dart';
import 'package:life_os/contexts/import/infrastructure/http_import_repository.dart';

void main() {
  group('HttpImportRepository', () {
    test('importWeight POSTs {baseUrl}/api/import/chaodays/weight with a bearer '
        'token and a snake_case body, and parses imported/skipped', () async {
      Uri? capturedUri;
      String? capturedMethod;
      String? capturedAuthHeader;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedAuthHeader = request.headers['Authorization'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'imported': 3, 'skipped': 1, 'from': '2026-07-01', 'to': '2026-07-18'}),
          200,
        );
      });
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final summary = await repository.importWeight(
        'token-123',
        chaodaysUid: 'user1',
        chaodaysPassword: 'pass1',
        startDate: '2026-07-01',
        endDate: '2026-07-18',
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/import/chaodays/weight'),
      );
      expect(capturedMethod, 'POST');
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(capturedBody, {
        'chaodays_uid': 'user1',
        'chaodays_password': 'pass1',
        'start_date': '2026-07-01',
        'end_date': '2026-07-18',
      });
      expect(summary.imported, 3);
      expect(summary.skipped, 1);
      expect(summary.glucoseImported, isNull);
    });

    test('importWater POSTs {baseUrl}/api/import/chaodays/water', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'imported': 2, 'skipped': 0}), 200);
      });
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final summary = await repository.importWater(
        'token-123',
        chaodaysUid: 'user1',
        chaodaysPassword: 'pass1',
        startDate: '2026-07-01',
        endDate: '2026-07-18',
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/import/chaodays/water'),
      );
      expect(summary.imported, 2);
      expect(summary.skipped, 0);
    });

    test('importBowel POSTs {baseUrl}/api/import/chaodays/bowel', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'imported': 5, 'skipped': 2}), 200);
      });
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final summary = await repository.importBowel(
        'token-123',
        chaodaysUid: 'user1',
        chaodaysPassword: 'pass1',
        startDate: '2026-07-01',
        endDate: '2026-07-18',
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/import/chaodays/bowel'),
      );
      expect(summary.imported, 5);
      expect(summary.skipped, 2);
    });

    test('importDiet POSTs {baseUrl}/api/import/chaodays/diet and parses '
        'mealsImported/mealsSkipped/glucoseImported', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'mealsImported': 7,
            'mealsSkipped': 3,
            'glucoseImported': 4,
            'from': '2026-07-01',
            'to': '2026-07-18',
          }),
          200,
        );
      });
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final summary = await repository.importDiet(
        'token-123',
        chaodaysUid: 'user1',
        chaodaysPassword: 'pass1',
        startDate: '2026-07-01',
        endDate: '2026-07-18',
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/import/chaodays/diet'),
      );
      expect(summary.imported, 7);
      expect(summary.skipped, 3);
      expect(summary.glucoseImported, 4);
    });

    test(
      'importDietTarget POSTs {baseUrl}/api/import/chaodays/diet-target and '
      'parses portionTargetsImported/portionTargetsSkipped/waterTargetsImported',
      () async {
        Uri? capturedUri;
        final client = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'portionTargetsImported': 8,
              'portionTargetsSkipped': 2,
              'waterTargetsImported': 9,
              'waterTargetsSkipped': 1,
              'from': '2026-07-01',
              'to': '2026-07-18',
            }),
            200,
          );
        });
        final repository = HttpImportRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final summary = await repository.importDietTarget(
          'token-123',
          chaodaysUid: 'user1',
          chaodaysPassword: 'pass1',
          startDate: '2026-07-01',
          endDate: '2026-07-18',
        );

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/import/chaodays/diet-target'),
        );
        expect(summary.imported, 8);
        expect(summary.skipped, 2);
        expect(summary.waterTargetsImported, 9);
      },
    );

    test('importMenstrual POSTs {baseUrl}/api/import/chaodays/menstrual', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'imported': 9,
            'skipped': 3,
            'from': '2026-07-01',
            'to': '2026-07-18',
          }),
          200,
        );
      });
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final summary = await repository.importMenstrual(
        'token-123',
        chaodaysUid: 'user1',
        chaodaysPassword: 'pass1',
        startDate: '2026-07-01',
        endDate: '2026-07-18',
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/import/chaodays/menstrual'),
      );
      expect(capturedBody, {
        'chaodays_uid': 'user1',
        'chaodays_password': 'pass1',
        'start_date': '2026-07-01',
        'end_date': '2026-07-18',
      });
      expect(summary.imported, 9);
      expect(summary.skipped, 3);
    });

    test('throws ImportReauthenticationRequired on 401', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.importWeight(
          'expired-token',
          chaodaysUid: 'user1',
          chaodaysPassword: 'pass1',
          startDate: '2026-07-01',
          endDate: '2026-07-18',
        ),
        throwsA(isA<ImportReauthenticationRequired>()),
      );
    });

    test(
      'throws ImportChaodaysAuthFailed on 400 with error=chaodays_auth_failed',
      () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'chaodays_auth_failed'}),
            400,
          ),
        );
        final repository = HttpImportRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        expect(
          () => repository.importWeight(
            'token-123',
            chaodaysUid: 'user1',
            chaodaysPassword: 'wrong-pass',
            startDate: '2026-07-01',
            endDate: '2026-07-18',
          ),
          throwsA(isA<ImportChaodaysAuthFailed>()),
        );
      },
    );

    test('throws ImportFetchFailure on a 400 with a different error body', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode({'error': 'something_else'}), 400),
      );
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.importWeight(
          'token-123',
          chaodaysUid: 'user1',
          chaodaysPassword: 'pass1',
          startDate: '2026-07-01',
          endDate: '2026-07-18',
        ),
        throwsA(isA<ImportFetchFailure>()),
      );
    });

    test('throws ImportChaodaysUnavailable on 502', () async {
      final client = MockClient(
        (request) async => http.Response('Bad Gateway', 502),
      );
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.importWeight(
          'token-123',
          chaodaysUid: 'user1',
          chaodaysPassword: 'pass1',
          startDate: '2026-07-01',
          endDate: '2026-07-18',
        ),
        throwsA(isA<ImportChaodaysUnavailable>()),
      );
    });

    test('throws ImportFetchFailure on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.importWeight(
          'token-123',
          chaodaysUid: 'user1',
          chaodaysPassword: 'pass1',
          startDate: '2026-07-01',
          endDate: '2026-07-18',
        ),
        throwsA(isA<ImportFetchFailure>()),
      );
    });

    test('throws ImportFetchFailure (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpImportRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.importWeight(
          'token-123',
          chaodaysUid: 'user1',
          chaodaysPassword: 'pass1',
          startDate: '2026-07-01',
          endDate: '2026-07-18',
        ),
        throwsA(isA<ImportFetchFailure>()),
      );
    });
  });
}
