/// A destination handed over by the service worker through same-origin
/// storage (Cache Storage on web — see design.md D1/D2), read by the app once
/// it is ready to navigate. The concrete implementation is resolved by
/// conditional import: the web impl on web builds, a no-op stub everywhere
/// else (mobile/desktop/VM tests) so those targets still compile. Widget
/// tests inject a fake instead.
library;

// The same conditional export also resolves `restoreForegroundLifecycle()`,
// the effect that runs whenever the app is brought to the foreground (issue
// #226, design.md D1/D3).
//
// A window that `client.focus()` pulls to the front does not always get a
// genuine `hidden -> visible` transition; on an installed Android WebAPK
// returning from a notification tap the browser dispatches no
// `visibilitychange` and no `focus` at all (measured). Flutter web's engine
// has no other lifecycle input and no polling, so it stays at
// `AppLifecycleState.hidden`, `framesEnabled` stays false, and nothing
// repaints: taps hit-test and mutate state while the last frame stays on
// screen, until the user backgrounds the app and comes back — which is the
// only reason that workaround works.
//
// So the remedy is to restore the lifecycle, not to ask for a frame: while the
// scheduler is disabled `scheduleFrame()` returns at its own guard and a frame
// pushed straight to the engine yields at most one (design.md D1/D5). The web
// implementation puts the engine back into `resumed`, which enables frames for
// the rest of the session; off the web there is no such state to repair.
export 'pending_deep_link_stub.dart'
    if (dart.library.js_interop) 'pending_deep_link_web.dart';

/// TRANSITIONAL (design D1), and the Dart half of a two-language constant:
/// until the backend sends an explicit `path` on every push, `web/push_sw.js`
/// maps a push it can recognize as a care reminder to this destination — the
/// one hard-coded destination left in the worker, pinned from this side by
/// `push_sw_handover_contract_test.dart` (which also asserts the worker has no
/// *unconditional* default any more; that default is issue #193). Read here by
/// the composition root, which reloads 今日照護 when a hand-over lands on a
/// 今日照護 already on screen. Delete both halves once the backend sends
/// `path`.
const careDestination = '/care-today';

/// A pending navigation target plus when it was written, so the consumer can
/// judge staleness (see [PendingDeepLinkStore.take]).
class PendingDeepLink {
  final String path;
  final DateTime savedAt;

  const PendingDeepLink({required this.path, required this.savedAt});
}

/// Injectable read side of the SW → app hand-over.
///
/// The worker writes `{path, savedAt}` (see the contract block at the top of
/// `web/push_sw.js`) only for a notification that carried a destination of its
/// own. [path] is a router path this *worker* version knew; whether the
/// running app version has a screen for it is the consumer's judgement, not
/// this store's.
abstract class PendingDeepLinkStore {
  /// Reads the pending entry, **deletes it, then** returns it — consumed
  /// exactly once even when the caller decides not to act on it (TTL, dedupe
  /// and "does this version know this path" are the caller's judgement, not
  /// the store's). The caller must not call this while auth is unresolved
  /// (see `PendingDeepLinkController`). May never answer at all — blocked
  /// site data is silence, not an error — so the caller bounds the wait.
  Future<PendingDeepLink?> take();

  /// Fires whenever there may be something to read: the worker's own message,
  /// and — because that message is not delivered on every path the app can be
  /// brought to the foreground by (design.md D7) — the page becoming visible.
  /// Carries no destination; the store stays the single source of truth
  /// (design.md D4), so a redundant signal costs one empty read.
  Stream<void> get handoverSignals;
}
