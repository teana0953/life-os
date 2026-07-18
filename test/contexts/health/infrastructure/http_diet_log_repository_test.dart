import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/infrastructure/http_diet_log_repository.dart';

Map<String, dynamic> _entryJson() => {
  'id': 'entry-1',
  'day': '2026-07-18',
  'meal': 'lunch',
  'name': '飯/1碗',
  'photo_ref': null,
  'source': 'dict',
  'unclassified': false,
  'carb_g': 90,
  'protein_g': 6,
  'fat_g': 0.75,
  'sugar_g': 0,
  'fiber_g': 1.5,
  'kcal': 420,
  'staple': 6,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'eaten_at': '2026-07-18T12:30:00.000Z',
  'logged_at': '2026-07-18T12:31:00.000Z',
};

void main() {
  group('HttpDietLogRepository', () {
    test(
      'logFromDictionary POSTs {baseUrl}/api/diet-entries with quantity',
      () async {
        Uri? capturedUri;
        Map<String, dynamic>? capturedBody;
        String? capturedAuthHeader;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedAuthHeader = request.headers['Authorization'];
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_entryJson()), 201, headers: {'content-type': 'application/json'});
        });
        final repository = HttpDietLogRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final entry = await repository.logFromDictionary(
          'token-123',
          day: '2026-07-18',
          meal: 'lunch',
          foodItemId: 'rice-1',
          quantity: 1.5,
        );

        expect(capturedUri, Uri.parse('https://example.test/api/diet-entries'));
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(capturedBody, {
          'day': '2026-07-18',
          'meal': 'lunch',
          'food_item_id': 'rice-1',
          'quantity': 1.5,
        });
        expect(entry.staple, 6);
      },
    );

    test('logFromDictionary sends grams and eaten_at when given', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_entryJson()), 201, headers: {'content-type': 'application/json'});
      });
      final repository = HttpDietLogRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.logFromDictionary(
        'token-123',
        day: '2026-07-18',
        meal: 'lunch',
        foodItemId: 'rice-1',
        grams: 33,
        eatenAt: DateTime.utc(2026, 7, 18, 12, 30),
      );

      expect(capturedBody, {
        'day': '2026-07-18',
        'meal': 'lunch',
        'food_item_id': 'rice-1',
        'grams': 33.0,
        'eaten_at': '2026-07-18T12:30:00.000Z',
      });
    });

    test('getDayLog GETs {baseUrl}/api/diet-entries?day=', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'day': '2026-07-18',
            'meals': [
              {'meal': 'lunch', 'entries': [_entryJson()]},
            ],
            'totals': {
              'carbG': 90,
              'proteinG': 6,
              'fatG': 0.75,
              'sugarG': 0,
              'fiberG': 1.5,
              'kcal': 420,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = HttpDietLogRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final log = await repository.getDayLog('token-123', '2026-07-18');

      expect(capturedUri, Uri.parse('https://example.test/api/diet-entries?day=2026-07-18'));
      expect(log.meals.single.meal, 'lunch');
    });

    test('deleteEntry DELETEs {baseUrl}/api/diet-entries/:id', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response('', 204);
      });
      final repository = HttpDietLogRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.deleteEntry('token-123', 'entry-1');

      expect(capturedUri, Uri.parse('https://example.test/api/diet-entries/entry-1'));
      expect(capturedMethod, 'DELETE');
    });

    test('throws DietReauthenticationRequired on 401', () async {
      final client = MockClient((request) async => http.Response('Unauthorized', 401));
      final repository = HttpDietLogRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDayLog('expired-token', '2026-07-18'),
        throwsA(isA<DietReauthenticationRequired>()),
      );
    });

    test('throws DietFetchFailure on other non-2xx responses', () async {
      final client = MockClient((request) async => http.Response('Internal Server Error', 500));
      final repository = HttpDietLogRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDayLog('token-123', '2026-07-18'),
        throwsA(isA<DietFetchFailure>()),
      );
    });
  });
}
