import 'pwa_install.dart';

/// Non-web stub: there is no browser install flow, so nothing is installable
/// and the app is treated as already "standalone" (native). Keeps mobile /
/// desktop / VM-test builds compiling without `dart:js_interop`.
class PwaInstallImpl implements PwaInstall {
  const PwaInstallImpl();

  @override
  bool get canInstall => false;

  @override
  bool get isIosHint => false;

  @override
  bool get isStandalone => true;

  @override
  Future<void> promptInstall() async {}
}
