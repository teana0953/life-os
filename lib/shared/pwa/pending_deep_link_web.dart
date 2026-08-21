import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'pending_deep_link.dart';

/// The Cache Storage hand-over contract (design.md D2) — SINGLE source of
/// truth shared with `web/push_sw.js`. Do not change one side without the
/// other.
const _cacheName = 'lifeos-deeplink';
const _cacheKey = '/pending';

/// Web implementation: reads/clears the D2 Cache Storage entry the service
/// worker writes on `notificationclick`, and turns its `postMessage` signal
/// (design D4) into [handoverSignals]. Thin adapter, NOT unit-tested (same
/// call as `BrowserWebPushGateway`) — the browser APIs it touches aren't
/// available on the VM.
class PendingDeepLinkStoreImpl implements PendingDeepLinkStore {
  const PendingDeepLinkStoreImpl();

  @override
  Future<PendingDeepLink?> take() async {
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final response = await cache.match(_cacheKey.toJS).toDart;
      if (response == null) return null;
      // Read-then-delete: the entry is consumed exactly once regardless of
      // what the caller decides to do with it (design.md D7).
      await cache.delete(_cacheKey.toJS).toDart;
      final body = (await response.text().toDart).toDart;
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final path = json['path'];
      final savedAt = json['savedAt'];
      if (path is! String || savedAt is! int) return null;
      return PendingDeepLink(
        path: path,
        savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
    } catch (_) {
      // No cache, no entry, malformed JSON — a broken hand-over must not
      // break app startup (design.md D2).
      return null;
    }
  }

  /// Each read returns its own subscription onto the worker's message event;
  /// the composition root takes one in `start()` and holds it for the app's
  /// lifetime.
  @override
  Stream<void> get handoverSignals {
    late final StreamController<void> controller;
    // Nullable rather than `late final`: a broadcast controller runs `onListen`
    // again if it is listened to after every subscriber has cancelled, which
    // would re-assign a `late final` and throw.
    JSFunction? listener;
    JSFunction? visibilityListener;
    JSFunction? focusListener;
    controller = StreamController<void>.broadcast(
      onListen: () {
        final serviceWorker = web.window.navigator.serviceWorker;
        listener = ((web.Event _) => controller.add(null)).toJS;
        serviceWorker.addEventListener('message', listener);
        // ServiceWorkerContainer's client message queue is disabled by
        // default — a plain addEventListener alone silently queues messages
        // forever (design.md D4).
        serviceWorker.startMessages();

        // `postMessage` is NOT enough on its own, and neither is the app
        // lifecycle (design D7). The worker only messages a window whose
        // `focus()` resolved; when it falls back to `openWindow` there is no
        // message at all, and an Android WebAPK brings an existing window to
        // the front without reloading it or firing a foreground lifecycle
        // transition — leaving the user in front of the app on whatever page
        // was already open, which is the "unexpected page" half of issue
        // #193. Becoming visible is the signal that always happens.
        //
        // Extra signals are harmless: they carry no destination, so a check
        // they trigger reads the store, finds nothing, and stops.
        visibilityListener =
            ((web.Event _) {
              if (web.document.visibilityState == 'visible') {
                controller.add(null);
              }
            }).toJS;
        web.document.addEventListener('visibilitychange', visibilityListener);
        focusListener = ((web.Event _) => controller.add(null)).toJS;
        web.window.addEventListener('focus', focusListener);
      },
      onCancel: () {
        web.window.navigator.serviceWorker.removeEventListener(
          'message',
          listener,
        );
        listener = null;
        web.document.removeEventListener(
          'visibilitychange',
          visibilityListener,
        );
        visibilityListener = null;
        web.window.removeEventListener('focus', focusListener);
        focusListener = null;
      },
    );
    return controller.stream;
  }
}
