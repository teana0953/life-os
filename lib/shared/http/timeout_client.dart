import 'dart:async';

import 'package:http/http.dart' as http;

/// Bounds every request made through the wrapped client by a wall-clock
/// deadline, so a backend that stops answering degrades into the screens'
/// existing error state instead of an indefinite spinner.
///
/// Three things about `package:http` shape this class:
///
///  * The deadline covers the response **body**, not just the headers.
///    `BaseClient._sendUnstreamed` ends with
///    `Response.fromStream(await send(request))` (http 1.6.0
///    `lib/src/base_client.dart:93`) — the body is read *after* the future
///    returned by [send] completes. Wrapping [send] in `Future.timeout` would
///    therefore bound only the time-to-headers and let a response trickle
///    forever, which is the same hang wearing a different hat. Hence the one
///    [Timer] here stays armed across the streaming phase and is cancelled
///    only when the body is done.
///  * This class owns the deadline; abort is only an extra signal on top.
///    `MockClient` documents that it "does not support aborting requests
///    directly" (`lib/src/mock_client.dart:31`), so a decorator that relied on
///    the inner client honouring `abortTrigger` for its *timing* could not be
///    tested at all.
///  * The abort trigger is still worth wiring, because clients that do support
///    it genuinely stop the work: `BrowserClient.send` builds an
///    `AbortController` and passes its signal into `fetch`
///    (`lib/src/browser_client.dart:72`). Without it a timed-out request keeps
///    occupying a connection until the platform gives up.
///
/// Deliberately **no** automatic retry, and in particular not
/// `package:http`'s own `RetryClient`: a timeout does not mean the request
/// failed to arrive, so replaying a POST can apply it twice (this app has
/// already shipped one duplicate-charge incident). Retrying is the user's
/// call, through the retry affordances the screens already have.
class TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration _timeout;

  TimeoutClient(this._inner, this._timeout);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortTrigger = Completer<void>();
    final expired = Completer<http.StreamedResponse>();
    StreamController<List<int>>? body;

    late final Timer timer;
    void cancelDeadline() => timer.cancel();

    timer = Timer(_timeout, () {
      if (!abortTrigger.isCompleted) abortTrigger.complete();
      final failure = TimeoutException(
        'HTTP request to ${request.url} timed out',
        _timeout,
      );
      // Whichever phase we are in, exactly one of these two is being
      // listened to; the other is already-completed and drops it.
      if (!expired.isCompleted) expired.completeError(failure);
      final controller = body;
      if (controller != null && !controller.isClosed) {
        controller.addError(failure);
        controller.close();
      }
    });

    final http.StreamedResponse response;
    final sending = _inner.send(_withAbortTrigger(request, abortTrigger.future));
    try {
      // `Future.any` swallows the loser's later error, so the abandoned send
      // does not surface as an unhandled async error.
      response = await Future.any([sending, expired.future]);
    } catch (_) {
      cancelDeadline();
      sending.ignore();
      rethrow;
    }

    final controller = StreamController<List<int>>();
    body = controller;
    controller.onListen = () {
      final subscription = response.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          cancelDeadline();
          if (!controller.isClosed) controller.close();
        },
      );
      controller
        ..onPause = subscription.pause
        ..onResume = subscription.resume
        // Returns void rather than `subscription.cancel()`'s future on
        // purpose. `_BufferingStreamSubscription._sendDone` withholds the
        // done event until the cancel future resolves, and under fake time
        // (`fakeAsync`, and the same machinery inside `testWidgets`) that
        // future never resolves — the caller's `Response.fromStream` would
        // hang forever in every test while working fine in production. The
        // upstream is still cancelled; only its completion is not awaited.
        ..onCancel = () {
          cancelDeadline();
          subscription.cancel();
        };
    };

    return http.StreamedResponse(
      controller.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}

/// Re-issues [request] as an [http.AbortableRequest] so clients that support
/// abortion can drop the in-flight work when the deadline passes. Anything
/// that is not a plain [http.Request] (or already abortable) is passed through
/// untouched — the deadline in [TimeoutClient.send] still applies to it.
http.BaseRequest _withAbortTrigger(
  http.BaseRequest request,
  Future<void> abortTrigger,
) {
  if (request is! http.Request || request is http.Abortable) return request;
  return http.AbortableRequest(
    request.method,
    request.url,
    abortTrigger: abortTrigger,
  )
    ..followRedirects = request.followRedirects
    ..maxRedirects = request.maxRedirects
    ..persistentConnection = request.persistentConnection
    ..headers.addAll(request.headers)
    ..encoding = request.encoding
    ..bodyBytes = request.bodyBytes;
}
