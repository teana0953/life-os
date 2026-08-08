import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/assistant/domain/assistant_failure.dart';
import 'package:life_os/contexts/assistant/domain/assistant_message.dart';
import 'package:life_os/contexts/assistant/infrastructure/http_assistant_repository.dart';

// A canary the assertions grep for: if this string reaches the URL or the
// body, the test names the leak.
const _canaryKey = 'SK-WIRE-CANARY-4406';

HttpAssistantRepository _repository(MockClient client) =>
    HttpAssistantRepository(baseUrl: 'https://example.test', client: client);

const _messages = [
  AssistantMessage(role: 'user', content: '這個月吃飯花多少?'),
  AssistantMessage(role: 'assistant', content: '共 3,600 元。'),
  AssistantMessage(role: 'user', content: '幫我記一筆'),
];

void main() {
  group('HttpAssistantRepository', () {
    test('POSTs the whole history and parses text + proposals', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'text': '好的,请确认',
            'proposals': [
              {
                'kind': 'create_transaction',
                'fields': {'type': 'expense', 'amount': 180},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final reply = await _repository(client).send(
        'token-123',
        geminiKey: _canaryKey,
        messages: _messages,
      );

      expect(captured!.method, 'POST');
      expect(captured!.url, Uri.parse('https://example.test/api/assistant'));
      expect(captured!.headers['Authorization'], 'Bearer token-123');
      final body = jsonDecode(utf8.decode(captured!.bodyBytes)) as Map<String, dynamic>;
      expect(body['messages'], [
        {'role': 'user', 'content': '這個月吃飯花多少?'},
        {'role': 'assistant', 'content': '共 3,600 元。'},
        {'role': 'user', 'content': '幫我記一筆'},
      ]);
      expect(reply.text, '好的,请确认');
      expect(reply.proposals.single.kind, 'create_transaction');
      expect(reply.proposals.single.fields['amount'], 180);
    });

    test('the key travels in the X-Gemini-Api-Key header and NOWHERE else', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'text': 'ok', 'proposals': []}),
          200,
        );
      });

      await _repository(client).send(
        'token-123',
        geminiKey: _canaryKey,
        messages: _messages,
      );

      expect(captured!.headers['X-Gemini-Api-Key'], _canaryKey);
      // A key in the query string reaches access logs and browser history; a
      // key in the body reaches the backend's request parsing. Either move
      // turns this red.
      expect(captured!.url.toString(), isNot(contains(_canaryKey)));
      expect(utf8.decode(captured!.bodyBytes), isNot(contains(_canaryKey)));
    });

    test('classifies the five backend failures by BODY error code, apart', () async {
      // The two 400s are the point: a status-only classification cannot tell
      // them apart and would collapse this table.
      const cases = [
        (400, 'bad_request', AssistantFailure.missingKey),
        (400, 'gemini_key_rejected', AssistantFailure.keyRejected),
        (429, 'gemini_quota_exhausted', AssistantFailure.quotaExhausted),
        (403, 'gemini_model_unavailable', AssistantFailure.modelUnavailable),
        (502, 'gemini_unavailable', AssistantFailure.serviceUnavailable),
      ];
      final seen = <AssistantFailure>{};
      for (final (status, code, expected) in cases) {
        final client = MockClient(
          (request) async =>
              http.Response(jsonEncode({'error': code}), status),
        );
        try {
          await _repository(client).send(
            'token-123',
            geminiKey: _canaryKey,
            messages: _messages,
          );
          fail('($status, $code) should have thrown');
        } on AssistantSendFailure catch (failure) {
          expect(failure.failure, expected, reason: '($status, $code)');
          seen.add(failure.failure);
        }
      }
      expect(seen.length, cases.length, reason: 'no two failures may collapse');
    });

    test('401 throws AssistantReauthRequired, not a send failure', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode({'error': 'unauthorized'}), 401),
      );
      await expectLater(
        _repository(client).send(
          'token-expired',
          geminiKey: _canaryKey,
          messages: _messages,
        ),
        throwsA(isA<AssistantReauthRequired>()),
      );
    });

    test('a transport exception classifies as network', () async {
      final client = MockClient(
        (request) async => throw http.ClientException('socket closed'),
      );
      await expectLater(
        _repository(client).send(
          'token-123',
          geminiKey: _canaryKey,
          messages: _messages,
        ),
        throwsA(
          isA<AssistantSendFailure>().having(
            (f) => f.failure,
            'failure',
            AssistantFailure.network,
          ),
        ),
      );
    });

    test('an unreadable error body degrades to serviceUnavailable', () async {
      final client = MockClient(
        (request) async => http.Response('<html>Bad Gateway</html>', 502),
      );
      await expectLater(
        _repository(client).send(
          'token-123',
          geminiKey: _canaryKey,
          messages: _messages,
        ),
        throwsA(
          isA<AssistantSendFailure>().having(
            (f) => f.failure,
            'failure',
            AssistantFailure.serviceUnavailable,
          ),
        ),
      );
    });

    test('a malformed 200 body throws serviceUnavailable, not a crash', () async {
      final client = MockClient(
        (request) async => http.Response('not json at all', 200),
      );
      await expectLater(
        _repository(client).send(
          'token-123',
          geminiKey: _canaryKey,
          messages: _messages,
        ),
        throwsA(
          isA<AssistantSendFailure>().having(
            (f) => f.failure,
            'failure',
            AssistantFailure.serviceUnavailable,
          ),
        ),
      );
    });
  });
}
