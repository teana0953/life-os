import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the design-D2 hand-over contract, which is hard-coded once in JS
/// (`web/push_sw.js`) and once in Dart (`pending_deep_link_web.dart`). Neither
/// side can import the other, and a typo on either side would make the whole
/// hand-over fail silently with every other test still green — so the check is
/// a textual one, reading the Dart declarations and asserting the worker uses
/// the same values.
/// Runs the real worker (see `push_sw_ack_harness.mjs`) for one event.
/// Textual assertions cannot fail on "a budget alert carries no destination"
/// or "nothing is written to the Cache when there is none" — those are
/// runtime behaviours, so they are executed rather than grepped.
Future<List<Map<String, dynamic>>> _run(Map<String, Object?> scenario) async {
  final result = await Process.run('node', [
    'test/shared/pwa/push_sw_ack_harness.mjs',
    jsonEncode({'search': '?api=https://api.test', ...scenario}),
  ]);
  expect(
    result.exitCode,
    0,
    reason: 'harness exited ${result.exitCode}: ${result.stderr}',
  );
  final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  expect(json['escaped'], isNull);
  return (json['calls'] as List).cast<Map<String, dynamic>>();
}

List<Map<String, dynamic>> _of(List<Map<String, dynamic>> calls, String kind) =>
    calls.where((c) => c['kind'] == kind).toList();

/// The wire payload the backend actually sends (backend design D2): the ack
/// token sits one level in, and only a care reminder carries one.
Map<String, Object?> _carePush() => {
  'title': 'Care',
  'body': 'Take your meds',
  'data': {'ack': 'Zm9vYmFyMDEyMzQ1Njc4OWFiY2RlZmdoaWprbG1ub3A'},
};

/// A budget alert / test push: same worker, same wire shape, no ack — and
/// nothing that says "this is about care" (issue #193).
Map<String, Object?> _budgetPush() => {
  'title': 'Budget',
  'body': 'You are over your food budget',
  'data': <String, Object?>{},
};

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

  test('the worker never assumes a destination the payload did not carry', () {
    final js = File('web/push_sw.js').readAsStringSync();

    // Issue #193: `data.path || '/care-today'` made EVERY push — budget
    // alerts, test pushes, anything the backend adds later — claim to be a
    // care reminder, so every one of them landed on 今日照護. The default is
    // the defect; a `||`/`??` fallback to any path is what must not come
    // back, whatever the destination happens to be.
    expect(
      RegExp(r"(\|\||\?\?)\s*'/[a-z-]").allMatches(js),
      isEmpty,
      reason: 'push_sw.js still falls back to a hard-coded destination',
    );

    // The transitional care mapping (design D1) is allowed to name the
    // destination once, and exactly once — pinned here so the branch cannot
    // quietly multiply, and so deleting it (once the backend sends `path`)
    // is a deliberate edit to this assertion too.
    final ports = File(
      'lib/shared/pwa/pending_deep_link.dart',
    ).readAsStringSync();
    final careDestination = RegExp(
      "const careDestination = '([^']+)'",
    ).firstMatch(ports);
    expect(
      careDestination,
      isNotNull,
      reason: 'missing `const careDestination` on the Dart side',
    );
    expect(
      "'${careDestination!.group(1)}'".allMatches(js).length,
      1,
      reason: 'the transitional care destination must appear exactly once',
    );
  });

  group('a notification carries its own destination (design D1)', () {
    test('a push that is not about care carries no destination at all', () async {
      final calls = await _run({'payload': _budgetPush()});

      final shown = _of(calls, 'showNotification').single;
      // Not "some other path" — *no* path. Issue #193: this notification
      // arrives with nothing saying where it goes, and the old worker filled
      // that in with the care checklist, so a budget alert opened 今日照護.
      expect((shown['options'] as Map)['data'], isEmpty);
    });

    test('a push the backend gives an explicit path uses that path', () async {
      final calls = await _run({
        'payload': {..._budgetPush(), 'path': '/finance'},
      });

      final shown = _of(calls, 'showNotification').single;
      expect((shown['options'] as Map)['data'], {'path': '/finance'});
    });

    test('a care reminder still carries the care checklist (transitional)', () async {
      final calls = await _run({'payload': _carePush()});

      final shown = _of(calls, 'showNotification').single;
      expect((shown['options'] as Map)['data'], {'path': '/care-today'});
    });

    test(
      'tapping a notification with no destination writes no hand-over, but '
      'still brings the app to the foreground',
      () async {
        // With an app window open…
        final focused = await _run({
          'dispatch': 'notificationclick',
          'notification': <String, Object?>{},
          'windows': 1,
        });
        expect(_of(focused, 'cachePut'), isEmpty);
        expect(_of(focused, 'focus'), hasLength(1));

        // …and with none, where focus() cannot be the answer.
        final opened = await _run({
          'dispatch': 'notificationclick',
          'notification': <String, Object?>{},
          'windows': 0,
        });
        expect(_of(opened, 'cachePut'), isEmpty);
        expect(_of(opened, 'openWindow'), hasLength(1));
      },
    );

    test('tapping a notification that has a destination hands it over', () async {
      final calls = await _run({
        'dispatch': 'notificationclick',
        'notification': {'path': '/care-today'},
        'windows': 1,
      });

      expect(_of(calls, 'cachePut'), hasLength(1));
      final put = _of(calls, 'cachePut').single;
      expect(put['key'], '/pending');
      // The destination that was handed over is the tapped notification's own,
      // read straight off it — not one the click handler decided for itself.
      expect(
        (jsonDecode(put['body'] as String) as Map)['path'],
        '/care-today',
      );
      expect(_of(calls, 'focus'), hasLength(1));
    });
  });
}
