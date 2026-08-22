/// A destination handed over by the service worker through same-origin
/// storage (Cache Storage on web — see design.md D1/D2), read by the app once
/// it is ready to navigate. The concrete implementation is resolved by
/// conditional import: the web impl on web builds, a no-op stub everywhere
/// else (mobile/desktop/VM tests) so those targets still compile. Widget
/// tests inject a fake instead.
library;

import 'package:flutter/widgets.dart';

export 'pending_deep_link_stub.dart'
    if (dart.library.js_interop) 'pending_deep_link_web.dart';

/// Asks the engine for a frame because the app has just been brought to the
/// foreground (issue #226, design.md D2).
///
/// A window that `client.focus()` pulls to the front does not always get a
/// genuine `hidden → visible` transition, and without one Flutter never
/// schedules another frame: the last frame stays on screen and taps
/// hit-test and mutate state, but nothing repaints — so the app looks dead
/// until the user backgrounds it and comes back, which is the only reason
/// that workaround works.
///
/// Both calls are deliberate. `SchedulerBinding.scheduleFrame` returns
/// without doing anything while the binding believes a frame is already on
/// its way — which is exactly the stalled state, since the frame it is
/// waiting for is the one that never arrives — so the demand is repeated
/// straight to the engine, where it is idempotent.
void demandForegroundFrame() {
  final binding = WidgetsBinding.instance;
  binding.scheduleFrame();
  binding.platformDispatcher.scheduleFrame();
}

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
