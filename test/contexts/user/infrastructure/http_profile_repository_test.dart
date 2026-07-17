import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/user/domain/profile_exceptions.dart';
import 'package:life_os/contexts/user/infrastructure/http_profile_repository.dart';

void main() {
  group('HttpProfileRepository', () {
    test('GETs {baseUrl}/api/me with a bearer token and parses the profile',
        () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'firebase_uid': 'firebase-abc',
            'email': 'test@example.com',
            'display_name': 'Test User',
            'created_at': '2026-01-01T00:00:00.000Z',
          }),
          200,
        );
      });
      final repository = HttpProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final profile = await repository.getProfile('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/me'));
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(profile.id, 'user-1');
      expect(profile.email, 'test@example.com');
    });

    test('throws ReauthenticationRequired on 401', () async {
      final client = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });
      final repository = HttpProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getProfile('expired-token'),
        throwsA(isA<ReauthenticationRequired>()),
      );
    });

    test('throws ProfileFetchFailure on other non-200 responses', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      final repository = HttpProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getProfile('token-123'),
        throwsA(isA<ProfileFetchFailure>()),
      );
    });
  });
}
