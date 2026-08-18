import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/menstrual/domain/next_period_status.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/privacy/privacy_mask_controller.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import 'home_screen_test.dart'
    show loadedDashboardFixture, testDailyTarget, testPrivacyMaskController;

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
      ..data = HomeDashboardData.allLoaded(
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
        dailyTarget: testDailyTarget,
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
      ..data = HomeDashboardData.allLoaded(
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
        dailyTarget: testDailyTarget,
      );

/// A loaded dashboard whose every figure fits on ONE line at 320dp, so all
/// four tiles of a section sit at the tile minimum height. That is exactly
/// where an eye-induced height difference shows: a value long enough to wrap
/// sets its own tile's height and hides the effect.
HomeDashboardController _evenValuesFixture() =>
    loadedDashboardFixture()
      ..data = HomeDashboardData.allLoaded(
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
        dailyTarget: testDailyTarget,
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
      ..data = HomeDashboardData.allLoaded(
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
        dailyTarget: testDailyTarget,
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
  /// Wired only by the per-tile failure guards: without a token provider the
  /// screen offers no retry at all, so the shape they measure would not be
  /// the shipped one.
  Future<String> Function()? idToken,
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
  /// `false` leaves layout errors to the CALLER to collect and judge. Nesting
  /// this helper inside `collectLayoutErrors` instead does not work: its own
  /// assertions then run against a swallowed error list and report the
  /// *absence* of the known 320dp overflow.
  bool guard = true,
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
          idToken: idToken,
        ),
      ),
    );
    await tester.pump();
  }

  if (!guard) {
    await pump();
  } else if (strict) {
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
///
/// **Exactly which assertions use it, and why — no blanket claim.** Three:
/// the two `_longestRealisticFixture` finance values at 332dp (its own
/// corner), and the 食物份量 value at 332dp, which paints its short candidate
/// `10主 7肉 2果…` at 0.613 there. Everything wider is held to
/// [_minValueScale]: after the round-3 separator tightening the food value
/// measures 0.700 at 360dp, 0.650 at 386dp and 0.661 at 390dp, so the
/// 332dp tile is the only width on that tile still under 0.65. It is
/// scoped to that corner, not to the food tile generally.
const _minValueScaleAtNarrowestTile = 0.45;

/// Every non-empty semantics label at or under the semantics node enclosing
/// [finder].
///
/// Reads `SemanticsNode`s, not `Semantics` *widgets*, and that distinction is
/// the whole point: a `Text` contributes its string to the semantics tree
/// through its `RenderParagraph`, inserting no `Semantics` widget, so a
/// widget-predicate search for a painted string is a guard that cannot fail.
/// Requires a live `tester.ensureSemantics()` handle.
///
/// It still only reads the widget-tree semantics cache — it says nothing
/// about what a real screen reader on a real device receives.
List<String> _semanticsLabelsUnder(WidgetTester tester, Finder finder) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(finder));
  return labels;
}

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
      //
      // Deliberately NOT `strict: true`, and measured rather than assumed:
      // 320dp is the one width that reproduces the pre-existing
      // section-header overflow (`_knownSectionHeaderOverflow`, 0.257px), so
      // `strict` here fails on that alone — with the tile floor at 110 *and*
      // at 128, i.e. it would be a red that says nothing about this tile.
      // The `expectKnown` path this takes instead still fails on any
      // *additional* overflow. What actually pins the tile floor is the
      // finance-tile tap in `home_screen_test.dart`: raising the floor to 128
      // pushes that tile off the 800×600 viewport and the tap finds nothing
      // (measured: `Found 0 widgets with text "FINANCE-ROUTE"`).
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
          reason:
              'health tile heights: $health (1 with an eye — 食物份量 also '
              'has a same-size 44pt action icon, but no eye — 2 with no '
              'icon at all)',
        );

        // Equality alone does not pin the floor: every tile shrinking to 60
        // together would satisfy it. `_SnapshotTile`'s `minHeight: 110` is
        // the number that makes an eyed tile's 44pt tap target fit without
        // growing the row, so assert it as a LOWER bound, here, where a
        // failure reads as a height.
        //
        // The only other reading of 110 in the suite is the finance tap in
        // `home_screen_test.dart`, and it is an *upper* bound with zero
        // margin (111 already pushes the tile below the fold) that fails with
        // a navigation message. That one is incidental; this is the property.
        //
        // Verified falsifiable on its own, not merely shadowed by the
        // equality above it: `minHeight: 92` reds the equality first
        // (`Set:[108.0, 92.0]` — the eyed tile grows, the eyeless one does
        // not), so the discriminating mutation is `minHeight: 108`, where
        // every tile is still equal and only this line goes red:
        // `Expected: a value greater than or equal to <110> / Actual: <108.0>`.
        expect(
          finance.toSet().single,
          greaterThanOrEqualTo(110),
          reason:
              'the snapshot tile minHeight floor (110) must hold — a 44pt eye '
              'has to fit without making its tile taller than its neighbours. '
              'Finance tile heights: $finance',
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

    testWidgets(
      'R3b: the retry marker is a 32×24 target inside its own tile — the '
      'deviation from R3, pinned so it cannot drift either way',
      (tester) async {
        // Deliberately NOT the 44pt R3 holds the eye to, and deliberately
        // asserted as an exact size rather than a floor. Both directions are
        // regressions: smaller is a target nobody can hit, and taller pushes
        // a failed tile past the height of the same tile loaded (28 was
        // already enough, measured) — the height-change false green the
        // sibling group below exists to catch. Whoever wants the full 44
        // has to move the value row's line-height pin first, which is what
        // makes this a design change rather than a one-line edit.
        final dashboard = loadedDashboardFixture();
        final from = dashboard.data!;
        dashboard.data = HomeDashboardData(
          weightGoal: ArmSlot.failedAfter(from.weightGoal),
          bloodPressure: ArmSlot.failedAfter(from.bloodPressure),
          menstrualStatus: ArmSlot.failedAfter(from.menstrualStatus),
          overallBudget: ArmSlot.failedAfter(from.overallBudget),
          netWorth: ArmSlot.failedAfter(from.netWorth),
          splitBalances: ArmSlot.failedAfter(from.splitBalances),
          dailyTarget: ArmSlot.failedAfter(from.dailyTarget),
        );
        // Errors collected and dropped: this width already carries
        // `_knownSectionHeaderOverflow` whatever this state does, and the
        // per-tile group below is what judges the list. What is under test
        // here is the marker's geometry.
        await collectLayoutErrors(
          () => _pumpAt(
            tester,
            _narrow,
            dashboardController: dashboard,
            idToken: () async => 'tok',
            guard: false,
          ),
        );

        for (final tileId in const [
          'home-latest-weight',
          'home-budget',
          'home-net-worth',
        ]) {
          final marker = find.byKey(Key('$tileId-retry'));
          expect(marker, findsOneWidget, reason: tileId);
          expect(tester.getSize(marker), const Size(32, 24), reason: tileId);

          final tile = tester.getRect(find.byKey(Key(tileId)));
          final rect = tester.getRect(marker);
          expect(
            tile.contains(rect.topLeft) && tile.contains(rect.bottomRight),
            isTrue,
            reason: '$tileId marker $rect escapes its tile $tile',
          );
        }
      },
    );

    testWidgets(
      'R3c: the retry marker grows with the text scaler — 32×36 at 2×, still '
      'inside its own tile',
      (tester) async {
        // R3b pins the 1× size, which a marker frozen at a constant height
        // also satisfies: reverting the height to a literal 24 leaves R3b and
        // every other test in this file green. This is the guard that fails
        // for that revert.
        //
        // The scale provably reaches the widget: `_pumpAt` builds through
        // `l10nTestApp`, which wraps only `MaterialApp` and inserts no
        // `MediaQuery` of its own, so nothing shadows the test value — a
        // marker ignoring the scaler measures 24 here and reds immediately.
        //
        // Exact, not `greaterThan(24)`: overshooting is the same regression
        // in the other direction. 24 × 1.5 = 36 has to stay under the value
        // row's own `titleMedium` line box (39 at this scale), and a marker
        // that grew past it would make a failed tile taller than the same
        // tile loaded.
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final dashboard = loadedDashboardFixture();
        final from = dashboard.data!;
        dashboard.data = HomeDashboardData(
          weightGoal: ArmSlot.failedAfter(from.weightGoal),
          bloodPressure: ArmSlot.failedAfter(from.bloodPressure),
          menstrualStatus: ArmSlot.failedAfter(from.menstrualStatus),
          overallBudget: ArmSlot.failedAfter(from.overallBudget),
          netWorth: ArmSlot.failedAfter(from.netWorth),
          splitBalances: ArmSlot.failedAfter(from.splitBalances),
          dailyTarget: ArmSlot.failedAfter(from.dailyTarget),
        );
        // Same reason as R3b: this width carries the known section-header
        // overflow regardless, and the marker's geometry is what is on trial.
        await collectLayoutErrors(
          () => _pumpAt(
            tester,
            _narrow,
            dashboardController: dashboard,
            idToken: () async => 'tok',
            guard: false,
          ),
        );

        for (final tileId in const [
          'home-latest-weight',
          'home-budget',
          'home-net-worth',
        ]) {
          final marker = find.byKey(Key('$tileId-retry'));
          expect(marker, findsOneWidget, reason: tileId);
          expect(tester.getSize(marker), const Size(32, 36), reason: tileId);

          final tile = tester.getRect(find.byKey(Key(tileId)));
          final rect = tester.getRect(marker);
          expect(
            tile.contains(rect.topLeft) && tile.contains(rect.bottomRight),
            isTrue,
            reason: '$tileId marker $rect escapes its tile $tile at 2×',
          );
        }
      },
    );

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
          // Renamed by issue #196: 食物份量工具 → 食物份量, the tile now
          // showing the day's target rather than being a lookup shortcut.
          '食物份量',
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

  // ------------------------------- 食物份量 tile: dropping 菜 (issue #196)
  //
  // The tile prints today's effective target as four count+icon pairs
  // (`10主 7肉 2果 2菜`). When the tile is too narrow for all four to stay
  // legible it prints three (`10主 7肉 2果…`) instead. Both sides are
  // asserted here on purpose: a one-sided guard passes a "always drop 菜" or
  // an "never drop 菜" implementation, which are exactly the two ways this
  // can be broken.
  //
  // **The separator format is load-bearing, and every number below was
  // remeasured after it changed.** Each count now binds to its own group
  // glyph with no space (`10主`), leaving only the group-to-group gap. The
  // figures rounds 1–2 recorded were all measured against the older, looser
  // `10 主 7 肉 …` form and are void; these are read off this build.
  //
  // Natural paragraph widths (widget-test font, `titleMedium`, off
  // `RenderParagraph.size.width`):
  //
  // | string | natural width |
  // | --- | --- |
  // | `10主 7肉 2果 2菜` (full, shipped) | 193.80 |
  // | `10主 7肉 2果…` (short, shipped) | 161.50 |
  // | `10主 7肉 2果` (short without the marker) | 145.35 |
  // | `10 主 7 肉 2 果 2 菜` (the old loose full, for the delta) | 258.40 |
  //
  // So the tightening bought 64.60px on the four-group string, and the
  // elision marker costs 16.15px on the three-group one.
  //
  // The tile keeps the longest candidate that would still be painted at
  // ≥ 0.65× (`_portionValueMinScale` in `home_screen.dart`), i.e. whose
  // natural width is ≤ `valueBox / 0.65`. Value box = tile − **26**, not −24:
  // 12 of padding on each side *plus* 1 of `Border.all(width: 1)` on each,
  // which `Container` folds into layout via `BoxDecoration.padding`
  // (`Border.dimensions`) — measured directly, the value box is 99.00 inside
  // a 125.00 tile. Tile = (screen − 82) / 2 in the two-column layout, so four
  // groups need a value box of 193.80 × 0.65 = 125.97 → tile ≥ 151.97 →
  // screen ≥ 385.94, i.e. the first half-pixel step at or above that is 386
  // — which is exactly where the scan below flips. No fudge factor needed.
  //
  // **Scanned** on this build (0.5dp steps around the edge):
  //
  // | screen | tile | printed | painted scale |
  // | --- | --- | --- | --- |
  // | 331 | 259.0 (one column) | `10主 7肉 2果 2菜` | 1.000 |
  // | 332 | 125.0 | `10主 7肉 2果…` | 0.613 |
  // | 360 | 139.0 | `10主 7肉 2果…` | 0.700 |
  // | 385.5 | 151.75 | `10主 7肉 2果…` | 0.779 |
  // | 386 | 152.0 | `10主 7肉 2果 2菜` | 0.650 |
  // | 390 | 154.0 | `10主 7肉 2果 2菜` | 0.661 |
  // | 402 | 160.0 | `10主 7肉 2果 2菜` | 0.691 |
  // | 412 | 165.0 | `10主 7肉 2果 2菜` | 0.717 |
  // | 430 | 174.0 | `10主 7肉 2果 2菜` | 0.764 |
  // | 440 | 179.0 | `10主 7肉 2果 2菜` | 0.790 |
  // | 470 | 194.0 | `10主 7肉 2果 2菜` | 0.867 |
  // | 600 | 259.0 | `10主 7肉 2果 2菜` | 1.000 |
  //
  // **This is the point of the change.** Before it the flip sat at 470dp, so
  // every mainstream phone (390/402/412/430/440) painted three groups. It now
  // sits at 386dp and all five of those widths keep 菜, at 0.66–0.79×. The
  // elision band is 332–385.5dp only.
  //
  // The 0.650 at 386 is not a coincidence: the rule switches to the longer
  // string at exactly the width where the longer string reaches the floor.
  // Below the flip the tile keeps the shorter candidate and lets the
  // `FittedBox` shrink it (0.613 at 332dp — above
  // `_minValueScaleAtNarrowestTile`, below `_minValueScale`; see that const's
  // doc for which widths are held to which floor).
  //
  // **A visible elision marker is shipped.** Three groups and "today's
  // target genuinely has no 菜" would otherwise be visually identical, so
  // `homeFoodPortionTargetShort` carries a bare trailing `…` (U+2026, no
  // leading space). Remeasured: it takes the short candidate from 145.35 to
  // 161.50 natural, which at the narrowest two-column tile (value box 99.00)
  // paints at **0.6130×** instead of 0.6811× — a real cost, and still far
  // above the 0.45 floor that corner is held to. The full figure also reaches
  // assistive tech through the semantics label (the test below).
  //
  // **Honest caveat about the locale.** In `flutter test` the default font
  // paints every glyph at the same fixed width, so `10主 7肉 2果 2菜` and
  // `10S 7M 2F 2V` measure *identically* here (193.80 both) and these
  // two guards would read the same in English. On a real device the CJK
  // glyphs are wider than the Latin ones, so the real zh-Hant boundary sits
  // wider than the English one. These tests run zh-Hant because that is the
  // locale whose real-device behaviour they are about — they do not prove
  // anything about where the English boundary falls, and 386dp is a zh-Hant
  // statement about this build's test font, not a device measurement.
  group('食物份量 tile drops 菜 when narrow (issue #196)', () {
    /// The narrowest two-column layout that exists (screen 332 → inner 260 →
    /// tile 125 → value box 99): the worst case the tile has to survive.
    const narrowTwoColumn = Size(332, 900);

    /// The narrowest screen at which all four groups are kept, and the last
    /// half-pixel step below it. Scanned, not guessed (see the group doc).
    const fourGroupWidth = Size(386, 900);
    const justBelowFourGroupWidth = Size(385.5, 900);

    /// A mainstream phone, comfortably above the flip. This width is the
    /// entire justification for the separator tightening — before it, 390dp
    /// painted three groups at 0.610×; it now paints four at 0.661×, over
    /// [_minValueScale]. Loosening the ARB separators back moves 390 to the
    /// short candidate and turns this red.
    const mainstreamPhone = Size(390, 900);

    /// The width the 2× text-scale test pumps, and **not** [fourGroupWidth].
    /// At 2× the section header row (`財務` + the `開啟財務` `TextButton`,
    /// `home_screen.dart:930`) overflows its own `Row` by 21px at 386dp — the
    /// same pre-existing shape as `_knownSectionHeaderOverflow`, nothing to
    /// do with the value tile, which is inside a `FittedBox` and cannot
    /// overflow — and `strict: true` rightly refuses it. Measured: at 470dp
    /// that header fits at 2× (zero layout errors), while 1× still keeps all
    /// four groups there (0.867 in the scan table above). So the test keeps
    /// both halves of its contrast; it just makes it at a width where the
    /// unrelated header bug is not in the way.
    const twoTimesScaleWidth = Size(470, 900);

    /// The value string the 食物份量 tile actually printed.
    String portionValue(WidgetTester tester) {
      final finder = find.descendant(
        of: find.byKey(const Key('home-food-dictionary')),
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains('主'),
        ),
      );
      expect(finder, findsOneWidget, reason: '食物份量 tile value');
      return tester.widget<Text>(finder).data!;
    }

    testWidgets(
      'LINCHPIN narrow (332dp, the narrowest two-column tile): 菜 is dropped, '
      'the other three groups stay',
      (tester) async {
        await _pumpAt(
          tester,
          narrowTwoColumn,
          dashboardController: loadedDashboardFixture(),
          locale: _zhHant,
          strict: true,
        );

        final value = portionValue(tester);
        expect(value, contains('主'), reason: value);
        expect(value, contains('肉'), reason: value);
        expect(value, contains('果'), reason: value);
        expect(
          value.contains('菜'),
          isFalse,
          reason: 'the vegetable group must be dropped at 332dp, got "$value"',
        );
        // The exact string, not just its parts. Three things had no named
        // guard before this line, each measured by mutation:
        //
        // - the trailing `…`: it is the only thing that tells "菜 was dropped
        //   for space" apart from "today's target genuinely has no 菜", and
        //   removing it from `homeFoodPortionTargetShort` left every test in
        //   this file green;
        // - the tightened separators (`10主`, not `10 主`) — the round-3 fix
        //   itself, which nothing else asserts as a string;
        // - the digits: the tile must print `effective` (10/7/2/2), and
        //   swapping it for `remaining` (7/5/1/2) previously failed only as
        //   "found 0 widgets containing 10主", a finder message that names
        //   neither the field nor the figure.
        expect(
          value,
          '10主 7肉 2果…',
          reason:
              "the 332dp tile must print today's EFFECTIVE target (10/7/2/2, "
              'not base 8/6/2/2 or remaining 7/5/1/2), with each count bound '
              'to its own group glyph and a trailing elision marker',
        );

        // Dropping 菜 is only half the requirement: what is left still has to
        // be one un-truncated, still-readable line inside the tile.
        // 0.45 and not [_minValueScale], deliberately and only here: 332dp is
        // the narrowest two-column tile that exists and the short candidate
        // paints at 0.613 there (measured). Every wider width this group
        // pumps is held to 0.65 — see the mainstream-phone and wide tests
        // below.
        _expectValueFitsOneLine(
          tester,
          'home-food-dictionary',
          '10主',
          minScale: _minValueScaleAtNarrowestTile,
          reason: '食物份量 value at 332dp',
        );
      },
    );

    testWidgets(
      'LINCHPIN mainstream phone (390dp): all four groups are shown, and '
      'legibly — the reason the separator format was tightened',
      (tester) async {
        await _pumpAt(
          tester,
          mainstreamPhone,
          dashboardController: loadedDashboardFixture(),
          locale: _zhHant,
          strict: true,
        );

        final value = portionValue(tester);
        expect(
          value,
          contains('菜'),
          reason:
              'a 390dp phone must keep the vegetable group after the '
              'separator tightening (it did not before it), got "$value"',
        );
        // Held to the full [_minValueScale], not the narrowest-tile floor:
        // measured 0.661 here.
        _expectValueFitsOneLine(
          tester,
          'home-food-dictionary',
          '10主',
          minScale: _minValueScale,
          reason: '食物份量 value at 390dp',
        );
      },
    );

    testWidgets(
      'LINCHPIN wide (386dp, the first width that keeps all four): all four '
      'groups are shown',
      (tester) async {
        await _pumpAt(
          tester,
          fourGroupWidth,
          dashboardController: loadedDashboardFixture(),
          locale: _zhHant,
          strict: true,
        );

        final value = portionValue(tester);
        expect(
          value,
          contains('菜'),
          reason: 'the vegetable group must survive at 386dp, got "$value"',
        );
        // Exactly at the floor here (0.650), by construction: 386dp is the
        // first width at which the four-group string clears it.
        _expectValueFitsOneLine(
          tester,
          'home-food-dictionary',
          '10主',
          minScale: _minValueScale,
          reason: '食物份量 value at 386dp',
        );
      },
    );

    testWidgets(
      'the boundary is a boundary: half a pixel narrower, 菜 is gone again',
      (tester) async {
        // The pair 385.5/386 is what pins the *threshold* rather than merely
        // "wide screens show four groups": a change to
        // `_portionValueMinScale`, or a loosening of the ARB separators,
        // moves this edge and one of the two sides then goes red.
        await _pumpAt(
          tester,
          justBelowFourGroupWidth,
          dashboardController: loadedDashboardFixture(),
          locale: _zhHant,
          strict: true,
        );

        final value = portionValue(tester);
        expect(
          value.contains('菜'),
          isFalse,
          reason: '菜 must still be dropped at 385.5dp, got "$value"',
        );
      },
    );

    testWidgets(
      'at 2× text scale 菜 is unconditionally elided on phone widths — this '
      'is not a boundary effect the way it is at 1×',
      (tester) async {
        // What this pins is the `MediaQuery.textScalerOf(context)` handed to
        // the measuring `TextPainter`. Measuring at 1× while painting at 2×
        // keeps a rendering that no longer fits, and nothing else in this
        // file would notice: `FittedBox` shrinks the too-long string instead
        // of overflowing. 470dp keeps 菜 at 1× (0.867 in the scan table, well
        // clear of the 386dp flip), so the two facts together say the scale is
        // what changed the answer, not the width. Doubling the scale doubles
        // the four-group string's measured width to 387.60 against the
        // 194.00-wide tile's 168.00 value box — nowhere near fitting.
        // See [twoTimesScaleWidth] for why this is not pumped at
        // [fourGroupWidth].
        //
        // This is NOT the same shape as the 1× 332–385.5dp band: there, a
        // wider phone eventually clears the floor (386dp+). At 2× there is no
        // such width on a phone — the short candidate is what a 200%-scale
        // user always gets, the elision `…` marker being the only *visual*
        // signal (a screen-reader user still gets the full figure via the
        // semantics label; a low-vision user reading visually at 2× does
        // not). Pinning the painted scale here, not just the dropped group,
        // is what stops a further shrink from going unnoticed.
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await _pumpAt(
          tester,
          twoTimesScaleWidth,
          dashboardController: loadedDashboardFixture(),
          locale: _zhHant,
          strict: true,
        );

        final value = portionValue(tester);
        expect(
          value.contains('菜'),
          isFalse,
          reason:
              'at 2× text scale the four-group string no longer clears the '
              'legibility floor at 470dp, got "$value"',
        );

        // Measured on this build: 0.523. Pinned with tolerance so an
        // unrelated font-metric drift does not spuriously red this, but a
        // regression that shrinks the painted figure well below what it is
        // today does.
        final finder = find.descendant(
          of: find.byKey(const Key('home-food-dictionary')),
          matching: find.textContaining('主'),
        );
        expect(
          paintedScaleOf(tester, finder),
          closeTo(0.523, 0.01),
          reason: '食物份量 value at 470dp, 2× text scale',
        );
      },
    );

    testWidgets(
      'CHARACTERIZATION: widening the phone from 331dp to 332dp REMOVES 菜, '
      'and that is the accepted trade, not a bug',
      (tester) async {
        // Not a defect report — a decision, written down so it cannot be
        // "fixed" by accident. 331dp is still one column, so the tile is the
        // full 259px wide and all four groups fit. 332dp is the first
        // two-column width, which halves the tile to 125px, and three groups
        // is all that stays legible there. So the seam inverts: one more
        // logical pixel of screen means one fewer food group.
        //
        // The alternative was letting 主/肉/果 shrink further so 菜 could stay,
        // and the user chose the opposite after seeing both: the first three
        // groups are guaranteed on every phone, and the full figure is still
        // available to assistive tech (see the semantics test below). Both
        // widths are pumped in one test so it can only pass by actually
        // crossing the seam.
        //
        // **Re-checked for vacuity after the separator tightening, because
        // this test would have become a tautology if the tightening had made
        // 332dp wide enough for four groups — both sides would then contain
        // 菜 and neither assertion could fail.** It did not: measured, the
        // flip moved from 470dp to 386dp, and 332dp's 125px tile (value box
        // 99.00, budget 152.31) is still short of the four-group string's
        // 193.80. The seam is real and this test still has two sides. If a
        // future change pushes the flip to 332 or below, delete this test
        // rather than leaving an assertion that cannot fail.
        await _pumpAt(
          tester,
          const Size(331, 900),
          dashboardController: loadedDashboardFixture(),
          locale: _zhHant,
          strict: true,
        );
        final atSingleColumn = portionValue(tester);
        expect(
          atSingleColumn,
          contains('菜'),
          reason: '331dp is single-column and wide enough for all four groups, '
              'got "$atSingleColumn"',
        );

        await _pumpAt(
          tester,
          narrowTwoColumn,
          dashboardController: loadedDashboardFixture(),
          locale: _zhHant,
          strict: true,
        );
        final atTwoColumns = portionValue(tester);
        expect(
          atTwoColumns.contains('菜'),
          isFalse,
          reason: '332dp is the first two-column width and 菜 is elided there '
              '— the accepted inversion. Got "$atTwoColumns"',
        );
      },
    );

    testWidgets(
      'the elided group is still in the semantics label at 332dp',
      (tester) async {
        // Why this exists: the visible `…` marker only says "something was
        // dropped for space" — it does not say WHICH group, so a sighted
        // reader still cannot tell "菜 was elided" from "today genuinely has
        // no 菜 target" by looking at the painted text alone. Assistive tech
        // is told the whole figure regardless of which candidate was
        // painted, which is what names the dropped group.
        //
        // **Honest limit.** This reads the `Semantics` widget in the widget
        // tree. It proves the tile *configures* that label; it does not prove
        // a screen reader on a real device announces it, and it cannot — the
        // platform semantics tree is not what this assertion looks at.
        await _pumpAt(
          tester,
          narrowTwoColumn,
          dashboardController: loadedDashboardFixture(),
          locale: _zhHant,
          strict: true,
        );

        final tile = find.byKey(const Key('home-food-dictionary'));

        // The painted text really is the short rendering...
        expect(
          find.descendant(of: tile, matching: find.textContaining('菜')),
          findsNothing,
          reason: '菜 must not be painted at 332dp',
        );
        // ...and the announced label really is the long one, spelled out
        // with the group NAME ("蔬菜") rather than the one-glyph icon
        // ("菜") the tile paints — a bare-glyph label would pass a `contains
        // '菜'` check for the wrong reason, since the icon glyph is a
        // substring of the category name.
        final labelled = find.descendant(
          of: tile,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label ?? '').contains('蔬菜') &&
                (w.properties.label ?? '').contains('主食'),
          ),
        );
        expect(
          labelled,
          findsOneWidget,
          reason:
              'the 食物份量 tile must carry the full four-group figure, named '
              'not iconified, as its value semantics label even when it '
              'paints three',
        );

        // ...and `ExcludeSemantics` is actually doing its job: the painted
        // (short, iconified) rendering must not ALSO surface as semantics —
        // otherwise a screen reader announces the figure twice, once fully
        // and once truncated.
        //
        // **This assertion was rewritten because the previous one could not
        // fail.** It looked for a `Semantics` *widget* whose label carried the
        // painted string — but `Text` inserts no `Semantics` widget at all;
        // its semantics come from `RenderParagraph`. So the predicate matched
        // nothing whether or not `ExcludeSemantics` was there. Measured: with
        // `ExcludeSemantics` deleted from `_SnapshotTile`'s
        // `valueSemanticLabel` branch, the whole of
        // `test/contexts/user/presentation/` stayed green. Reading the
        // semantics data instead is what turns that mutation red.
        //
        // **Honest limit, same as above.** `getSemantics` reads the
        // widget-tree semantics cache; it does not prove the platform
        // semantics tree received any of this.
        // Collected and the handle disposed *before* asserting, not via
        // `addTearDown`: tear-downs run after the framework's
        // "a SemanticsHandle was active at the end of the test" verification,
        // so a deferred dispose fails the test on its own.
        final semantics = tester.ensureSemantics();
        final labels = _semanticsLabelsUnder(tester, tile);
        semantics.dispose();
        expect(
          labels.where((l) => l.contains('蔬菜')),
          isNotEmpty,
          reason:
              'the full four-group figure must reach the semantics tree, not '
              'only the widget tree. Labels: $labels',
        );
        expect(
          labels.where((l) => l.contains('10主')),
          isEmpty,
          reason:
              'the painted short rendering "10主 7肉 2果…" must be excluded '
              'from semantics, not just overlaid by the full-figure label. '
              'Labels: $labels',
        );
      },
    );

    testWidgets(
      'CHARACTERIZATION: a fractional (half-portion) target paints well '
      'under the legibility floor at 390dp — known, not fixed here (see '
      '_portionTargetValue\'s doc)',
      (tester) async {
        // Every boundary number in this group's doc and in
        // `_portionValueMinScale` assumes integer targets. Half portions are
        // a shipped, ordinary user action (`portion_stepper.dart`'s
        // `step = 0.5`), and `_compactNumber` prints them as `10.5`, not
        // `10` or `½` — wider than every measurement above accounts for.
        // This does not assert a floor (there is none defined for this
        // case); it pins the current, degraded number so a further
        // regression is visible instead of silent.
        final dashboard = loadedDashboardFixture();
        final data = dashboard.data!;
        dashboard.data = data.copyWith(
          dailyTarget: const ArmSlot.loaded(
            DailyTargetWithRemaining(
              day: '2026-01-01',
              base: Portions(staple: 8.5, meat: 6.5, fruit: 2.5, veg: 2.5),
              bonus: Portions(staple: 2, meat: 1, fruit: 0, veg: 0),
              effective: Portions(staple: 10.5, meat: 7.5, fruit: 2.5, veg: 2.5),
              logged: Portions(staple: 3, meat: 2, fruit: 1, veg: 0),
              remaining: Portions(staple: 7.5, meat: 5.5, fruit: 1.5, veg: 2.5),
            ),
          ),
        );

        // 390dp: `mainstreamPhone` above, held to the full `_minValueScale`
        // (0.65) for the all-integer fixture.
        await _pumpAt(
          tester,
          mainstreamPhone,
          dashboardController: dashboard,
          locale: _zhHant,
          strict: true,
        );

        final value = portionValue(tester);
        expect(
          value,
          contains('.5'),
          reason: 'sanity: this fixture must actually exercise a fractional '
              'group, got "$value"',
        );

        final finder = find.descendant(
          of: find.byKey(const Key('home-food-dictionary')),
          matching: find.textContaining('主'),
        );
        final scale = paintedScaleOf(tester, finder);
        // Measured on this build: 0.495. Below `_minValueScale` (0.65) —
        // which the all-integer fixture clears at this exact width (see the
        // "mainstream phone" test above, 0.661) — but above
        // `_minValueScaleAtNarrowestTile` (0.45). Fractional targets are
        // documented, not held to either floor; this pins the current number
        // so a further shrink is visible instead of silent.
        expect(
          scale,
          lessThan(_minValueScale),
          reason:
              'fractional targets are not held to _minValueScale: this '
              'paints at ${scale.toStringAsFixed(3)}, below the 0.65 floor '
              'an integer target clears at this same 390dp width. If this '
              'starts failing because the scale moved back to or above '
              '0.65, that is improvement, not a regression: update the doc '
              'and this test rather than loosening the bound further.',
        );
      },
    );
  });

  // ------------------------------- the 食物份量 label itself (issue #196)
  //
  // Measured cause: at 332dp the label row is `[44pt icon][Expanded label]`,
  // which leaves the label ~51px. `Food portions` broke to **three** lines
  // there. Shortening the English copy to `Portions` is the whole fix — the
  // 44pt icon is the a11y floor for a tap target and is not negotiable, and
  // zh-Hant's 食物份量 (four glyphs) was never the problem.
  //
  // **Honest caveat, and it is a big one.** `flutter test`'s default font
  // paints every character at the same fixed width, so English and Chinese
  // measure identically here and "how wide is `Portions` really" is a
  // question this test cannot answer. What it *does* pin is the character
  // count against the label column at three real phone widths: put
  // `Food portions` back and it goes red. The real-device boundary may sit on
  // either side of this one.
  group('食物份量 label fits its column in English (issue #196)', () {
    for (final width in [332.0, 360.0, 390.0]) {
      testWidgets('at ${width}dp the label stays within two lines', (
        tester,
      ) async {
        await _pumpAt(
          tester,
          Size(width, 900),
          dashboardController: loadedDashboardFixture(),
          locale: const Locale('en'),
          strict: true,
        );

        // Looked up, not typed as a literal: this test is about how many
        // lines the label needs, so it must keep finding the label after the
        // copy changes — otherwise a longer string would fail at the finder
        // and never reach the assertion below (measured: it does exactly
        // that when the lookup is replaced with `find.text('Portions')`).
        final label = find.descendant(
          of: find.byKey(const Key('home-food-dictionary')),
          matching: find.text(
            lookupAppLocalizations(const Locale('en')).homeFoodPortion,
          ),
        );
        expect(label, findsOneWidget);
        expect(
          paintedTextLineCount(tester, label),
          lessThanOrEqualTo(2),
          reason:
              'the food-portion label wrapped past two lines at ${width}dp, '
              'which is what made the tile taller than its row neighbours',
        );
      });
    }
  });

  // Its own group because it deliberately runs at two widths — the
  // single-column 320dp case and the two-column 360dp one.
  group('HomeScreen snapshot tile title alignment', () {
    // The invariant is the title's offset INSIDE its tile, never an absolute
    // y: at 320dp the sections are single-column, so each tile is its own
    // `Wrap` row and the tile tops legitimately differ. 5 of the 8 tiles
    // carry an eye in the title row, which makes that row 48dp tall (the
    // 44pt target plus Material's tap-target padding) instead of the
    // 16–32dp the `bodySmall` title needs on its own. Measured with the
    // alignment removed, centring therefore put the titles at three
    // different offsets — 29 (icon, one-line title), 21 (icon, wrapped
    // two-line title) and 13 (no icon) — i.e. 8–16dp of drift depending on
    // whether the title wraps.
    Future<void> expectTitlesAlignedWithinTiles(
      WidgetTester tester,
      Size size, {
      required bool twoColumns,
      required bool strict,
    }) async {
      await _pumpAt(
        tester,
        size,
        dashboardController: _evenValuesFixture(),
        // Passed separately from `twoColumns` on purpose: 320dp has a
        // known, pre-existing sub-pixel overflow allowance, so tying
        // strictness to the column count would make a width change fail on
        // the overflow check before it ever reached the column pin below.
        strict: strict,
      );

      // Pin which layout was actually exercised — otherwise both cases could
      // silently be the same single-column one.
      expect(_isTwoColumns(tester, _healthTiles), twoColumns);
      expect(_isTwoColumns(tester, _financeTiles), twoColumns);

      final loc = lookupAppLocalizations(const Locale('en'));
      final titles = {
        'home-latest-weight': loc.homeLatestWeight,
        'home-food-dictionary': loc.homeFoodPortion,
        'home-latest-blood-pressure': loc.homeLatestBloodPressure,
        'home-menstrual-prediction': loc.homeMenstrualPrediction,
        'home-budget': loc.homeBudget,
        'home-net-worth': loc.homeNetWorth,
        'home-total-liabilities': loc.homeTotalLiabilities,
        'home-split-overview': loc.homeSplitOverview,
      };

      final offsets = <String, double>{};
      for (final entry in titles.entries) {
        final tile = find.byKey(Key(entry.key));
        final label = find.descendant(of: tile, matching: find.text(entry.value));
        expect(
          label,
          findsOneWidget,
          reason: '${entry.key} must print its title "${entry.value}"',
        );
        offsets[entry.key] =
            tester.getRect(label).top - tester.getRect(tile).top;
      }

      expect(
        offsets.values.toSet(),
        hasLength(1),
        reason:
            'every snapshot tile title must start at the same offset inside '
            'its own tile, whether or not the tile has an icon. Offsets at '
            '${size.width}dp: $offsets',
      );
    }

    testWidgets(
      'R2b: tile titles start at the same offset with and without an icon '
      '(single column, 320dp)',
      (tester) async {
        await expectTitlesAlignedWithinTiles(
          tester,
          _narrow,
          twoColumns: false,
          strict: false,
        );
      },
    );

    testWidgets(
      'R2b: tile titles start at the same offset with and without an icon '
      '(two columns, 360dp)',
      (tester) async {
        await expectTitlesAlignedWithinTiles(
          tester,
          const Size(360, 800),
          twoColumns: true,
          strict: true,
        );
      },
    );
  });

  // ------------------------------------------- per-tile failure / loading states
  //
  // What these can and cannot say: widget tests are font-blind (see
  // CLAUDE.md — `flutter_test` paints one fontSize-sized square per glyph),
  // so green here means the LAYOUT LOGIC holds, never that the real Noto Sans
  // string fits. The failure copy is **not** short — `Couldn't load` is 13
  // characters against `62.5 kg`'s 7, plus an 18px icon and a 6px gap — and
  // measured with the real font it does get shrunk by its `FittedBox`: 0.900
  // at 360dp/1×, 0.502 at 360dp/2×, against 1.000 in zh-Hant everywhere. The
  // real-font guard for it therefore lives where it can measure that
  // (`real_font_metrics_test.dart`, "a failed tile's copy is never painted
  // smaller than the figure it replaces"), and this file's own numbers below
  // remain placeholder-font numbers.
  //
  // Each width/scale is measured against the SAME screen in its loaded state
  // rather than against zero: at 320dp and at 2× text scale this page already
  // produces layout errors that have nothing to do with this change (see
  // `_knownSectionHeaderOverflow`), and a bare "no errors" assertion would
  // either fail for a pre-existing reason or be relaxed into one that cannot
  // fail.
  group('a tile whose own arm is loading or failed', () {
    HomeDashboardData allFailed(HomeDashboardData from) => HomeDashboardData(
      weightGoal: ArmSlot.failedAfter(from.weightGoal),
      bloodPressure: ArmSlot.failedAfter(from.bloodPressure),
      menstrualStatus: ArmSlot.failedAfter(from.menstrualStatus),
      overallBudget: ArmSlot.failedAfter(from.overallBudget),
      netWorth: ArmSlot.failedAfter(from.netWorth),
      splitBalances: ArmSlot.failedAfter(from.splitBalances),
      dailyTarget: ArmSlot.failedAfter(from.dailyTarget),
    );

    HomeDashboardController fixtureWith(HomeDashboardData Function(HomeDashboardData) map) {
      final dashboard = loadedDashboardFixture();
      dashboard.data = map(dashboard.data!);
      return dashboard;
    }

    /// The four renderings a tile can be in, all from the same figures.
    Map<String, HomeDashboardController> statesOf() => {
      'loaded': loadedDashboardFixture(),
      // Cold: nothing fetched yet, so no figure to keep.
      'loading': fixtureWith((_) => const HomeDashboardData.allLoading()),
      'cold failure': fixtureWith(
        (_) => allFailed(const HomeDashboardData.allLoading()),
      ),
      // Stale: this session already had the figures, so they stay on screen
      // with a marker beside them.
      'stale failure': fixtureWith(allFailed),
    };

    Future<List<String>> layoutErrorsAt(
      WidgetTester tester,
      Size size,
      HomeDashboardController dashboard,
    ) async {
      // A `RenderFlex` reports each overflow ONCE per render object, so a
      // second pump in the same test reuses the same objects and reports
      // nothing — every state after the first would look clean whatever it
      // did. Dropping the tree first forces fresh render objects.
      await tester.pumpWidget(const SizedBox.shrink());
      final errors = await collectLayoutErrors(
        () => _pumpAt(
          tester,
          size,
          dashboardController: dashboard,
          idToken: () async => 'tok',
          guard: false,
        ),
      );
      return errors
          .map((e) => e.exception.toString().split('\n').first)
          .toList()
        ..sort();
    }

    for (final width in const [320.0, 375.0, 600.0]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets(
          'at ${width.toInt()}dp / $scale× text scale, neither state adds a '
          'layout error the loaded state does not already have',
          (tester) async {
            if (scale != 1.0) {
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
            }
            final size = Size(width, 900);
            final states = statesOf();
            final baseline = await layoutErrorsAt(
              tester,
              size,
              states['loaded']!,
            );
            for (final entry in states.entries) {
              if (entry.key == 'loaded') continue;
              expect(
                await layoutErrorsAt(tester, size, entry.value),
                baseline,
                reason: '${entry.key} at ${width}dp / ${scale}x',
              );
            }
          },
        );

        testWidgets(
          'at ${width.toInt()}dp / $scale× text scale, a tile is exactly as '
          'tall loading or failed as it is loaded',
          (tester) async {
            // The documented false green this exists for: a page that grows
            // between states, so a tap measured in one state lands somewhere
            // else in the other. The value area is pinned to one line of its
            // own text style precisely so this holds at every scale.
            if (scale != 1.0) {
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
            }
            final size = Size(width, 900);
            final states = statesOf();
            // Layout errors are collected and DROPPED here on purpose: this
            // page already overflows at 320dp and at 2x whatever this change
            // does (see `_knownSectionHeaderOverflow`), and the sibling test
            // above is the one that judges them. What is under test here is
            // only the height.
            Future<void> pumpQuiet(HomeDashboardController dashboard) async {
              await tester.pumpWidget(const SizedBox.shrink());
              await collectLayoutErrors(
                () => _pumpAt(
                  tester,
                  size,
                  dashboardController: dashboard,
                  idToken: () async => 'tok',
                  guard: false,
                ),
              );
            }

            await pumpQuiet(states['loaded']!);
            final loadedHealth = _heightsOf(tester, _healthTiles);
            final loadedFinance = _heightsOf(tester, _financeTiles);

            for (final entry in states.entries) {
              if (entry.key == 'loaded') continue;
              await pumpQuiet(entry.value);
              expect(
                _heightsOf(tester, _healthTiles),
                loadedHealth,
                reason: 'health tiles, ${entry.key}',
              );
              expect(
                _heightsOf(tester, _financeTiles),
                loadedFinance,
                reason: 'finance tiles, ${entry.key}',
              );
            }
          },
        );
      }
    }
  });
}
