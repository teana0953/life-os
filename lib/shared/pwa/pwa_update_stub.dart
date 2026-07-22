import 'pwa_update.dart';

/// Non-web stub: there is no browser service worker, so no update is ever
/// available and applying is a no-op. Keeps mobile / desktop / VM-test builds
/// compiling without `dart:js_interop`.
class PwaUpdateImpl implements PwaUpdate {
  const PwaUpdateImpl();

  @override
  bool get updateAvailable => false;

  @override
  Future<void> applyUpdate() async {}
}
