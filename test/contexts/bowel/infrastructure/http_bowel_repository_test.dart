import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/bowel/domain/bowel_exceptions.dart';
import 'package:life_os/contexts/bowel/infrastructure/http_bowel_repository.dart';

void main() {
  group('HttpBowelRepository', () {
    test('getDay GETs {baseUrl}/api/bowel?day= with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'day': '2026-07-18',
            'count': 2,
            'is_normal': true,
            'note': 'fine',
          }),
          200,
        );
      });
      final repository = HttpBowelRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final day = await repository.getDay('token-123', '2026-07-18');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/bowel?day=2026-07-18'),
      );
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(day.count, 2);
      expect(day.isNormal, true);
      expect(day.note, 'fine');
    });

    test('getDay maps a null is_normal', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'day': '2026-07-18',
            'count': 0,
            'is_normal': null,
            'note': '',
          }),
          200,
        ),
      );
      final repository = HttpBowelRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final day = await repository.getDay('token-123', '2026-07-18');

      expect(day.isNormal, isNull);
    });

    test('save PUTs {day, count, is_normal, note} and returns the saved record',
        () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'day': '2026-07-18',
            'count': 3,
            'is_normal': false,
            'note': 'loose',
          }),
          200,
        );
      });
      final repository = HttpBowelRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final saved = await repository.save(
        'token-123',
        day: '2026-07-18',
        count: 3,
        isNormal: false,
        note: 'loose',
      );

      expect(capturedUri, Uri.parse('https://example.test/api/bowel'));
      expect(capturedMethod, 'PUT');
      expect(capturedBody, {
        'day': '2026-07-18',
        'count': 3,
        'is_normal': false,
        'note': 'loose',
      });
      expect(saved.count, 3);
      expect(saved.isNormal, false);
    });

    test('throws BowelReauthenticationRequired on 401', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpBowelRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('expired-token', '2026-07-18'),
        throwsA(isA<BowelReauthenticationRequired>()),
      );
    });

    test('throws BowelFetchFailure on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpBowelRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('token-123', '2026-07-18'),
        throwsA(isA<BowelFetchFailure>()),
      );
    });

    test('throws BowelFetchFailure (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpBowelRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('token-123', '2026-07-18'),
        throwsA(isA<BowelFetchFailure>()),
      );
    });
  });
}
