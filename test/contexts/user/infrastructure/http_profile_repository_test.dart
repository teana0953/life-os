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

    test(
      'wraps network exceptions from the client in ProfileFetchFailure '
      'without leaking the original exception text',
      () async {
        final client = MockClient((request) async {
          throw http.ClientException(
            'Connection refused at 10.0.0.5:443 (internal-host)',
          );
        });
        final repository = HttpProfileRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        try {
          await repository.getProfile('token-123');
          fail('expected ProfileFetchFailure');
        } catch (e) {
          expect(e, isA<ProfileFetchFailure>());
          expect(
            (e as ProfileFetchFailure).message,
            isNot(contains('10.0.0.5')),
          );
          expect(e.message, isNot(contains('Connection refused')));
        }
      },
    );

    test(
      'wraps a non-JSON response body in ProfileFetchFailure without '
      'leaking the parser error text',
      () async {
        final client = MockClient((request) async {
          return http.Response('not valid json {{{', 200);
        });
        final repository = HttpProfileRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        try {
          await repository.getProfile('token-123');
          fail('expected ProfileFetchFailure');
        } catch (e) {
          expect(e, isA<ProfileFetchFailure>());
          expect(
            (e as ProfileFetchFailure).message,
            isNot(contains('FormatException')),
          );
        }
      },
    );

    test(
      'wraps a 200 response missing required profile fields in '
      'ProfileFetchFailure without leaking the cast error text',
      () async {
        final client = MockClient((request) async {
          return http.Response(jsonEncode({'id': 'user-1'}), 200);
        });
        final repository = HttpProfileRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        try {
          await repository.getProfile('token-123');
          fail('expected ProfileFetchFailure');
        } catch (e) {
          expect(e, isA<ProfileFetchFailure>());
          expect(
            (e as ProfileFetchFailure).message,
            isNot(contains('type \'Null\'')),
          );
        }
      },
    );
  });
}
