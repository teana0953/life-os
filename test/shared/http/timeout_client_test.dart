import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/shared/config.dart';
import 'package:life_os/shared/http/timeout_client.dart';

/// Records how a single `client.get(...)` finished without ever awaiting it —
/// inside `fakeAsync` an `await` in the test body would deadlock, because the
/// only thing that can advance time is the test body itself.
class _Outcome {
  bool done = false;
  Object? error;
  http.Response? response;

  void watch(Future<http.Response> future) {
    future.then(
      (value) {
        response = value;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
  }
}

class _CloseRecordingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 200);

  @override
  void close() => closed = true;
}

void main() {
  final url = Uri.parse('https://example.test/api/thing');

  test('throws TimeoutException when the server never responds', () {
    fakeAsync((async) {
      final client = TimeoutClient(
        MockClient((_) => Completer<http.Response>().future),
        const Duration(seconds: 15),
      );
      final outcome = _Outcome()..watch(client.get(url));

      // Just inside the deadline nothing has fired yet: this half is what
      // goes red if someone shortens the timeout to near zero.
      async.elapse(const Duration(seconds: 14));
      async.flushMicrotasks();
      expect(outcome.done, isFalse);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(outcome.done, isTrue);
      expect(outcome.error, isA<TimeoutException>());
      expect(async.pendingTimers, isEmpty);
    });
  });

  // LINCHPIN. `BaseClient._sendUnstreamed` ends with
  // `Response.fromStream(await send(request))` (http 1.6.0
  // lib/src/base_client.dart:93) — the body is read OUTSIDE the future that
  // `send` returns. So an implementation that merely wraps the inner
  // `send()` in `Future.timeout` bounds only the time-to-headers and lets a
  // response trickle forever. This fixture is the shape that tells the two
  // apart: headers land immediately, the body never arrives.
  test('times out when headers arrive fast but the body never finishes', () {
    fakeAsync((async) {
      final body = StreamController<List<int>>();
      final client = TimeoutClient(
        MockClient.streaming(
          (_, __) async => http.StreamedResponse(body.stream, 200),
        ),
        const Duration(seconds: 15),
      );
      final outcome = _Outcome()..watch(client.get(url));

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      body.add(utf8.encode('{"partial":'));
      async.flushMicrotasks();
      expect(outcome.done, isFalse);

      async.elapse(const Duration(seconds: 20));
      async.flushMicrotasks();
      expect(outcome.done, isTrue);
      expect(outcome.error, isA<TimeoutException>());
      expect(async.pendingTimers, isEmpty);

      body.close();
      async.flushMicrotasks();
    });
  });

  test('a response arriving well inside the deadline succeeds', () {
    fakeAsync((async) {
      final client = TimeoutClient(
        MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => http.Response('{"ok":true}', 200),
          ),
        ),
        const Duration(seconds: 15),
      );
      final outcome = _Outcome()..watch(client.get(url));

      // Elapsing past the server's own delay is what makes a mutated
      // 1ms deadline fire here instead of quietly never running.
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(outcome.error, isNull);
      expect(outcome.done, isTrue);
      expect(outcome.response!.statusCode, 200);
      expect(outcome.response!.body, '{"ok":true}');
      // A deadline timer left armed after a successful response makes any
      // widget test that shares the clock fail with "A Timer is still
      // pending after the widget tree was disposed".
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('the request reaching the inner client carries an abort trigger', () {
    fakeAsync((async) {
      http.BaseRequest? seen;
      // `MockClient`'s non-streaming constructor rebuilds the request into a
      // plain `Request` before the handler sees it, which would hide exactly
      // the property under test; the streaming one hands over the original.
      final client = TimeoutClient(
        MockClient.streaming((request, _) async {
          seen = request;
          return http.StreamedResponse(const Stream.empty(), 200);
        }),
        const Duration(seconds: 15),
      );
      _Outcome().watch(client.post(url, body: 'hello'));
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(seen, isA<http.Abortable>());
      expect((seen! as http.Abortable).abortTrigger, isNotNull);
      // The rebuilt request must still be the request the caller asked for.
      expect(seen!.method, 'POST');
      expect(seen!.url, url);
      expect((seen! as http.Request).body, 'hello');
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('close() closes the inner client', () {
    final inner = _CloseRecordingClient();
    TimeoutClient(inner, const Duration(seconds: 15)).close();
    expect(inner.closed, isTrue);
  });

  // The long bound exists precisely because a single 15s value cannot cover
  // both a normal backend call and a Gemini generation / a bulk import.
  // Collapsing them back into one constant reopens the bug this change fixed.
  test('the long-running bound is a separate, larger constant', () {
    expect(longRunningHttpTimeout, greaterThan(httpRequestTimeout));
  });
}
