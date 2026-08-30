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
    // Each of the three signals below means "the app is in front of the user
    // again", and carries no destination. The foreground effect is
    // deliberately NOT run here: its single call site is the controller's
    // injected `onForegrounded` seam, which runs it before every gate
    // (design.md D5). Two call sites would be two explanations for any future
    // partial recovery, and only the seam is observable off the browser.
    void signal() {
      controller.add(null);
    }

    controller = StreamController<void>.broadcast(
      onListen: () {
        final serviceWorker = web.window.navigator.serviceWorker;
        listener = ((web.Event _) => signal()).toJS;
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
        // #193. Becoming visible is the broadest of the three signals — but
        // not a universal one: on an installed WebAPK the notification path
        // was measured dispatching neither `visibilitychange` nor `focus`
        // (issue #226), which is why the worker's message matters and why the
        // engine's lifecycle has to be restored explicitly.
        //
        // Extra signals are harmless: they carry no destination, so a check
        // they trigger reads the store, finds nothing, and stops.
        //
        // `restoreForegroundLifecycle()` dispatches exactly these two events,
        // and it runs on every signal this stream produces, so an untrusted
        // event must stop here or the fix is a loop: signal -> dispatch
        // 'focus' -> this adapter's own 'focus' listener -> signal -> ...
        // The engine survives it (it ignores an unchanged lifecycle state);
        // this adapter has no such dedupe (design.md D4). Only the browser can
        // produce a trusted event — every synthetic one is ours.
        visibilityListener =
            ((web.Event event) {
              if (!event.isTrusted) return;
              if (web.document.visibilityState == 'visible') {
                signal();
              }
            }).toJS;
        web.document.addEventListener('visibilitychange', visibilityListener);
        focusListener =
            ((web.Event event) {
              if (!event.isTrusted) return;
              signal();
            }).toJS;
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

/// Puts Flutter web's engine back into a `resumed` lifecycle state after the
/// app has been brought to the foreground without the browser reporting it
/// (issue #226, design.md D1/D3).
///
/// The engine's ONLY lifecycle input is `_BrowserAppLifecycleState` in
/// `flutter/bin/cache/flutter_web_sdk/lib/_engine/engine/platform_dispatcher/app_lifecycle_state.dart`
/// (read in Flutter 3.35.4, the version this was measured against): window
/// `focus`/`blur` and document `visibilitychange`, with no polling and no
/// other source. It never re-reads `document.visibilityState` outside that one
/// listener, so a WebAPK that becomes visible without dispatching an event
/// leaves it stuck at `hidden` and frames disabled. There is no API to correct
/// that from Dart, which is why this dispatches synthetic events: typing these
/// two dispatches into the console of a frozen installed WebAPK revived it
/// immediately, and that measurement is the whole evidence for this fix.
///
/// Both events, because the pair is what was measured. The engine maps either
/// one to `resumed`, so one is very likely enough — but "very likely enough"
/// is what produced the three previous attempts at this bug: **reducing this
/// to a single event requires a new on-device measurement, not reasoning**
/// (design.md D3). `visibilitychange` goes first because its listener re-reads
/// `visibilityState` and so can only report what is actually true.
///
/// Only while genuinely visible: a synthetic `focus` asserts `resumed`
/// unconditionally, and enabling frames for a hidden page would put the engine
/// at odds with reality — the same class of desync as the bug being fixed.
///
/// If a Flutter upgrade breaks this, the symptom is issue #226 verbatim
/// (painted, dead screen after a notification tap). Check those engine
/// listeners first, then re-measure on a real installed WebAPK; design.md D2
/// names the documented next approach and the evidence it needs.
///
/// Side effect worth knowing about: the synthetic `visibilitychange` also
/// reaches `web/index.html`'s listener, which defers a `registration.update()`
/// by 10 seconds — so every notification tap now schedules one extra service
/// worker update check. That deferral exists precisely to keep the check off
/// the moment the user starts using the app, and the call is idempotent, so
/// this is accepted rather than filtered.
void restoreForegroundLifecycle() {
  if (web.document.visibilityState != 'visible') return;
  web.document.dispatchEvent(web.Event('visibilitychange'));
  web.window.dispatchEvent(web.Event('focus'));
}
