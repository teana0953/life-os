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

/// TWD amount used to build the "not split mid-digit" fixture below —
/// spelled out here so both the fixture and its assertions read the same
/// literal instead of two independently-typed copies of "456700".
const _budgetRemainingMinorUnits = 456700;

/// TWD amount for the same fixture's net-worth tile — a different value from
/// [_budgetRemainingMinorUnits] on purpose, so a `find.text` lookup for
/// either printed string can never match both tiles.
const _netWorthMinorUnits = 9999999;

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

/// Traditional Chinese — the only locale whose dashboard labels can actually
/// falsify a column-breakpoint threshold (plan §2d: English wraps 3–6 lines
/// on both sides of any realistic threshold and stays on the same side).
const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

/// The maskable tiles, in the order they are laid out inside their section.
const _healthTiles = [
  'home-latest-weight',
  'home-food-dictionary',
  'home-latest-blood-pressure',
  'home-menstrual-prediction',
];
const _financeTiles = [
  'home-budget',
  'home-net-worth',
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
          // The widest thing this tile can print: 15 characters, sign
          // included — wider than the 14-character liability figure.
          netWorth: -99999999999,
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

/// Like [_longestValuesFixture], but with a realistic-magnitude figure
/// (`9,999,999` instead of the eye guards' `99,999,999,999`) — the correct
/// instrument for the two-column breakpoint. The 11-digit fixture wraps to 3
/// lines on both sides of the boundary (plan §2c: value line counts of 2/2/3
/// at inner 264/258/254 for `9,999,999`, vs 3/3/3 at every one of those
/// widths for `99,999,999`), so it cannot distinguish the two sides — a
/// same-side fixture that would pass whether or not the threshold moved.
HomeDashboardController _longestRealisticFixture() =>
    loadedDashboardFixture()
      ..data = const HomeDashboardData(
        weightGoal: WeightGoal(currentWeightKg: 102.5),
        bloodPressure: null,
        menstrualStatus: NextPeriodStatus(state: NextPeriodState.noRecords),
        overallBudget: FinanceBudget(
          id: 'b1',
          categoryId: null,
          amount: 9999999,
          spent: 1,
          remaining: 9999999,
          percent: 1,
        ),
        netWorth: MonthlyNetWorth(
          month: '2026-01',
          accounts: [],
          totalAsset: 9999999,
          totalLiability: 9999999,
          netWorth: -9999999,
          prevNetWorth: null,
          growthRate: null,
        ),
        splitBalances: [
          Balance(
            userId: 'friend-1',
            displayName: 'Friend',
            balances: [CurrencyBalance(currency: 'TWD', amount: 9999999)],
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

/// A loaded dashboard whose finance figures are two concrete, human-scale
/// amounts — `456,700` (behind 本月預算's "剩餘 …" wrapper) and `9,999,999`
/// (printed bare on 淨值) — the pair the Samsung Flip7 regression (issue
/// #189) was actually about: at 360/361dp a thousands-grouped number used to
/// get hard-wrapped mid-digit (`456,70` / `0`). Neither figure needs to be
/// the *longest* the screen can print (that's `_longestRealisticFixture` /
/// `_longestValuesFixture`, which guard illegibility from length) — this
/// fixture exists only to pin two exact, greppable strings a
/// `paintedLineCountOfPart` check can look for.
HomeDashboardController _financeAmountsFixture() =>
    loadedDashboardFixture()
      ..data = const HomeDashboardData(
        weightGoal: WeightGoal(currentWeightKg: 62.5),
        bloodPressure: null,
        menstrualStatus: NextPeriodStatus(state: NextPeriodState.noRecords),
        overallBudget: FinanceBudget(
          id: 'b1',
          categoryId: null,
          amount: 500000,
          spent: 43300,
          remaining: _budgetRemainingMinorUnits,
          percent: 9,
        ),
        netWorth: MonthlyNetWorth(
          month: '2026-01',
          accounts: [],
          totalAsset: _netWorthMinorUnits,
          // Deliberately not equal to `_netWorthMinorUnits`: 總負債 prints the
          // same bare-number format as 淨值, and an identical value would
          // make `find.text('9,999,999')` match two tiles instead of one.
          totalLiability: 8765432,
          netWorth: _netWorthMinorUnits,
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
  // Defaults to English to match the app's fallback locale and every
  // existing caller. Breakpoint guards must pass `Locale.fromSubtags(
  // languageCode: 'zh', scriptCode: 'Hant')`: English labels wrap 3–6 lines
  // on both sides of the threshold and cannot falsify it (see plan §2d).
  Locale locale = const Locale('en'),
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
        locale: locale,
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

/// Whether the first two tiles of a section (e.g. `home-latest-weight` and
/// `home-food-dictionary`) sit side by side — same row `top`, different
/// `left` — rather than one below the other. A behavioural check, not a
/// width-arithmetic one: a width-only assertion still passes if the `Wrap`
/// stops wrapping, and a relation-only assertion still passes if `tileWidth`
/// is miscomputed, so B1 asserts both this and the tile width.
bool _isTwoColumns(WidgetTester tester, List<String> tileKeys) {
  final first = tester.getRect(find.byKey(Key(tileKeys[0])));
  final second = tester.getRect(find.byKey(Key(tileKeys[1])));
  return first.top == second.top && first.left != second.left;
}

void main() {
  group('HomeScreen responsive layout', () {
    testWidgets(
      '360dp phone: the two-column dashboard has no overflow',
      (tester) async {
        await _pumpAt(tester, const Size(360, 800), strict: true);

        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('finance-dashboard-section')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('primary-navigation-bar')), findsNothing);

        // 360dp crossed the HEALTH breakpoint (plan §0/§3: was single column
        // below ~402dp, now two above ~332dp) — name and assert it, so a
        // future threshold move that puts 360dp back on the single-column
        // side fails loudly here instead of silently changing what this test
        // covers.
        expect(_isTwoColumns(tester, _healthTiles), isTrue);
        // Finance did NOT move — it keeps the original, higher threshold
        // (issue #189: a two-column finance tile at this width hard-wraps a
        // money value mid-digit). See the "Samsung Flip7 breakpoint" group
        // below for the dedicated regression coverage.
        expect(_isTwoColumns(tester, _financeTiles), isFalse);
      },
    );

    testWidgets('wide desktop width: dashboard content remains bounded', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(1200, 800), strict: true);

      expect(find.byKey(const Key('health-dashboard-section')), findsOneWidget);
      expect(
        find.byKey(const Key('finance-dashboard-section')),
        findsOneWidget,
      );
    });
  });

  group('Samsung Flip7 breakpoint (issue #189)', () {
    // The user's two actually-measured real-device widths: outer screen
    // 361px, inner screen 360px. Each gets its own test (not a loop) so a
    // regression on just one of the two fails with that width in the test
    // name, not buried inside a shared failure message.
    for (final width in [360.0, 361.0]) {
      testWidgets(
        '${width.toInt()}dp: health section is two columns, '
        'finance section stays one column',
        (tester) async {
          await _pumpAt(
            tester,
            Size(width, 900),
            dashboardController: _financeAmountsFixture(),
            locale: _zhHant,
            strict: true,
          );

          expect(
            _isTwoColumns(tester, _healthTiles),
            isTrue,
            reason: 'health section should be two columns at ${width}dp',
          );
          expect(
            _isTwoColumns(tester, _financeTiles),
            isFalse,
            reason: 'finance section should stay one column at ${width}dp',
          );
        },
      );

      testWidgets(
        '${width.toInt()}dp LINCHPIN: finance amounts are not split mid-digit',
        (tester) async {
          await _pumpAt(
            tester,
            Size(width, 900),
            dashboardController: _financeAmountsFixture(),
            locale: _zhHant,
            strict: true,
          );

          // "456,700" lives inside 本月預算's "剩餘 456,700" wrapper —
          // `find.text` needs the substring form, not an exact match.
          final budgetValue = find.descendant(
            of: find.byKey(const Key('home-budget')),
            matching: find.textContaining('456,700'),
          );
          expect(
            paintedLineCountOfPart(tester, budgetValue, '456,700'),
            1,
            reason: '本月預算 value at ${width}dp',
          );

          final netWorthValue = find.descendant(
            of: find.byKey(const Key('home-net-worth')),
            matching: find.textContaining('9,999,999'),
          );
          expect(
            paintedLineCountOfPart(tester, netWorthValue, '9,999,999'),
            1,
            reason: '淨值 value at ${width}dp',
          );
        },
      );
    }

    testWidgets('320dp: both sections stay one column', (tester) async {
      // Default (English) locale, matching every other 320dp test in this
      // file — the pre-existing known section-header overflow `_pumpAt`
      // tolerates is measured against that locale, and this boolean
      // one-column-vs-two check does not depend on locale anyway (it is
      // purely a width-vs-threshold comparison).
      await _pumpAt(
        tester,
        _narrow,
        dashboardController: loadedDashboardFixture(),
      );

      expect(_isTwoColumns(tester, _healthTiles), isFalse);
      expect(_isTwoColumns(tester, _financeTiles), isFalse);
    });

    testWidgets(
      '420dp: health is two columns, finance stays one '
      '(too narrow for a 2-column finance tile to hold 9,999,999 on one line)',
      (tester) async {
        await _pumpAt(
          tester,
          const Size(420, 900),
          dashboardController: _financeAmountsFixture(),
          locale: _zhHant,
          strict: true,
        );

        expect(_isTwoColumns(tester, _healthTiles), isTrue);
        expect(_isTwoColumns(tester, _financeTiles), isFalse);
      },
    );

    testWidgets(
      '430dp LINCHPIN: both sections go two columns without splitting money',
      (tester) async {
        await _pumpAt(
          tester,
          const Size(430, 900),
          dashboardController: _financeAmountsFixture(),
          locale: _zhHant,
          strict: true,
        );

        expect(_isTwoColumns(tester, _healthTiles), isTrue);
        expect(_isTwoColumns(tester, _financeTiles), isTrue);

        final budgetValue = find.descendant(
          of: find.byKey(const Key('home-budget')),
          matching: find.textContaining('456,700'),
        );
        expect(
          paintedLineCountOfPart(tester, budgetValue, '456,700'),
          1,
          reason: '本月預算 value at 430dp',
        );

        final netWorthValue = find.descendant(
          of: find.byKey(const Key('home-net-worth')),
          matching: find.textContaining('9,999,999'),
        );
        expect(
          paintedLineCountOfPart(tester, netWorthValue, '9,999,999'),
          1,
          reason: '淨值 value at 430dp',
        );
      },
    );
  });

  group('HomeScreen privacy eye at 320dp', () {
    setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
    tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

    testWidgets('320dp is single column — the narrowest tile this group covers', (
      tester,
    ) async {
      // The whole group's premise is that 320dp exercises "the narrowest
      // tile" — that was only ever assumed, never stated, and would
      // silently stop being true if the breakpoint ever moved past 320dp.
      await _pumpAt(tester, _narrow, dashboardController: loadedDashboardFixture());

      expect(_isTwoColumns(tester, _healthTiles), isFalse);
    });

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
          'Net worth',
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

        // The labels are only half of each row, and the half that is NOT the
        // reason this fixture exists. Measured: with only the four label
        // assertions above, this test stayed green both with the fixture's
        // net worth back at `0` and with 40 extra characters glued in front
        // of the tile's value — the widest string the screen prints was never
        // observed at all. Pin it: the widest value, beside an eye, at 320dp.
        const widestValue = '-99,999,999,999';
        // Named first, so a fixture (or a tile) that stopped printing this
        // string fails as "the widest value is gone" rather than as
        // `expectPaintedInFull`'s "Bad state: No element".
        expect(
          find.text(widestValue),
          findsOneWidget,
          reason: 'the net worth tile prints the fixture value verbatim',
        );
        expectPaintedInFull(
          tester,
          find.text(widestValue),
          reason: 'net worth value',
        );
        expect(
          paintedTextLineCount(tester, find.text(widestValue)),
          lessThanOrEqualTo(2),
          reason: 'net worth value',
        );
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
        PrivacyMaskItem.netWorth: 'home-net-worth',
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

  group('health section two-column breakpoint (260)', () {
    // Inner-width (LayoutBuilder's `constraints.maxWidth`) is
    // `screenWidth − 72` (plan §0: 20+20 page padding, 2+2 LedgeCard border,
    // 14+14 LedgeCard padding). 332 → inner 260 (two columns), 330 → inner
    // 258 (single column, measured floor — plan §2b). This pair only crosses
    // the HEALTH threshold (`_healthTwoColumnMinWidth` = 260) — the finance
    // section's own threshold is 330, so finance stays single column at both
    // of these widths and every assertion below that names a specific tile
    // deliberately reads a health tile, not a finance one.
    const aboveSize = Size(332, 2000);
    const belowSize = Size(330, 2000);

    testWidgets(
      'B1 LINCHPIN: the health breakpoint sits where measured, with a fixture on each side',
      (tester) async {
        await _pumpAt(
          tester,
          aboveSize,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );
        expect(
          _isTwoColumns(tester, _healthTiles),
          isTrue,
          reason: '332dp (inner 260) should be two columns',
        );
        final tile1 = tester.getSize(find.byKey(const Key('home-latest-weight')));
        expect(tile1.width, closeTo(125, 0.5));
      },
    );

    testWidgets(
      'B1 LINCHPIN: just below the health breakpoint stays single column',
      (tester) async {
        await _pumpAt(
          tester,
          belowSize,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );
        final tile1 = tester.getRect(find.byKey(const Key('home-latest-weight')));
        final tile2 = tester.getRect(find.byKey(const Key('home-food-dictionary')));
        expect(
          tile2.top,
          greaterThanOrEqualTo(tile1.bottom),
          reason: '330dp (inner 258) should be single column',
        );
        expect(tile1.width, closeTo(258, 0.5));
      },
    );

    testWidgets(
      'B2: at the two-column tile width, no health/finance label wraps '
      '(a font/label-change guard — NOT a threshold guard: it renders only '
      'at 332dp and is insensitive to `_healthTwoColumnMinWidth`\'s value; '
      'the threshold itself is pinned by B1 above and by the 320dp guard in '
      'the privacy-eye group)',
      (tester) async {
        await _pumpAt(
          tester,
          aboveSize,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );

        for (final key in [..._healthTiles, ..._financeTiles]) {
          final tile = find.byKey(Key(key));
          final labelFinder = find.descendant(
            of: tile,
            matching: find.byType(Text),
          );
          for (final element in labelFinder.evaluate()) {
            final textWidget = element.widget as Text;
            final text = textWidget.data;
            if (text == null || text.isEmpty) continue;
            final textFinder = find.text(text).first;
            expectPaintedInFull(tester, textFinder, reason: text);
          }
        }

        // Every tile label sits on exactly one line and every value on at
        // most two. For health this is exactly the measured floor (plan
        // §2b: inner 258 → labels 1 line, values ≤2 lines, 0 layout errors);
        // finance is single-column at inner 258 too (its own, higher
        // threshold), which gives it a whole 258px-wide tile — an easier
        // case, but still worth asserting so a regression there doesn't slip
        // through unnoticed.
        const labels = [
          '最新體重',
          '食物份量工具',
          '上次血壓',
          '生理週期預測',
          '本月預算',
          '淨值',
          '總負債',
          '分帳總覽',
        ];
        final found = <String>[];
        for (final label in labels) {
          final finder = find.text(label);
          if (finder.evaluate().isEmpty) continue;
          found.add(label);
          expect(
            paintedTextLineCount(tester, finder),
            equals(1),
            reason: label,
          );
        }
        // A renamed/removed l10n string must fail loudly here, not silently
        // shrink the loop above to fewer assertions.
        expect(found, labels, reason: 'every expected label must be found');
      },
    );

    testWidgets(
      'B3: the finance section sits higher on screen once the health section '
      'goes two columns (the whole reason for the split threshold: a shorter '
      'health section pulls finance up instead of leaving it stranded below '
      'the fold)',
      (tester) async {
        await _pumpAt(
          tester,
          aboveSize,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );
        final financeAbove = tester
            .getTopLeft(find.byKey(const Key('finance-dashboard-section')))
            .dy;

        await _pumpAt(
          tester,
          belowSize,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );
        final financeBelow = tester
            .getTopLeft(find.byKey(const Key('finance-dashboard-section')))
            .dy;

        expect(
          financeAbove,
          lessThan(financeBelow),
          reason:
              'two columns should push the finance section up, not leave it '
              'as far down as single column',
        );
      },
    );

    testWidgets(
      'B4: no overflow, no truncation, at and just below the threshold '
      '(NOTE: does not fail if the threshold is lowered — the tile cannot '
      'overflow until inner ≈150, plan §2a; B1 pins the threshold itself, '
      'B2 only guards label wrapping at the resulting tile width)',
      (tester) async {
        for (final locale in [const Locale('en'), _zhHant]) {
          for (final size in [aboveSize, belowSize]) {
            await _pumpAt(
              tester,
              size,
              dashboardController: _longestRealisticFixture(),
              locale: locale,
              strict: true,
            );
            for (final key in [..._healthTiles, ..._financeTiles]) {
              final tile = find.byKey(Key(key));
              final textFinders = find.descendant(
                of: tile,
                matching: find.byType(Text),
              );
              for (final element in textFinders.evaluate()) {
                final text = (element.widget as Text).data;
                if (text == null || text.isEmpty) continue;
                expectPaintedInFull(
                  tester,
                  find.text(text).first,
                  reason: '$text @ $size $locale',
                );
              }
            }
          }
        }
      },
    );
  });
}
