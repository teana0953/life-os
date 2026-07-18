import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/infrastructure/http_daily_target_repository.dart';

void main() {
  group('HttpDailyTargetRepository', () {
    test('getTarget GETs {baseUrl}/api/daily-target?day= with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'day': '2026-07-18',
            'base': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
            'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
            'effective': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
            'logged': {'staple': 9, 'meat': 3, 'fruit': 1, 'veg': 0},
            'remaining': {'staple': 3, 'meat': 3, 'fruit': 3, 'veg': 3},
          }),
          200,
        );
      });
      final repository = HttpDailyTargetRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final target = await repository.getTarget('token-123', '2026-07-18');

      expect(capturedUri, Uri.parse('https://example.test/api/daily-target?day=2026-07-18'));
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(target.remaining.staple, 3);
    });

    test('setTarget PUTs {baseUrl}/api/daily-target with flat base_/bonus_ fields', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 'target-1',
            'day': '2026-07-18',
            'base_staple': 12,
            'base_meat': 6,
            'base_fruit': 4,
            'base_veg': 3,
            'bonus_staple': 1,
            'bonus_meat': 0,
            'bonus_fruit': 0,
            'bonus_veg': 0,
          }),
          200,
        );
      });
      final repository = HttpDailyTargetRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final target = await repository.setTarget(
        'token-123',
        day: '2026-07-18',
        baseStaple: 12,
        baseMeat: 6,
        baseFruit: 4,
        baseVeg: 3,
        bonusStaple: 1,
      );

      expect(capturedUri, Uri.parse('https://example.test/api/daily-target'));
      expect(capturedMethod, 'PUT');
      expect(capturedBody, {
        'day': '2026-07-18',
        'base_staple': 12.0,
        'base_meat': 6.0,
        'base_fruit': 4.0,
        'base_veg': 3.0,
        'bonus_staple': 1.0,
      });
      expect(target.bonusStaple, 1);
    });

    test('throws DietReauthenticationRequired on 401', () async {
      final client = MockClient((request) async => http.Response('Unauthorized', 401));
      final repository = HttpDailyTargetRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getTarget('expired-token', '2026-07-18'),
        throwsA(isA<DietReauthenticationRequired>()),
      );
    });

    test('throws DietFetchFailure on other non-2xx responses', () async {
      final client = MockClient((request) async => http.Response('Internal Server Error', 500));
      final repository = HttpDailyTargetRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getTarget('token-123', '2026-07-18'),
        throwsA(isA<DietFetchFailure>()),
      );
    });
  });
}
