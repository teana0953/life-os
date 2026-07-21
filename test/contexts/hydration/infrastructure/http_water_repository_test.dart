import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/hydration/domain/water_exceptions.dart';
import 'package:life_os/contexts/hydration/infrastructure/http_water_repository.dart';

void main() {
  group('HttpWaterRepository', () {
    test('getDay GETs {baseUrl}/api/water?day= with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'day': '2026-07-18',
            'total_ml': 1200,
            'target_ml': 2000,
            'remaining_ml': 800,
          }),
          200,
        );
      });
      final repository = HttpWaterRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final day = await repository.getDay('token-123', '2026-07-18');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/water?day=2026-07-18'),
      );
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(day.totalMl, 1200);
      expect(day.targetMl, 2000);
      expect(day.remainingMl, 800);
    });

    test('addWater POSTs {day, add_ml} and returns the updated total', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'day': '2026-07-18', 'total_ml': 750}),
          200,
        );
      });
      final repository = HttpWaterRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final total = await repository.addWater(
        'token-123',
        day: '2026-07-18',
        addMl: 250,
      );

      expect(capturedUri, Uri.parse('https://example.test/api/water'));
      expect(capturedMethod, 'POST');
      expect(capturedBody, {'day': '2026-07-18', 'add_ml': 250});
      expect(total, 750);
    });

    test('setTarget PUTs {day, target_ml} and returns the updated target', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'day': '2026-07-18', 'target_ml': 2500}),
          200,
        );
      });
      final repository = HttpWaterRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final target = await repository.setTarget(
        'token-123',
        day: '2026-07-18',
        targetMl: 2500,
      );

      expect(capturedUri, Uri.parse('https://example.test/api/water/target'));
      expect(capturedMethod, 'PUT');
      expect(capturedBody, {'day': '2026-07-18', 'target_ml': 2500});
      expect(target, 2500);
    });

    test('throws WaterReauthenticationRequired on 401', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpWaterRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('expired-token', '2026-07-18'),
        throwsA(isA<WaterReauthenticationRequired>()),
      );
    });

    test('throws WaterFetchFailure on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpWaterRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('token-123', '2026-07-18'),
        throwsA(isA<WaterFetchFailure>()),
      );
    });

    test('throws WaterFetchFailure (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpWaterRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('token-123', '2026-07-18'),
        throwsA(isA<WaterFetchFailure>()),
      );
    });
  });
}
