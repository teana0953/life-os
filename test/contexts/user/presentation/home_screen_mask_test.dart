import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/privacy/privacy_mask_controller.dart';

import '../../../support/semantics_tree.dart';
import 'home_screen_test.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// The figure `loadedDashboardFixture()` prints for 淨值 — the string the
/// mask has to make disappear.
const _netWorthText = '530,900';

Future<HomeController> _loadedController() async {
  final profileRepository = FakeProfileRepository()
    ..profileToReturn = UserProfile(
      id: 'user-1',
      firebaseUid: 'firebase-abc',
      email: 'test@example.com',
      displayName: 'Test User',
      createdAt: '2026-01-01T00:00:00.000Z',
      isAdmin: false,
    );
  final controller = HomeController(
    GetProfile(profileRepository),
    SignOut(FakeAuthRepository()),
  );
  await controller.load('token-123');
  return controller;
}

Key _eyeKey(PrivacyMaskItem item) => Key('home-mask-toggle-${item.name}');

/// Taps an eye and insists the tap actually landed on it.
///
/// The finance tiles sit below the fold at the default 800pt height, where a
/// bare `tester.tap` derives an off-screen offset, hits the view instead, and
/// merely *warns* — every masking assertion here passed vacuously until
/// `hitTestWarningShouldBeFatal` turned that warning into a failure.
Future<void> _tapEye(WidgetTester tester, PrivacyMaskItem item) async {
  await tester.ensureVisible(find.byKey(_eyeKey(item)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_eyeKey(item)));
  await tester.pumpAndSettle();
}

void main() {
  group('HomeScreen privacy mask', () {
    setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
    tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

    testWidgets(
      'W1 LINCHPIN: exactly the four maskable tiles carry an eye',
      (tester) async {
        await pumpHomeScreen(
          tester,
          await _loadedController(),
          dashboardController: loadedDashboardFixture(),
        );

        for (final item in PrivacyMaskItem.values) {
          expect(find.byKey(_eyeKey(item)), findsOneWidget, reason: item.name);
        }
        // Not `findsNWidgets(4)` on the key prefix alone: the count has to be
        // pinned across the whole screen, so a fifth eye somewhere else is
        // caught too.
        expect(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.key.toString().contains('home-mask-toggle-'),
          ),
          findsNWidgets(4),
        );

        // The tiles that must NOT get one. 分帳總覽 is in this list on
        // purpose: it prints money like the three above it, so "money tiles
        // get an eye" would wrongly include it.
        //
        // Judged by the eye's KEY, not by "this tile has no `IconButton` at
        // all": 食物份量 now carries a search icon (issue #196), which is an
        // `IconButton` and not an eye. Widened by exactly that much — an
        // `IconButton` whose key starts with `home-mask-toggle-` under any of
        // these four tiles still fails. Mutation-checked: forcing the eye
        // onto 食物份量 (giving it a `maskItem`) turns this red.
        for (final tile in const [
          'home-latest-blood-pressure',
          'home-menstrual-prediction',
          'home-food-dictionary',
          'home-split-overview',
        ]) {
          expect(
            find.descendant(
              of: find.byKey(Key(tile)),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is IconButton &&
                    w.key.toString().contains('home-mask-toggle-'),
              ),
            ),
            findsNothing,
            reason: tile,
          );
        }
      },
    );

    testWidgets(
      'W2 LINCHPIN: hiding total assets removes the figure from the screen',
      (tester) async {
        await pumpHomeScreen(
          tester,
          await _loadedController(),
          dashboardController: loadedDashboardFixture(),
        );
        expect(find.text(_netWorthText), findsOneWidget);

        await _tapEye(tester, PrivacyMaskItem.netWorth);

        // The load-bearing half: asserting only that `••••` appeared would
        // also pass if the bullets were painted beside the untouched number.
        expect(find.text(_netWorthText), findsNothing);
        expect(find.text(_en.homeMaskedValue), findsOneWidget);
        // And only that one tile is masked.
        expect(find.text('456,700'), findsOneWidget); // 總負債
      },
    );

    testWidgets('W3: tapping the eye again brings the figure back', (
      tester,
    ) async {
      await pumpHomeScreen(
        tester,
        await _loadedController(),
        dashboardController: loadedDashboardFixture(),
      );

      await _tapEye(tester, PrivacyMaskItem.netWorth);
      expect(find.text(_netWorthText), findsNothing);

      await _tapEye(tester, PrivacyMaskItem.netWorth);
      expect(find.text(_netWorthText), findsOneWidget);
      expect(find.text(_en.homeMaskedValue), findsNothing);
    });

    testWidgets(
      'W4 LINCHPIN: a hidden figure reads as "Hidden" and is nowhere in the '
      'semantics tree',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpHomeScreen(
          tester,
          await _loadedController(),
          dashboardController: loadedDashboardFixture(),
        );

        await _tapEye(tester, PrivacyMaskItem.netWorth);

        // Read off the real SemanticsOwner tree, not a widget's cached node.
        // The tile is one merged node, so what a screen reader actually says
        // is the pair — which is the assertion, rather than "a node labelled
        // Hidden exists somewhere".
        expect(
          semanticsDataForLabel(
            tester,
            '${_en.homeNetWorth}\n${_en.homeValueHidden}',
          ),
          isNotNull,
          reason:
              'the total-assets node should read "Hidden"; live labels were '
              '${allSemanticsLabels(tester)}',
        );
        // Masking the pixels while the number stays in the semantics tree is
        // exactly the leak this feature exists to stop.
        expect(
          allSemanticsLabels(tester).where((l) => l.contains(_netWorthText)),
          isEmpty,
        );
        // The bullets must not be spelled out instead.
        expect(
          allSemanticsLabels(tester).where(
            (l) => l.contains(_en.homeMaskedValue),
          ),
          isEmpty,
        );
        handle.dispose();
      },
    );

    testWidgets('W5: each eye names its own tile, before and after', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHomeScreen(
        tester,
        await _loadedController(),
        dashboardController: loadedDashboardFixture(),
      );

      String tooltipOf(PrivacyMaskItem item) => tester
          .widget<IconButton>(find.byKey(_eyeKey(item)))
          .tooltip!;

      final visible = {
        PrivacyMaskItem.latestWeight: _en.homeMaskHide(_en.homeLatestWeight),
        PrivacyMaskItem.budget: _en.homeMaskHide(_en.homeBudget),
        PrivacyMaskItem.netWorth: _en.homeMaskHide(_en.homeNetWorth),
        PrivacyMaskItem.totalLiabilities: _en.homeMaskHide(
          _en.homeTotalLiabilities,
        ),
      };
      for (final entry in visible.entries) {
        expect(tooltipOf(entry.key), entry.value, reason: entry.key.name);
      }
      // Four eyes on one screen are useless to a screen-reader user if they
      // all read "Hide value".
      expect(visible.values.toSet(), hasLength(4));
      // And the names really reach the platform: an icon-only button's
      // accessible name arrives as a semantics tooltip, and the widget
      // property above only proves it was set.
      expect(
        allSemanticsTooltips(tester),
        containsAll(visible.values),
        reason: 'the four eyes must be distinguishable to a screen reader',
      );

      await _tapEye(tester, PrivacyMaskItem.netWorth);

      expect(
        tooltipOf(PrivacyMaskItem.netWorth),
        _en.homeMaskShow(_en.homeNetWorth),
      );
      expect(
        allSemanticsTooltips(tester),
        contains(_en.homeMaskShow(_en.homeNetWorth)),
      );
      // The other three did not flip.
      expect(
        tooltipOf(PrivacyMaskItem.budget),
        _en.homeMaskHide(_en.homeBudget),
      );
      handle.dispose();
    });

    testWidgets('W6: tapping the eye does not navigate to finance', (
      tester,
    ) async {
      final harness = await pumpHomeScreen(
        tester,
        await _loadedController(),
        dashboardController: loadedDashboardFixture(),
      );

      await _tapEye(tester, PrivacyMaskItem.netWorth);

      expect(harness.financeLocations, isEmpty);
      // The mask still happened, i.e. the tap landed on the eye rather than
      // being swallowed entirely.
      expect(find.text(_netWorthText), findsNothing);

      // And the tile itself still navigates — the eye must not have taken
      // over the whole tile's gesture area.
      await tester.ensureVisible(find.byKey(const Key('home-net-worth')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-net-worth')));
      await tester.pumpAndSettle();
      expect(harness.financeLocations, ['/finance?tab=networth']);
    });

    testWidgets(
      'W7: the placeholder dashboard carries the same four eyes',
      (tester) async {
        // The eye is a user setting, not a property of the data: it must not
        // appear only once the six-request fan-out lands.
        await pumpHomeScreen(tester, await _loadedController());
        expect(find.text(_netWorthText), findsNothing); // placeholder block

        for (final item in PrivacyMaskItem.values) {
          expect(find.byKey(_eyeKey(item)), findsOneWidget, reason: item.name);
        }
      },
    );

    testWidgets(
      'W7b: a choice restored from disk is masked on the first frame',
      (tester) async {
        await pumpHomeScreen(
          tester,
          await _loadedController(),
          dashboardController: loadedDashboardFixture(),
          privacyMaskController: await testPrivacyMaskController(
            initialValues: {
              'privacy_hidden_items_uid-test': <String>['netWorth'],
            },
          ),
        );

        expect(find.text(_netWorthText), findsNothing);
        expect(find.text(_en.homeMaskedValue), findsOneWidget);
      },
    );
  });
}
