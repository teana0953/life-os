import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/infrastructure/push_sw_url.dart';

/// Guards the delivery-ack half of `web/push_sw.js` by EXECUTING it (see
/// `push_sw_ack_harness.mjs`) rather than grepping it. Every property below is
/// a runtime behaviour — "the notification still shows when the ack fails",
/// "nothing is sent when the payload carries no token" — and a textual
/// `contains()` could not fail on any of them.
///
/// A missing `node` makes these FAIL, deliberately: a self-skipping test is an
/// impossible-to-fail guard, which is what this file exists to avoid.
const _harness = 'test/shared/pwa/push_sw_ack_harness.mjs';

/// 43-char base64url, the shape the backend mints (design D1).
const _token = 'Zm9vYmFyMDEyMzQ1Njc4OWFiY2RlZmdoaWprbG1ub3A';
const _apiBase = 'https://api.test';

Future<_Run> _run({
  String? search,
  Object? payload,
  bool payloadThrows = false,
  String fetchMode = 'success',
}) async {
  final result = await Process.run('node', [
    _harness,
    jsonEncode({
      // Derived from the Dart side, not hard-coded: the query the worker is
      // handed is then the query `pushSwScriptUrl` actually produces, so the
      // ack tests below are end-to-end over both languages.
      'search': search ?? '?${Uri.parse(pushSwScriptUrl(_apiBase)).query}',
      'payload': payload,
      'payloadThrows': payloadThrows,
      'fetchMode': fetchMode,
    }),
  ]);
  expect(
    result.exitCode,
    0,
    reason: 'harness exited ${result.exitCode}: ${result.stderr}',
  );
  return _Run(jsonDecode(result.stdout as String) as Map<String, dynamic>);
}

class _Run {
  _Run(this._json);

  final Map<String, dynamic> _json;

  List<Map<String, dynamic>> get calls =>
      (_json['calls'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> of(String kind) =>
      calls.where((c) => c['kind'] == kind).toList();
  List<String> get waitUntilStates =>
      (_json['waitUntilStates'] as List).cast<String>();
  Object? get escaped => _json['escaped'];
}

Object? _carePayload({String? ack}) => {
  'title': 'Care',
  'body': 'Take your meds',
  if (ack != null) 'data': {'ack': ack},
};

void main() {
  group('push_sw.js delivery ack', () {
    test('posts the token to the API base URL carried on the script URL', () async {
      final result = await _run(payload: _carePayload(ack: _token));

      final fetches = result.of('fetch');
      expect(fetches, hasLength(1));
      final fetch = fetches.single;
      expect(fetch['url'], '$_apiBase/api/push/ack');
      expect(fetch['method'], 'POST');
      expect(jsonDecode(fetch['body'] as String), {'ack': _token});

      final headers = (fetch['headers'] as Map).cast<String, String>();
      // `text/plain` is CORS-safelisted, so the POST is a simple request with
      // no preflight and the ack does not depend on the backend's origin
      // allowlist. Restoring the contract's `application/json` reintroduces
      // that dependency silently.
      final contentType = headers.entries
          .firstWhere((e) => e.key.toLowerCase() == 'content-type')
          .value;
      expect(contentType.split(';').first.trim(), 'text/plain');
      // Design D1: the endpoint is unauthenticated on purpose. An
      // `Authorization` header would also be CORS-unsafelisted and bring the
      // preflight back.
      expect(
        headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    test('shows the notification first, and never puts the token in it', () async {
      final result = await _run(payload: _carePayload(ack: _token));

      // The very first observed call, ahead of both `waitUntil`s: an ack that
      // ran first could cost the user the notification.
      expect(result.calls.first['kind'], 'showNotification');

      final options = result.of('showNotification').single['options'] as Map;
      // The token is a bearer capability, and this object outlives the handler
      // — it is persisted with the notification and read back by
      // `notificationclick` (design D1). Only the *destination* it implies is
      // carried: a care reminder is the one push type that carries an ack, so
      // that is how the transitional mapping recognizes it (design D1) until
      // the backend sends `path` itself.
      expect(options['data'], {'path': '/care-today'});
      expect(jsonEncode(options), isNot(contains(_token)));
    });

    test('hands the ack to waitUntil, or the worker may die before it leaves', () async {
      final acked = await _run(payload: _carePayload(ack: _token));
      expect(acked.of('waitUntil'), hasLength(2));

      final unacked = await _run(payload: _carePayload());
      expect(unacked.of('waitUntil'), hasLength(1));
    });

    test('sends nothing when the payload carries no ack token', () async {
      // The test push and the budget alert (backend design D6) — the seam the
      // backend design names as most likely to be missed.
      for (final payload in [
        _carePayload(),
        {'title': 'Test', 'body': 'Hi', 'data': <String, Object?>{}},
      ]) {
        final result = await _run(payload: payload);
        expect(result.of('fetch'), isEmpty, reason: 'payload: $payload');
        expect(result.of('showNotification'), hasLength(1));
        expect(result.escaped, isNull);
      }
    });

    test('sends nothing when the script URL carries no api parameter', () async {
      // An app version registered before this change: the worker must degrade
      // to today's behaviour, not throw and not guess a relative URL (which
      // would POST to the Pages origin, where nothing is listening).
      final result = await _run(search: '', payload: _carePayload(ack: _token));

      expect(result.of('showNotification'), hasLength(1));
      expect(result.of('fetch'), isEmpty);
      expect(result.escaped, isNull);
    });

    test('a failing ack never costs the user the notification', () async {
      // Both shapes of fetch failure: a synchronous throw (invalid URL) and a
      // rejected promise (offline). Neither may escape the handler, or the
      // whole push event is reported as failed.
      for (final mode in ['throw', 'reject']) {
        final result = await _run(
          payload: _carePayload(ack: _token),
          fetchMode: mode,
        );
        expect(result.of('showNotification'), hasLength(1), reason: mode);
        expect(result.escaped, isNull, reason: mode);
        expect(result.waitUntilStates, everyElement('fulfilled'), reason: mode);
      }
    });

    test('an undecodable payload still shows a notification', () async {
      // Any push from another source, or a truncated body, makes
      // `event.data.json()` throw. Without the handler's try/catch that error
      // escapes and the user loses the notification entirely — the same
      // failure class the ack fetch is already guarded for.
      final result = await _run(payloadThrows: true);

      expect(result.escaped, isNull);
      final shown = result.of('showNotification');
      expect(shown, hasLength(1));
      expect(shown.single['title'], 'LifeOS');
      // Nothing decodable came out of the payload, so nothing identifies what
      // this notification is about — and no destination is invented for it
      // (design D1). Tapping it brings the app to the foreground and leaves
      // it where it normally opens.
      expect((shown.single['options'] as Map)['data'], isEmpty);
      expect(result.of('fetch'), isEmpty);
      expect(result.of('waitUntil'), hasLength(1));
    });

    test('a hung ack does not settle, but the notification already showed', () async {
      final result = await _run(
        payload: _carePayload(ack: _token),
        fetchMode: 'pending',
      );
      expect(result.of('showNotification'), hasLength(1));
      expect(result.waitUntilStates, ['fulfilled', 'pending']);
    });
  });

  test('Dart and JS agree on the script-URL parameter name', () {
    // Both sides are EXTRACTED and compared, rather than a literal being
    // hard-coded here: renaming either one alone goes red.
    final dartKey = Uri.parse(
      pushSwScriptUrl(_apiBase),
    ).queryParameters.keys.single;
    final js = File('web/push_sw.js').readAsStringSync();
    final jsKey = RegExp(
      r"searchParams\.get\('([^']+)'\)",
    ).firstMatch(js)?.group(1);

    expect(jsKey, isNotNull, reason: 'push_sw.js no longer reads a query param');
    expect(jsKey, dartKey);
  });
}
