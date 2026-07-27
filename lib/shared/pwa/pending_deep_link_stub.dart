import 'pending_deep_link.dart';

/// Non-web stub: there is no Cache Storage or service worker, so there is
/// never a pending hand-over. Keeps mobile / desktop / VM-test builds
/// compiling without `dart:js_interop`.
class PendingDeepLinkStoreImpl implements PendingDeepLinkStore {
  const PendingDeepLinkStoreImpl();

  @override
  Future<PendingDeepLink?> take() async => null;

  @override
  Stream<void> get handoverSignals => const Stream.empty();
}
