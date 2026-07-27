/// A destination handed over by the service worker through same-origin
/// storage (Cache Storage on web — see design.md D1/D2), read by the app once
/// it is ready to navigate. The concrete implementation is resolved by
/// conditional import: the web impl on web builds, a no-op stub everywhere
/// else (mobile/desktop/VM tests) so those targets still compile. Widget
/// tests inject a fake instead.
library;

export 'pending_deep_link_stub.dart'
    if (dart.library.js_interop) 'pending_deep_link_web.dart';

/// A pending navigation target plus when it was written, so the consumer can
/// judge staleness (see [PendingDeepLinkStore.take]).
class PendingDeepLink {
  final String path;
  final DateTime savedAt;

  const PendingDeepLink({required this.path, required this.savedAt});
}

/// Injectable read side of the SW → app hand-over.
abstract class PendingDeepLinkStore {
  /// Reads the pending entry, **deletes it, then** returns it — consumed
  /// exactly once even when the caller decides not to act on it (TTL/dedupe
  /// are the caller's judgement, not the store's). The caller must not call
  /// this while auth is unresolved (see `PendingDeepLinkController`).
  Future<PendingDeepLink?> take();

  /// Fires when the service worker says "there may be something to read".
  /// Carries no destination — the store stays the single source of truth
  /// (design.md D4).
  Stream<void> get handoverSignals;
}
