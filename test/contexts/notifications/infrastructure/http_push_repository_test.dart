import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_push_repository.dart';

void main() {
  group('HttpPushRepository', () {
    test(
      'fetchVapidPublicKey GETs {baseUrl}/api/push/vapid-public-key with a '
      'bearer token and parses {public_key}',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        String? capturedAuthHeader;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedAuthHeader = request.headers['Authorization'];
          return http.Response(
            jsonEncode({'public_key': 'vapid-key-abc'}),
            200,
          );
        });
        final repository = HttpPushRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final key = await repository.fetchVapidPublicKey('token-123');

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/push/vapid-public-key'),
        );
        expect(capturedMethod, 'GET');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(key, 'vapid-key-abc');
      },
    );

    test(
      'saveSubscription POSTs {baseUrl}/api/push/subscribe with a bearer '
      'token and a snake_case {endpoint,p256dh,auth} body',
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
          return http.Response('', 204);
        });
        final repository = HttpPushRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        await repository.saveSubscription(
          'token-123',
          const PushSubscription(
            endpoint: 'https://push.example/abc',
            p256dh: 'p256dh-key',
            auth: 'auth-key',
          ),
        );

        expect(
          capturedUri,
          Uri.parse('https://example.test/api/push/subscribe'),
        );
        expect(capturedMethod, 'POST');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(capturedBody, {
          'endpoint': 'https://push.example/abc',
          'p256dh': 'p256dh-key',
          'auth': 'auth-key',
        });
      },
    );

    test(
      'sendTest POSTs {baseUrl}/api/push/test with a bearer token and '
      'parses {sent,failed}',
      () async {
        Uri? capturedUri;
        String? capturedMethod;
        String? capturedAuthHeader;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedAuthHeader = request.headers['Authorization'];
          return http.Response(jsonEncode({'sent': 2, 'failed': 1}), 200);
        });
        final repository = HttpPushRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        final result = await repository.sendTest('token-123');

        expect(capturedUri, Uri.parse('https://example.test/api/push/test'));
        expect(capturedMethod, 'POST');
        expect(capturedAuthHeader, 'Bearer token-123');
        expect(result.sent, 2);
        expect(result.failed, 1);
      },
    );

    test('throws PushReauthRequired on 401 for every endpoint', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpPushRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.fetchVapidPublicKey('token-123'),
        throwsA(isA<PushReauthRequired>()),
      );
      expect(
        () => repository.saveSubscription(
          'token-123',
          const PushSubscription(endpoint: 'e', p256dh: 'p', auth: 'a'),
        ),
        throwsA(isA<PushReauthRequired>()),
      );
      expect(
        () => repository.sendTest('token-123'),
        throwsA(isA<PushReauthRequired>()),
      );
    });

    test('throws PushRequestFailed on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpPushRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.fetchVapidPublicKey('token-123'),
        throwsA(isA<PushRequestFailed>()),
      );
    });

    test('throws PushRequestFailed (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpPushRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.fetchVapidPublicKey('token-123'),
        throwsA(isA<PushRequestFailed>()),
      );
    });

    test(
      'throws PushRequestFailed on an unparseable success body',
      () async {
        final client = MockClient(
          (request) async => http.Response('not json', 200),
        );
        final repository = HttpPushRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        expect(
          () => repository.fetchVapidPublicKey('token-123'),
          throwsA(isA<PushRequestFailed>()),
        );
      },
    );
  });
}
