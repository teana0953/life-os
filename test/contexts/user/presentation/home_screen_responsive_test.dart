import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/menstrual/domain/next_period_status.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/shared/privacy/privacy_mask_controller.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import 'home_screen_test.dart' show loadedDashboardFixture, testPrivacyMaskController;

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> getProfile(String idToken) async => UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'test@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
    isAdmin: false,
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

/// The narrow phone the single-column dashboard layout is for.
const _narrow = Size(320, 640);

/// The maskable tiles, in the order they are laid out inside their section.
const _healthTiles = [
  'home-latest-weight',
  'home-food-dictionary',
  'home-latest-blood-pressure',
  'home-menstrual-prediction',
];
const _financeTiles = [
  'home-budget',
  'home-total-assets',
  'home-total-liabilities',
  'home-split-overview',
];

Key _eyeKey(PrivacyMaskItem item) => Key('home-mask-toggle-${item.name}');

/// A loaded dashboard whose budget line is the longest string the finance
/// section ever prints — the worst case for a row that also has to hold an
/// eye. Unmasked, because a masked tile is the *easy* case: `••••` is short.
HomeDashboardController _longestValuesFixture() =>
    loadedDashboardFixture()
      ..data = const HomeDashboardData(
        weightGoal: WeightGoal(currentWeightKg: 102.5),
        bloodPressure: null,
        menstrualStatus: NextPeriodStatus(state: NextPeriodState.noRecords),
        overallBudget: FinanceBudget(
          id: 'b1',
          categoryId: null,
          amount: 99999999999,
          spent: 1,
          remaining: 99999999999,
          percent: 1,
        ),
        netWorth: MonthlyNetWorth(
          month: '2026-01',
          accounts: [],
          totalAsset: 99999999999,
          totalLiability: 99999999999,
          netWorth: 0,
          prevNetWorth: null,
          growthRate: null,
        ),
        splitBalances: [
          Balance(
            userId: 'friend-1',
            displayName: 'Friend',
            balances: [CurrencyBalance(currency: 'TWD', amount: 99999999999)],
          ),
        ],
      );

/// A loaded dashboard whose every figure fits on ONE line at 320dp, so all
/// four tiles of a section sit at the tile minimum height. That is exactly
/// where an eye-induced height difference shows: a value long enough to wrap
/// sets its own tile's height and hides the effect.
HomeDashboardController _evenValuesFixture() =>
    loadedDashboardFixture()
      ..data = const HomeDashboardData(
        weightGoal: WeightGoal(currentWeightKg: 62.5),
        bloodPressure: null,
        menstrualStatus: NextPeriodStatus(state: NextPeriodState.noRecords),
        overallBudget: FinanceBudget(
          id: 'b1',
          categoryId: null,
          amount: 900,
          spent: 100,
          remaining: 800,
          percent: 11,
        ),
        netWorth: MonthlyNetWorth(
          month: '2026-01',
          accounts: [],
          totalAsset: 900,
          totalLiability: 700,
          netWorth: 200,
          prevNetWorth: null,
          growthRate: null,
        ),
        splitBalances: [],
      );

class _Pumped {
  final HomeController controller;
  final PrivacyMaskController mask;

  _Pumped(this.controller, this.mask);
}

/// `_DashboardSection`'s title row (e.g. 財務 + 開啟財務) overflows by this
/// much at 320dp on this build — **pre-existing and unrelated to the eye**:
/// it reproduces with the placeholder dashboard, which has neither an eye nor
/// a long value. Left alone (CLAUDE.md §3) and excluded by exact amount, so a
/// real eye-induced overflow (a different amount, a different row) still
/// fails, and fixing the original makes [_expectOnlyKnownOverflow]'s count
/// assertion say so rather than silently widening the hole.
const _knownSectionHeaderOverflow = 'overflowed by 0.257 pixels';

void _expectOnlyKnownOverflow(
  List<FlutterErrorDetails> errors, {
  // Only the initial build reproduces the known section-header overflow
  // (see `_knownSectionHeaderOverflow`) — the `_guarded` calls later
  // callers make around a tap/settle see an already-built tree and report
  // none. So the "exactly one known overflow, not silently more" pin below
  // only applies when [expectKnown] says this run is the initial build.
  bool expectKnown = false,
}) {
  final known = errors.where(
    (e) => e.toString().contains(_knownSectionHeaderOverflow),
  );
  final unexpected = errors
      .where((e) => !e.toString().contains(_knownSectionHeaderOverflow))
      .map((e) => e.exception.toString().split('\n').first)
      .toList();
  expect(unexpected, isEmpty, reason: 'new layout errors at 320dp');
  if (expectKnown) {
    // Pins the allowance to exactly the one known overflow — so a *second*
    // error that happens to also read "overflowed by 0.257 pixels" isn't
    // silently swallowed alongside it, and so fixing the section header
    // (which makes this list empty) is the signal to delete the allowance.
    expect(
      known,
      hasLength(1),
      reason:
          'the known section-header overflow: fix it and delete this allowance',
    );
  }
}

/// Runs [body] with layout errors captured (so the binding never stores one
/// and quietly swallows the *second*), then asserts nothing new broke.
Future<void> _guarded(Future<void> Function() body, {bool expectKnown = false}) async {
  _expectOnlyKnownOverflow(await collectLayoutErrors(body), expectKnown: expectKnown);
}

Future<_Pumped> _pumpAt(
  WidgetTester tester,
  Size size, {
  HomeDashboardController? dashboardController,
  PrivacyMaskController? privacyMaskController,
  // 360dp/1200dp have no known pre-existing overflow (that's only
  // reproduced at 320dp — see `_knownSectionHeaderOverflow`), so those two
  // callers pass `strict: true` to demand zero layout errors instead of
  // tolerating the 320dp allowance, which would otherwise also swallow a
  // *new* overflow at these widths.
  bool strict = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = HomeController(
    GetProfile(_FakeProfileRepository()),
    SignOut(_FakeAuthRepository()),
  );
  await controller.load('token-123');
  final mask = privacyMaskController ?? await testPrivacyMaskController();
  Future<void> pump() async {
    await tester.pumpWidget(
      l10nTestApp(
        theme: lightTheme,
        home: HomeScreen(
          controller: controller,
          privacyMaskController: mask,
          dashboardController: dashboardController,
        ),
      ),
    );
    await tester.pump();
  }

  if (strict) {
    await expectNoLayoutErrors(pump);
  } else {
    await _guarded(pump, expectKnown: true);
  }
  return _Pumped(controller, mask);
}

List<double> _heightsOf(WidgetTester tester, List<String> tileKeys) => [
  for (final key in tileKeys) tester.getSize(find.byKey(Key(key))).height,
];

void main() {
  group('HomeScreen responsive layout', () {
    testWidgets('narrow phone width: dashboard sections have no overflow', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(360, 800), strict: true);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('health-dashboard-section')), findsOneWidget);
      expect(
        find.byKey(const Key('finance-dashboard-section')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('primary-navigation-bar')), findsNothing);
    });

    testWidgets('wide desktop width: dashboard content remains bounded', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(1200, 800), strict: true);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('health-dashboard-section')), findsOneWidget);
      expect(
        find.byKey(const Key('finance-dashboard-section')),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen privacy eye at 320dp', () {
    setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
    tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

    testWidgets(
      'R1: the longest values plus an eye still fit the narrowest tile',
      (tester) async {
        // The assertion lives in `_pumpAt`'s `_guarded` wrapper, which uses
        // `collectLayoutErrors` rather than `takeException` — the binding
        // keeps only the FIRST exception, so with the pre-existing section
        // header overflow already in hand a new tile overflow would be
        // dropped on the floor.
        await _pumpAt(
          tester,
          _narrow,
          dashboardController: _longestValuesFixture(),
        );

        // …and the labels beside the eye were not silently truncated to make
        // room, which no overflow error would report.
        for (final label in const [
          'Latest weight',
          'Monthly budget',
          'Total assets',
          'Total liabilities',
        ]) {
          expectPaintedInFull(tester, find.text(label), reason: label);
          // Every glyph painting is not "not silently truncated to make
          // room": `Expanded` can still shrink the label onto a second (or
          // third) line while painting every character in full. Pin the
          // line count too, so a label that wraps one line further than
          // today doesn't pass unnoticed.
          expect(
            paintedTextLineCount(tester, find.text(label)),
            lessThanOrEqualTo(2),
            reason: label,
          );
        }
      },
    );

    testWidgets(
      'R2 LINCHPIN: eyed and eyeless tiles are exactly the same height',
      (tester) async {
        // Realistic figures on purpose: every tile then sits at the tile
        // minimum, which is precisely where a taller "has an eye" tile shows
        // up — `Wrap` does not stretch a short run item to match a tall one,
        // so the row goes visibly ragged.
        await _pumpAt(
          tester,
          _narrow,
          dashboardController: _evenValuesFixture(),
        );

        final finance = _heightsOf(tester, _financeTiles);
        expect(
          finance.toSet(),
          hasLength(1),
          reason: 'finance tile heights: $finance (3 with an eye, 1 without)',
        );
        final health = _heightsOf(tester, _healthTiles);
        expect(
          health.toSet(),
          hasLength(1),
          reason: 'health tile heights: $health (1 with an eye, 3 without)',
        );
      },
    );

    testWidgets('R3: every eye is a 44pt target inside its own tile', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        _narrow,
        dashboardController: loadedDashboardFixture(),
      );

      const owner = {
        PrivacyMaskItem.latestWeight: 'home-latest-weight',
        PrivacyMaskItem.budget: 'home-budget',
        PrivacyMaskItem.totalAssets: 'home-total-assets',
        PrivacyMaskItem.totalLiabilities: 'home-total-liabilities',
      };
      for (final entry in owner.entries) {
        final eye = find.byKey(_eyeKey(entry.key));
        final size = tester.getSize(eye);
        expect(size.width, greaterThanOrEqualTo(44), reason: entry.key.name);
        expect(size.height, greaterThanOrEqualTo(44), reason: entry.key.name);

        // Inside its OWN tile: an eye that has spilled over the tile edge is
        // both a layout bug and a mis-tap waiting to happen.
        final tile = tester.getRect(find.byKey(Key(entry.value)));
        final rect = tester.getRect(eye);
        expect(
          tile.contains(rect.topLeft) && tile.contains(rect.bottomRight),
          isTrue,
          reason: '${entry.key.name} eye $rect escapes its tile $tile',
        );
      }
    });

    testWidgets('R4: a real tap at 320dp actually flips the mask', (
      tester,
    ) async {
      // Not "the eye can be found": at this width the finance tiles sit below
      // the fold, where an un-scrolled `tap` derives an off-screen offset,
      // hits the view instead and only warns — which is why the group makes
      // that warning fatal.
      final pumped = await _pumpAt(
        tester,
        _narrow,
        dashboardController: loadedDashboardFixture(),
      );

      for (final item in PrivacyMaskItem.values) {
        final before = pumped.mask.isHidden(item);
        await _guarded(() async {
          await tester.ensureVisible(find.byKey(_eyeKey(item)));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(_eyeKey(item)));
          await tester.pumpAndSettle();
        });
        expect(pumped.mask.isHidden(item), !before, reason: item.name);
      }
    });

    testWidgets(
      'R5: masking changes neither the layout nor the tile heights',
      (tester) async {
        final pumped = await _pumpAt(
          tester,
          _narrow,
          dashboardController: _evenValuesFixture(),
        );
        final financeBefore = _heightsOf(tester, _financeTiles);
        final healthBefore = _heightsOf(tester, _healthTiles);

        await _guarded(() async {
          for (final item in PrivacyMaskItem.values) {
            await pumped.mask.setHidden(item, true);
          }
          await tester.pumpAndSettle();
        });

        expect(_heightsOf(tester, _financeTiles), financeBefore);
        expect(_heightsOf(tester, _healthTiles), healthBefore);
      },
    );

    testWidgets(
      'R5b: the worst case — three masked, the longest value NOT masked',
      (tester) async {
        // A fully masked screen is the easy case (`••••` is short). The row
        // that has to survive is the one still printing the longest string
        // next to an eye.
        final pumped = await _pumpAt(
          tester,
          _narrow,
          dashboardController: _longestValuesFixture(),
        );

        await _guarded(() async {
          for (final item in PrivacyMaskItem.values) {
            if (item == PrivacyMaskItem.budget) continue;
            await pumped.mask.setHidden(item, true);
          }
          await tester.pumpAndSettle();
        });

        expectPaintedInFull(tester, find.text('Monthly budget'));
      },
    );
  });
}
