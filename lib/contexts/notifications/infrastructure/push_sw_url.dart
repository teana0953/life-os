/// Script URL used to register `web/push_sw.js`, carrying the backend base URL
/// so the worker can post delivery acks to it.
///
/// A static service worker cannot learn a build-time constant any other way:
/// it is served from the app origin while the API lives on another, and there
/// is no substitution step over `web/`. `?api=` is read back by
/// `ackEndpoint()` in `web/push_sw.js`; the parameter name is a two-language
/// contract guarded by `test/shared/pwa/push_sw_ack_contract_test.dart`.
///
/// Trailing slashes are stripped here rather than in the worker so the two
/// sides never both normalize (or both assume the other did) — the worker
/// concatenates `/api/push/ack` verbatim.
String pushSwScriptUrl(String apiBaseUrl) {
  final base = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return 'push_sw.js?api=${Uri.encodeComponent(base)}';
}
