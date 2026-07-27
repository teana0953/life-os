import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the design-D2 hand-over contract, which is hard-coded once in JS
/// (`web/push_sw.js`) and once in Dart (`pending_deep_link_web.dart`). Neither
/// side can import the other, and a typo on either side would make the whole
/// hand-over fail silently with every other test still green — so the check is
/// a textual one, reading the Dart declarations and asserting the worker uses
/// the same values.
void main() {
  test('web/push_sw.js and the Dart adapter agree on the D2 contract', () {
    final dart = File(
      'lib/shared/pwa/pending_deep_link_web.dart',
    ).readAsStringSync();
    final js = File('web/push_sw.js').readAsStringSync();

    String dartConst(String name) {
      final match = RegExp("const $name = '([^']+)'").firstMatch(dart);
      expect(match, isNotNull, reason: 'missing `const $name` in the adapter');
      return match!.group(1)!;
    }

    expect(js, contains("'${dartConst('_cacheName')}'"));
    expect(js, contains("'${dartConst('_cacheKey')}'"));
    // Agreeing on the same *value* is not enough: a relative key resolves
    // against each side's base URL (`/push/push_sw.js` in the worker, `/` in
    // the page), so both would write and read different URLs while this test
    // stayed green. Root-relative is a correctness condition, not a style
    // rule (design.md D2).
    expect(dartConst('_cacheKey'), startsWith('/'));
    // Payload field names: read as `json['path']`/`json['savedAt']` in Dart,
    // written as object keys in the worker.
    expect(dart, contains("json['path']"));
    expect(dart, contains("json['savedAt']"));
    expect(js, contains('path: path'));
    expect(js, contains('savedAt: Date.now()'));
  });
}
