import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/assistant/gemini_key_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

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

    test('health access is off when prefs hold no preference', () async {
      // Absent must never read as granted: a fresh install, private
      // browsing, and cleared site data all land here, and this is consent
      // to send menstrual/glucose/vitals records off the device.
      expect(GeminiKeyController(await _emptyPrefs()).healthEnabled, isFalse);
    });

    test('setHealthEnabled persists and a rebuilt controller reads it back', () async {
      final prefs = await _emptyPrefs();
      await GeminiKeyController(prefs).setHealthEnabled(true);

      expect(prefs.getBool('assistant_health_enabled'), isTrue);
      // The restart path — the flag survives without the user re-granting it.
      expect(GeminiKeyController(prefs).healthEnabled, isTrue);
    });

    test('turning health access back off persists too', () async {
      final prefs = await _emptyPrefs();
      final controller = GeminiKeyController(prefs);
      await controller.setHealthEnabled(true);

      await controller.setHealthEnabled(false);

      expect(controller.healthEnabled, isFalse);
      expect(prefs.getBool('assistant_health_enabled'), isFalse);
      expect(GeminiKeyController(prefs).healthEnabled, isFalse);
    });

    test('the health flag has its own prefs slot, separate from the key', () async {
      // Packed into the key's entry, clearing one could half-clear the other.
      final prefs = await _emptyPrefs();
      final controller = GeminiKeyController(prefs);

      await controller.setHealthEnabled(true);

      expect(prefs.getString('gemini_api_key'), isNull);
      expect(controller.hasKey, isFalse);
    });

    test('clear removes the health flag from memory AND from prefs', () async {
      final prefs = await _emptyPrefs();
      final controller = GeminiKeyController(prefs);
      await controller.setKey(_fakeKey);
      await controller.setHealthEnabled(true);

      await controller.clear();

      expect(controller.healthEnabled, isFalse);
      // The prefs half is the one that matters on the *next* launch, and it
      // is the half a `clear()` that only reset the in-memory field would
      // leave behind. Mutation: drop the `remove` and keep
      // `_healthEnabled = false` → only this line goes red.
      expect(prefs.containsKey('assistant_health_enabled'), isFalse);
      expect(GeminiKeyController(prefs).healthEnabled, isFalse);
      expect(controller.hasKey, isFalse);
    });

    test('notifies listeners on setHealthEnabled', () async {
      final controller = GeminiKeyController(await _emptyPrefs());
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setHealthEnabled(true);

      expect(notified, 1);
      expect(controller.healthEnabled, isTrue);
    });

    test('toString reports hasKey but never the key itself', () async {
      final prefs = await _emptyPrefs();
      final controller = GeminiKeyController(prefs);
      await controller.setKey(_fakeKey);

      // Guard the danger side first: the key really is inside the object …
      expect(controller.key, _fakeKey);
      // … and still doesn't surface through the one implicit serialization
      // path every log/error interpolation goes through. This is only a real
      // guard because GeminiKeyController overrides toString() at all — the
      // default Object.toString() never touches fields, so asserting
      // "doesn't contain the key" against it could never go red. Mutation:
      // change the override to interpolate `key` (or `_key`) instead of
      // `hasKey` → this line turns red.
      expect(controller.toString(), isNot(contains(_fakeKey)));
      expect(controller.toString(), contains('hasKey: true'));
    });
  });

  group('a write that fails', () {
    // Private browsing, a blocked quota, cleared site data — all real on a
    // PWA, and this repo has watched PWA storage disappear before. The whole
    // point of writing before notifying is that this case cannot paint a
    // success the storage never accepted.
    setUp(() {
      SharedPreferencesStorePlatform.instance = _FailingStore();
    });

    // No tearDown restoring the store: `SharedPreferences.setMockInitialValues`
    // installs a fresh one at the top of every other test, so a failing store
    // left behind cannot leak into them.

    test('leaves the controller without a key, instead of claiming one', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      SharedPreferencesStorePlatform.instance = _FailingStore();
      final controller = GeminiKeyController(prefs);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await expectLater(controller.setKey(_fakeKey), throwsA(isA<Exception>()));

      // Both halves matter. `hasKey` false is the state the UI renders from;
      // zero notifications is what keeps a listener from repainting the
      // success card before the failure surfaces.
      expect(controller.hasKey, isFalse);
      expect(notifications, 0);
    });

    test('leaves health access off, instead of painting a consent that never stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      SharedPreferencesStorePlatform.instance = _FailingStore();
      final controller = GeminiKeyController(prefs);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await expectLater(
        controller.setHealthEnabled(true),
        throwsA(isA<Exception>()),
      );

      expect(controller.healthEnabled, isFalse);
      expect(notifications, 0);
    });
  });
}

/// Fails every write, succeeds at nothing else either — the controller only
/// reads at construction, which happens before this is installed.
class _FailingStore extends SharedPreferencesStorePlatform {
  @override
  bool get isMock => true;

  @override
  Future<bool> clear() async => throw Exception('storage blocked');

  @override
  Future<Map<String, Object>> getAll() async => <String, Object>{};

  @override
  Future<bool> remove(String key) async => throw Exception('storage blocked');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => throw Exception('storage blocked');

}
