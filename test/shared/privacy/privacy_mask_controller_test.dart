import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/privacy/privacy_mask_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('PrivacyMaskController', () {
    test('U1: nothing is hidden before a user has loaded anything', () async {
      final controller = PrivacyMaskController(await prefsWith({}));

      for (final item in PrivacyMaskItem.values) {
        expect(controller.isHidden(item), isFalse, reason: item.name);
      }
    });

    test('U2: setHidden persists under the signed-in uid and notifies', () async {
      final prefs = await prefsWith({});
      final controller = PrivacyMaskController(prefs)..loadForUser('uid-a');
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setHidden(PrivacyMaskItem.netWorth, true);

      expect(controller.isHidden(PrivacyMaskItem.netWorth), isTrue);
      expect(
        prefs.getStringList('privacy_hidden_items_uid-a'),
        contains('netWorth'),
      );
      expect(notifications, greaterThan(0));
    });

    test(
      'U3 LINCHPIN: loading a second user REPLACES the first user\'s choices',
      () async {
        // Both users already have a (different) choice on disk. The failure
        // this pins is account bleed-through: B seeing A's mask.
        final prefs = await prefsWith({
          'privacy_hidden_items_uid-a': <String>['netWorth'],
          'privacy_hidden_items_uid-b': <String>['budget'],
        });
        final controller = PrivacyMaskController(prefs);

        controller.loadForUser('uid-a');
        expect(controller.isHidden(PrivacyMaskItem.netWorth), isTrue);
        expect(controller.isHidden(PrivacyMaskItem.budget), isFalse);

        controller.loadForUser('uid-b');
        expect(controller.isHidden(PrivacyMaskItem.budget), isTrue);
        // The half that matters: A's choice must be GONE, not merely joined
        // by B's. Asserting only `budget` is hidden passes on a shared key.
        expect(controller.isHidden(PrivacyMaskItem.netWorth), isFalse);
      },
    );

    test('U4: clearUser wipes memory but leaves the choices on disk', () async {
      final prefs = await prefsWith({
        'privacy_hidden_items_uid-a': <String>['netWorth', 'budget'],
      });
      final controller = PrivacyMaskController(prefs)..loadForUser('uid-a');
      expect(controller.isHidden(PrivacyMaskItem.budget), isTrue);

      controller.clearUser();

      for (final item in PrivacyMaskItem.values) {
        expect(controller.isHidden(item), isFalse, reason: item.name);
      }
      // Signing out is a change of occupant, not a deletion: A signing back
      // in must get A's own settings back.
      expect(
        prefs.getStringList('privacy_hidden_items_uid-a'),
        containsAll(<String>['netWorth', 'budget']),
      );
      controller.loadForUser('uid-a');
      expect(controller.isHidden(PrivacyMaskItem.netWorth), isTrue);
      expect(controller.isHidden(PrivacyMaskItem.budget), isTrue);
    });

    test('U5: with no uid, setHidden writes nothing at all', () async {
      final prefs = await prefsWith({'unrelated': 'keep-me'});
      final controller = PrivacyMaskController(prefs)
        ..loadForUser('uid-a')
        ..loadForUser(null);

      for (final item in PrivacyMaskItem.values) {
        expect(controller.isHidden(item), isFalse, reason: item.name);
      }

      final keysBefore = prefs.getKeys().toSet();
      await controller.setHidden(PrivacyMaskItem.netWorth, true);
      await controller.toggle(PrivacyMaskItem.budget);

      // The whole key set, not one named key: a null uid must not invent
      // `privacy_hidden_items_null` either.
      expect(prefs.getKeys().toSet(), keysBefore);
    });

    test('U6: the enum identifiers ARE the on-disk format', () async {
      // Renaming any of these silently discards every existing user's
      // choices on their next launch, so the names are pinned here rather
      // than left to a refactor tool.
      expect(
        PrivacyMaskItem.values.map((e) => e.name).toList(),
        ['latestWeight', 'budget', 'netWorth', 'totalLiabilities'],
      );

      final prefs = await prefsWith({
        'privacy_hidden_items_uid-a': <String>[
          'latestWeight',
          'budget',
          'netWorth',
          'totalLiabilities',
        ],
      });
      final controller = PrivacyMaskController(prefs)..loadForUser('uid-a');
      for (final item in PrivacyMaskItem.values) {
        expect(controller.isHidden(item), isTrue, reason: item.name);
      }
    });

    test('U7: an unparseable stored item is ignored, not fatal', () async {
      final prefs = await prefsWith({
        'privacy_hidden_items_uid-a': <String>['legacyThing', 'budget'],
      });
      final controller = PrivacyMaskController(prefs);

      expect(() => controller.loadForUser('uid-a'), returnsNormally);
      expect(controller.isHidden(PrivacyMaskItem.budget), isTrue);
      expect(controller.isHidden(PrivacyMaskItem.netWorth), isFalse);
    });
  });
}
