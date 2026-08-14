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

/// `_SnapshotTile`'s own padding (12 each side). Its 1px border is *not*
/// subtracted here on purpose: leaving those 2px in makes the "the value fits
/// inside the tile" assertion below slightly lenient rather than
/// off-by-one-brittle, and every real failure mode (a value painted at full
/// size in a tile too narrow for it) misses by tens of pixels, not by two.
const _tilePadding = 24.0;

/// The floor `_financeAmountsFixture`'s amounts stay above in the two-column
/// layouts these guards render, at the widths issues #189/#190 named — not a
/// universal floor over every string the app can print (a longer real
/// balance shrinks further still; see `home_screen.dart`'s
/// `_sectionTwoColumnMinWidth` doc for the narrowest-tile numbers, which do
/// dip below this).
///
/// Measured on this build (zh-Hant, `_financeAmountsFixture`, painted scale of
/// the value `Text` under `_SnapshotTile`'s `FittedBox`):
///
/// | screen | tile | 剩餘 456,700 | 9,999,999 |
/// | --- | --- | --- | --- |
/// | 360dp | 139 | 0.700 | 0.777 |
/// | 361dp | 139.5 | 0.703 | 0.781 |
/// | 402dp | 160 | 0.830 | 0.922 |
/// | 412dp | 165 | 0.861 | 0.956 |
/// | 420dp | 169 | 0.885 | 0.984 |
/// | 430dp | 174 | 0.916 | 1.000 |
///
/// So the worst case at these widths is 0.700 and the floor sits below it
/// with room for font-metric drift. It is not a re-statement of the
/// implementation: shrink-to-fit alone would happily paint a figure at 0.2×
/// and still be "one line, not truncated" — this is the assertion that says
/// the fix has to stay *readable*, and the one that goes red if a tile gets
/// narrower or the value font bigger.
const _minValueScale = 0.65;

/// The same floor for the single narrowest two-column tile that exists
/// (screen 332dp → inner 260 → tile 125), measured with the deliberately
/// over-long `_longestRealisticFixture`: `剩餘 9,999,999` paints at 0.511
/// there, `9,999,999` and the health prose value `再記錄一次即可預測` at 0.681.
/// Lower than [_minValueScale] because this is the extreme corner (widest
/// realistic string × narrowest tile), not a width a real figure is expected
/// to be read at.
const _minValueScaleAtNarrowestTile = 0.45;

/// Asserts the snapshot value containing [part] inside tile [tileKey] is
/// painted as **one un-truncated line that fits its tile and is still
/// legible**.
///
/// All three parts are needed, and the first one alone is a guard that cannot
/// fail. `_SnapshotTile` wraps its value in a `FittedBox`, which lays the
/// paragraph out at its natural width and *then* scales it — so under it
/// `paintedLineCountOfPart` is 1 at every screen width whatever the tile does,
/// and `BoxFit.scaleDown` can never raise an overflow either. The falsifiable
/// halves are the painted rect (proves the figure fits the tile: red if the
/// `FittedBox` stops scaling) and the painted scale (proves it was not
/// "fixed" by shrinking it into unreadability).
///
/// Verified by mutation, one at a time, against this file:
///
/// | mutation | result |
/// | --- | --- |
/// | `BoxFit.scaleDown` → `BoxFit.none` | RED — rect: `161.50px wide inside a 174.00px tile` |
/// | value style `titleMedium` → `headlineMedium` | RED — scale: `shrunk to 0.529×, below … 0.65` |
/// | `_tileValue` → plain `Text` (no `FittedBox`) | RED — line count: `Expected: <1> Actual: <2>` |
/// | drop `maxLines: 1` | **GREEN** — see below |
/// | drop `maxLines: 1` *and* `softWrap: false` | **GREEN** — see below |
///
/// The last two are the honest caveat: while the `FittedBox` is there, the
/// paragraph is laid out at unbounded width, so nothing wraps whatever those
/// two properties say, and no assertion here can see them go. They are kept
/// in the implementation as protection for a future edit that removes the
/// `FittedBox` — but nothing in this file guards them, and adding an
/// assertion that "checks" them would be a guard that cannot fail.
void _expectValueFitsOneLine(
  WidgetTester tester,
  String tileKey,
  String part, {
  required double minScale,
  required String reason,
}) {
  final value = find.descendant(
    of: find.byKey(Key(tileKey)),
    matching: find.textContaining(part),
  );
  expect(value, findsOneWidget, reason: '$reason: value not found');
  expect(
    paintedLineCountOfPart(tester, value, part),
    1,
    reason: '$reason: painted line count',
  );

  final tile = tester.getRect(find.byKey(Key(tileKey)));
  final painted = tester.getRect(value);
  expect(
    painted.width,
    lessThanOrEqualTo(tile.width - _tilePadding),
    reason:
        '$reason: painted ${painted.width.toStringAsFixed(2)}px wide inside a '
        '${tile.width.toStringAsFixed(2)}px tile',
  );

  final scale = paintedScaleOf(tester, value);
  expect(
    scale,
    greaterThanOrEqualTo(minScale),
    reason:
        '$reason: shrunk to ${scale.toStringAsFixed(3)}×, below the legibility '
        'floor of $minScale',
  );
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
        // Finance now moves with it. It used to keep its own, higher
        // threshold (330) so that a money value could never land in a tile
        // narrow enough to hard-wrap mid-digit (issue #189) — but the value
        // is shrink-to-fit now, so there is no wrap left to dodge and both
        // sections share one breakpoint. The "Samsung Flip7 breakpoint"
        // group below is what pins the figures themselves.
        expect(_isTwoColumns(tester, _financeTiles), isTrue);
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
        '${width.toInt()}dp: both sections are two columns',
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
          // Was `isFalse`: #189 was originally fixed by keeping finance
          // single-column at these widths. The tile now shrinks the figure
          // instead, so finance follows the same breakpoint as health — the
          // LINCHPIN below is what proves the figures survive it.
          expect(
            _isTwoColumns(tester, _financeTiles),
            isTrue,
            reason: 'finance section should be two columns at ${width}dp',
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
          // `find.textContaining` is the substring form this needs.
          _expectValueFitsOneLine(
            tester,
            'home-budget',
            '456,700',
            minScale: _minValueScale,
            reason: '本月預算 value at ${width}dp',
          );
          _expectValueFitsOneLine(
            tester,
            'home-net-worth',
            '9,999,999',
            minScale: _minValueScale,
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

    // 402/412/420dp (iPhone 16 Pro, Pixel 8/9): these three used to be
    // *characterization* tests for issue #190 — finance was two columns here
    // (inner >= the old 330 threshold) with a tile (160/165/169px) below the
    // 171.5px a 7-digit amount needed, so `9,999,999` split mid-digit and the
    // assertion below read `2`. #190 is fixed: the value shrinks to fit
    // instead of wrapping, so it is `1` at all three widths, and the measured
    // scale (0.92/0.96/0.98 for 淨值) says it did not have to shrink much to
    // get there.
    for (final width in [402.0, 412.0, 420.0]) {
      testWidgets(
        '${width.toInt()}dp (issue #190): finance is two columns and '
        '9,999,999 stays whole',
        (tester) async {
          await _pumpAt(
            tester,
            Size(width, 900),
            dashboardController: _financeAmountsFixture(),
            locale: _zhHant,
            strict: true,
          );

          expect(_isTwoColumns(tester, _healthTiles), isTrue);
          expect(
            _isTwoColumns(tester, _financeTiles),
            isTrue,
            reason: 'finance section should be two columns at ${width}dp',
          );

          _expectValueFitsOneLine(
            tester,
            'home-net-worth',
            '9,999,999',
            minScale: _minValueScale,
            reason: '淨值 value at ${width}dp (issue #190)',
          );
          _expectValueFitsOneLine(
            tester,
            'home-budget',
            '456,700',
            minScale: _minValueScale,
            reason: '本月預算 value at ${width}dp (issue #190)',
          );
        },
      );
    }

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

        _expectValueFitsOneLine(
          tester,
          'home-budget',
          '456,700',
          minScale: _minValueScale,
          reason: '本月預算 value at 430dp',
        );
        _expectValueFitsOneLine(
          tester,
          'home-net-worth',
          '9,999,999',
          minScale: _minValueScale,
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
        // Was `paintedTextLineCount(...) <= 2`. That reading is now
        // structurally 1 — the value sits under a `FittedBox`, which lays the
        // paragraph out at unbounded width — so "at most 2 lines" could not
        // fail whatever the layout did. What is still falsifiable at this
        // width is that the figure fits the tile and is not shrunk into
        // illegibility (measured here: 0.916×, 222px painted inside a 248px
        // tile).
        _expectValueFitsOneLine(
          tester,
          'home-net-worth',
          widestValue,
          minScale: _minValueScale,
          reason: 'net worth value at 320dp',
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

  group('section two-column breakpoint (260)', () {
    // Inner-width (LayoutBuilder's `constraints.maxWidth`) is
    // `screenWidth − 72` (plan §0: 20+20 page padding, 2+2 LedgeCard border,
    // 14+14 LedgeCard padding). 332 → inner 260 (two columns), 330 → inner
    // 258 (single column, measured floor — plan §2b). Both sections now share
    // that one threshold (`_sectionTwoColumnMinWidth`), so 332dp is where the
    // narrowest two-column tile in the app exists — 125px, for finance as
    // well as health. B2 below is the only place a two-column *finance* tile
    // that narrow gets measured.
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
      'B2: at the two-column tile width, no health/finance label wraps and '
      'the narrowest finance value still fits and is legible (renders only '
      'at 332dp; the threshold itself is pinned by B1 above and by the '
      '320dp guard in the privacy-eye group)',
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

        // Every tile label sits on exactly one line. This is exactly the
        // measured floor (plan §2b: inner 258 → labels 1 line, 0 layout
        // errors), and since both sections share the 260 threshold it is now
        // asserted for the finance labels in a 125px two-column tile too —
        // measured: 本月預算/淨值/總負債/分帳總覽 all still 1 line there. Labels
        // are NOT shrink-to-fit (only values are), so unlike the value
        // assertions below this one can fail by wrapping.
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

        // The narrowest two-column tile in the app (125px) with the widest
        // realistic figures in it — the corner the shrink-to-fit value has to
        // survive. Measured on this build: 剩餘 9,999,999 at 0.511×,
        // -9,999,999 at 0.613×, both painted 99px wide inside the 125px tile.
        expect(
          tester.getSize(find.byKey(const Key('home-budget'))).width,
          closeTo(125, 0.5),
          reason: 'finance is two columns at 332dp too',
        );
        _expectValueFitsOneLine(
          tester,
          'home-budget',
          '9,999,999',
          minScale: _minValueScaleAtNarrowestTile,
          reason: '本月預算 value in the narrowest two-column tile',
        );
        _expectValueFitsOneLine(
          tester,
          'home-net-worth',
          '-9,999,999',
          minScale: _minValueScaleAtNarrowestTile,
          reason: '淨值 value in the narrowest two-column tile',
        );
      },
    );

    testWidgets(
      'B3: crossing the threshold pulls finance above the fold and makes '
      'both sections shorter (the whole reason for the breakpoint: two '
      'columns pull the dashboard up instead of stranding the lower half '
      'below the fold)',
      (tester) async {
        // The `top`-of-finance comparison needs a realistic phone height to
        // show anything: at `aboveSize`/`belowSize` below (2000px tall, used
        // for the height comparison so nothing is clipped) the whole
        // dashboard fits and the page centres its content vertically, so the
        // block above finance shrinks by exactly as much as the centring
        // offset grows and finance's `top` ties at 1070.0 either width. A
        // real phone viewport scrolls instead of centring, so the pull-up is
        // visible there.
        const realisticAbove = Size(332, 740);
        const realisticBelow = Size(330, 740);

        await _pumpAt(
          tester,
          realisticAbove,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );
        final financeTopAbove = tester
            .getRect(find.byKey(const Key('finance-dashboard-section')))
            .top;

        await _pumpAt(
          tester,
          realisticBelow,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );
        final financeTopBelow = tester
            .getRect(find.byKey(const Key('finance-dashboard-section')))
            .top;

        expect(
          financeTopAbove,
          lessThan(financeTopBelow),
          reason:
              'two columns should pull the finance section higher '
              '($financeTopAbove vs $financeTopBelow)',
        );

        double heightOf(String key) =>
            tester.getSize(find.byKey(Key(key))).height;

        await _pumpAt(
          tester,
          aboveSize,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );
        final healthAbove = heightOf('health-dashboard-section');
        final financeAbove = heightOf('finance-dashboard-section');

        await _pumpAt(
          tester,
          belowSize,
          dashboardController: _longestRealisticFixture(),
          locale: _zhHant,
          strict: true,
        );
        final healthBelow = heightOf('health-dashboard-section');
        final financeBelow = heightOf('finance-dashboard-section');

        expect(
          healthAbove,
          lessThan(healthBelow),
          reason:
              'two columns should make the health section shorter '
              '($healthAbove vs $healthBelow)',
        );
        expect(
          financeAbove,
          lessThan(financeBelow),
          reason:
              'two columns should make the finance section shorter '
              '($financeAbove vs $financeBelow)',
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
