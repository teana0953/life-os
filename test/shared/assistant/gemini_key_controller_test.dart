import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/assistant/gemini_key_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Deliberately implausible: nothing else in the test environment can contain
// this string by coincidence, so "does not appear" assertions mean something.
const _fakeKey = 'AIzaSyFAKE-TEST-KEY-1234wxyz';

Future<SharedPreferences> _emptyPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  group('GeminiKeyController', () {
    test('starts without a key on empty prefs', () async {
      final controller = GeminiKeyController(await _emptyPrefs());

      expect(controller.hasKey, isFalse);
      expect(controller.last4, isNull);
      expect(controller.key, isNull);
    });

    test('setKey persists and a rebuilt controller reads it back', () async {
      final prefs = await _emptyPrefs();
      await GeminiKeyController(prefs).setKey(_fakeKey);

      // A fresh controller on the same prefs — the restart path.
      final rebuilt = GeminiKeyController(prefs);
      expect(rebuilt.hasKey, isTrue);
      expect(rebuilt.last4, 'wxyz');
      expect(rebuilt.key, _fakeKey);
      // The specific, gemini-named prefs key — a rename or a generic
      // "assistant_api_key" would break the next slice's HTTP adapter and
      // silently orphan already-stored keys.
      expect(prefs.getString('gemini_api_key'), _fakeKey);
    });

    test('setKey trims surrounding whitespace before storing', () async {
      // Pasting from a key-management page routinely brings a trailing
      // newline along; stored untrimmed it corrupts the auth header.
      final prefs = await _emptyPrefs();
      final controller = GeminiKeyController(prefs);

      await controller.setKey('  $_fakeKey \n');

      expect(prefs.getString('gemini_api_key'), _fakeKey);
      expect(controller.last4, 'wxyz');
    });

    test('setKey rejects a key that is empty after trimming', () async {
      final prefs = await _emptyPrefs();
      final controller = GeminiKeyController(prefs);

      await expectLater(controller.setKey(' \n '), throwsArgumentError);

      expect(controller.hasKey, isFalse);
      expect(prefs.containsKey('gemini_api_key'), isFalse);
    });

    test('clear really removes the prefs entry, not just empties it', () async {
      final prefs = await _emptyPrefs();
      final controller = GeminiKeyController(prefs);
      await controller.setKey(_fakeKey);

      await controller.clear();

      // containsKey, not getString()=='': a lazy setString('') mutation
      // keeps the entry alive and turns this assertion red.
      expect(prefs.containsKey('gemini_api_key'), isFalse);
      expect(controller.hasKey, isFalse);
      expect(controller.last4, isNull);
      // The restart path agrees the key is gone.
      expect(GeminiKeyController(prefs).hasKey, isFalse);
    });

    test('notifies listeners on setKey and on clear', () async {
      final controller = GeminiKeyController(await _emptyPrefs());
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setKey(_fakeKey);
      expect(notified, 1);

      await controller.clear();
      expect(notified, 2);
    });

    test('toString does not leak the key', () async {
      final prefs = await _emptyPrefs();
      final controller = GeminiKeyController(prefs);
      await controller.setKey(_fakeKey);

      // Guard the danger side first: the key really is inside the object …
      expect(controller.key, _fakeKey);
      // … and still doesn't surface through the one implicit serialization
      // path every log/error interpolation goes through.
      expect(controller.toString(), isNot(contains(_fakeKey)));
    });
  });
}
