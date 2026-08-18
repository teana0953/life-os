import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the one line that joins the two halves this change already covers:
/// `pushSwScriptUrl` (unit-tested) produces the URL, `push_sw.js` (executed by
/// `push_sw_ack_harness.mjs`) parses it — but nothing proved the produced URL
/// is the one handed to `register()`. Dropping the argument back to a bare
/// `'push_sw.js'` leaves every other test green and silently kills every ack.
///
/// Source-level rather than behavioural, and that is not a shortcut:
/// `browser_web_push_gateway.dart` imports `dart:js_interop`/`package:web`,
/// which do not resolve on the VM target, so a test importing it fails to
/// COMPILE (measured) — no test in this suite can reach the gateway at all.
const _gateway =
    'lib/contexts/notifications/infrastructure/browser_web_push_gateway.dart';

void main() {
  test('registers the URL built by pushSwScriptUrl, not a bare script name', () {
    final source = File(_gateway).readAsStringSync();

    // Checked before the extraction, not separately: a second `.register(`
    // call would let `firstMatch` latch onto the wrong site and stay green
    // while the real one regressed.
    expect(RegExp(r'\.register\(').allMatches(source), hasLength(1));

    final match = RegExp(r'\.register\(\s*([^,]+),').firstMatch(source);
    expect(match, isNotNull, reason: 'no `.register(<arg>,` call found');
    // Exact equality, not `contains('pushSwScriptUrl')`: the identifier also
    // appears in the gateway's import and in its `[pushSwScriptUrl]` doc
    // reference, so a file-level `contains` survives the mutation — and the
    // doc reference alone is what keeps `flutter analyze` quiet about the
    // then-unused import.
    expect(match!.group(1)!.trim(), 'pushSwScriptUrl(apiBaseUrl).toJS');
  });
}
