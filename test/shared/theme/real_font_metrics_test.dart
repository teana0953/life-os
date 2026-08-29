import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/application/sign_up.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/auth/presentation/login_screen.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/next_period_status.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_calendar.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:life_os/shared/widgets/cycle_badge.dart';

import '../../contexts/user/presentation/home_screen_test.dart'
    show loadedDashboardFixture, testDailyTarget, testPrivacyMaskController;
import '../../support/l10n_test_app.dart';
import '../../support/layout_guard.dart';

/// Layout guards rendered with the **real bundled .ttf**, not the
/// `flutter_test` placeholder font.
///
/// **Why this file has to exist.** Every other widget test in this repo is
/// structurally blind to which font family the theme names. `flutter_test`
/// draws one `fontSize`-sized square per glyph whatever the family is, so
/// `TextPainter` returns byte-identical widths for Quicksand, Noto Sans,
/// Roboto and `null` alike. That was measured, not assumed, while swapping
/// the app font (issue #194): setting `_fontFamily` to `NotoSans` and running
/// the four layout-guard files (`home_screen_responsive_test.dart`,
/// `login_screen_responsive_test.dart`, `friends_invite_layout_test.dart`,
/// `split_layout_test.dart`) produced 166 passing tests and **zero**
/// behavioural difference. A green `flutter test` therefore says "the logic
/// still works", never "the layout still fits".
///
/// This file closes that hole for the highest-risk screens by registering the
/// actual font file with a [FontLoader] before pumping, so the paragraphs are
/// laid out at the real advance widths and the real line height.
///
/// **What it cannot prove** — stated here rather than papered over with
/// assertions that look stronger than they are:
///
/// 1. **Nothing about bold.** The bundled file is a variable font, and
///    `FontLoader` registers it as a single face: the renderer only ever
///    produces its *default* instance (wght 400), so `w400` and `w700` lay
///    out to identical widths here. The `weight: 700` registration in
///    `pubspec.yaml` is real on device (the file's `fvar` carries a
///    100–900 `wght` axis) but is out of this file's reach — it belongs to
///    the manual on-device pass.
/// 2. **Nothing about CJK.** The bundled Noto Sans is the Latin/Greek/
///    Cyrillic family and the shipped copy is subset further still, to
///    Latin-1 + Latin Extended-A + punctuation + super/subscripts +
///    currency (the upstream font has no arrow/math/misc-symbol glyphs at
///    all, so those were never an option). It has no Han glyphs and never
///    had any — 剩餘, 淨值 and every other
///    Chinese string fall back to the host's font, exactly as they did under
///    Quicksand. The zh-Hant cases below therefore measure *mixed* runs whose
///    CJK half is the test font; the falsifiable part is the Latin/digit
///    half.
/// 3. **Nothing about the web splash.** `web/index.html`'s pre-Flutter
///    `font-family` is CSS, invisible to any Dart test.
///
/// Everything asserted below is verified by mutation — see the tables on the
/// individual helpers.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = File(_fontAssetPath).readAsBytesSync();
    final loader = FontLoader(_appFontFamily)
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  group('the bundled font file', () {
    test('is the Noto Sans subset the theme names', () {
      expect(
        _appFontFamily,
        'NotoSans',
        reason:
            'the theme font family and the file loaded by this test must be '
            'the same family, or every guard below silently measures the '
            'placeholder font again',
      );
      expect(
        File(_fontAssetPath).existsSync(),
        isTrue,
        reason: '$_fontAssetPath is missing',
      );
    });

    test('is registered in pubspec.yaml, twice, so bold has a face', () {
      // The same-file-twice shape (once plain, once `weight: 700`) is what
      // makes a variable font render heavier on device. Nothing in a widget
      // test can observe it (see caveat 1 in the library doc), so the
      // registration itself is what gets pinned.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: $_appFontFamily'));
      expect(
        _fontAssetPath.allMatches(pubspec).length,
        2,
        reason: 'expected $_fontAssetPath registered twice (plain + weight 700)',
      );
      expect(pubspec, contains('weight: 700'));
      expect(
        pubspec.contains('Quicksand'),
        isFalse,
        reason: 'the old family must be gone, not merely unused',
      );
    });

    test('lays out at Noto Sans metrics, not the old font\'s', () {
      // The direct measurement, and the only assertion in this file that
      // pins the *file* rather than a screen built on it: re-subsetting from
      // a different source, or dropping the wrong .ttf in under the same
      // name, changes these numbers. Both were measured on the shipped
      // subset; the Quicksand figures next to them are what they replaced.
      TextPainter painted(String text) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: _appFontFamily, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Line height: 1.362 em against Quicksand's 1.250 (+9%).
      expect(painted('Ag').height, 22.0);
      // A near-*best*-case width string, not the worst case: +8.6% over
      // Quicksand's 66.9, driven mostly by the comma (0.167 → 0.268 em,
      // +60%). Noto's digits are tabular (every digit is 0.572 em); only `0`
      // happens to be narrower than Quicksand's proportional 0.588 em — `1`
      // widens by +58% (0.363 → 0.572 em) under the same swap, so a
      // digit-heavy fixture with fewer `0`s grows far more than this string
      // does.
      expect(painted('9,999,999').width, closeTo(72.64, 0.01));
    });
  });

  group('home dashboard, real font metrics', () {
    testWidgets('360dp two-column: the widest figure still reads', (
      tester,
    ) async {
      // 360dp, not 320dp, and the 11-digit fixture, not a human-scale one —
      // both forced by what the real font measures. Real Noto digits are
      // *narrower* than the placeholder font's fontSize squares (a `0` is
      // 0.572 em against the test font's 1.0), so at 320dp — where the
      // dashboard is one column and a tile is 248dp wide — every realistic
      // figure fits at scale 1.0 and no assertion here could fail whatever
      // the tile did. 360dp is where two columns kick in (tile 139dp), and
      // `99,999,999,999` behind 本月預算's `剩餘 …` wrapper is the string
      // that actually has to be shrunk to fit it. Measured: without the
      // `FittedBox` this exact case wraps (see the mutation table on
      // [_expectValueLegible]).
      await _pumpHome(
        tester,
        const Size(360, 640),
        locale: _zhHant,
        dashboard: _longestValuesFixture(),
      );

      _expectValueLegible(
        tester,
        'home-budget',
        '99,999,999,999',
        reason: '本月預算 at 360dp',
      );
    });

    testWidgets(
      'a failed tile\'s copy is never painted smaller than the figure it '
      'replaces (360dp, textScale 2.0, English)',
      (tester) async {
        // The one width/scale where this is close, measured with the real
        // font on this build. `Couldn't load` inside the tile's `FittedBox`
        // (English; 載入失敗 is four characters and never shrinks at all):
        //
        // |        | 320dp | 360dp | 375dp | 600dp |
        // | ---    | ---   | ---   | ---   | ---   |
        // | 1×     | 1.000 | 0.900 | 0.960 | 1.000 |
        // | 2×     | 0.987 | 0.502 | 0.536 | 1.000 |
        //
        // So the copy is **not** "shorter than every figure it replaces" — it
        // is 13 characters against `62.5 kg`'s 7, plus an 18px icon and a 6px
        // gap — and at two columns with large text it does get shrunk. What
        // holds, and what is asserted here, is comparative: swapping a figure
        // for the failure notice never makes that tile's text smaller than it
        // already was. An absolute 0.65 floor (the bar `_expectValueLegible`
        // holds figures to at 1×) is deliberately NOT asserted: this tile's
        // own loaded figure is painted at 0.399 here, so a 0.65 assertion
        // would be a guard on a bar the shipped screen does not clear and
        // would fail for a reason that has nothing to do with this state.
        const size = Size(360, 640);
        await _pumpHome(
          tester,
          size,
          locale: const Locale('en'),
          textScale: 2.0,
          dashboard: loadedDashboardFixture(),
        );
        // `_pumpHome` builds its own `MediaQuery`, so setting
        // `textScaleFactorTestValue` instead of passing `textScale` here
        // renders at 1.0 whatever the platform value says, and every number
        // above stops applying. Measured, not assumed: the first draft of
        // this test did exactly that, and the copy-lengthening mutation below
        // stayed green through it.
        //
        // | mutation | result |
        // | --- | --- |
        // | `homeTileLoadFailed` → `Couldn't load this right now` | RED — painted at 0.255× against the 0.399× figure |
        // | `_statusLine`'s `FittedBox` removed | RED — the copy spills past its tile |
        // | `_statusLine` icon 18 → 60 | GREEN, and correctly so: the icon sits INSIDE the `FittedBox`, so growing it shrinks the whole row proportionally and the copy stays above the figure it replaced. The width budget is what this measures, not the icon. |
        _expectTextScaleReached(tester, find.byType(HomeScreen), 2.0);
        final figure = find.descendant(
          of: find.byKey(const Key('home-budget')),
          matching: find.textContaining('123,400'),
        );
        expect(figure, findsOneWidget);
        final figureScale = paintedScaleOf(tester, figure);

        await _pumpHome(
          tester,
          size,
          locale: const Locale('en'),
          textScale: 2.0,
          dashboard: loadedDashboardFixture()..data = _allFailedCold(),
        );
        final copy = find.descendant(
          of: find.byKey(const Key('home-budget')),
          matching: find.text(
            lookupAppLocalizations(const Locale('en')).homeTileLoadFailed,
          ),
        );
        expect(
          copy,
          findsOneWidget,
          reason: 'the failed tile printed something else entirely',
        );
        expectPaintedInFull(tester, copy);
        final copyScale = paintedScaleOf(tester, copy);
        expect(
          copyScale,
          greaterThanOrEqualTo(figureScale),
          reason:
              'the failure copy is painted at ${copyScale.toStringAsFixed(3)}×, '
              'smaller than the ${figureScale.toStringAsFixed(3)}× figure it '
              'replaced — a message the user cannot read is worse than the '
              'number it stands in for',
        );
        final tile = tester.getRect(find.byKey(const Key('home-budget')));
        expect(
          paintedTextRight(tester, copy),
          lessThanOrEqualTo(tile.right - _tilePadding / 2),
          reason: 'the failure copy spills past its tile',
        );
      },
    );

    testWidgets('320dp at textScale 2.0: no layout error', (tester) async {
      // The narrowest phone at the largest accessibility text size — every
      // row on the dashboard laid out with real advance widths.
      //
      // **What this catches, measured.** Re-running it at a 150dp surface
      // reports `A RenderFlex overflowed by 109 pixels on the right` (×2) and
      // `… by 12 pixels` (×2), so the instrument does fire on a horizontal
      // overflow — the axis this font change moves (+8.6% on `9,999,999`,
      // almost all of it the comma at 0.167 → 0.268 em).
      //
      // **What it cannot catch, also measured.** Vertical growth. A style
      // with an explicit `height:` (headlineMedium, titleLarge, bodyLarge,
      // bodyMedium — most of the app's text) renders at an *identical* line
      // box under Noto and Quicksand, because the multiplier pins it
      // font-independently. Only the styles without one (titleMedium,
      // labelLarge, labelMedium/Small, bodySmall — tile values, button
      // captions, small captions) grow: 18–20px line boxes become 19–22px,
      // ≤2px each. `painted('Ag').height == 22.0` above measures exactly
      // that unpinned case (fontSize 16, no `height:`, i.e. labelLarge's
      // shape) — but the home body scrolls, so even that growth never raises
      // an error here: re-run at a 320×120 surface and the error list is
      // still empty. Nothing here guards the vertical axis on this screen,
      // and an assertion pretending otherwise would be a
      // guard that cannot fail. The line height itself is pinned directly by
      // the metrics test above instead.
      final errors = await collectLayoutErrors(
        () => _pumpHome(tester, const Size(320, 640), locale: _zhHant, textScale: 2.0),
      );
      _expectTextScaleReached(tester, find.byType(HomeScreen), 2.0);
      // Anti-vacuity: an empty error list proves nothing if the dashboard
      // never rendered.
      expect(find.byKey(const Key('finance-dashboard-section')), findsOneWidget);
      expect(
        errors.map((e) => e.exception.toString().split('\n').first).toList(),
        isEmpty,
      );
    });
  });

  // The menstrual calendar's period-day marker stacks two lines of digits
  // inside a fixed 32x32 circle. Every ordinary widget test of it is blind to
  // the font: `flutter_test` paints one fontSize-square per glyph, so a
  // two-line column measures 12+11=23dp there whatever the real ascender and
  // descender do. Only the real .ttf can say whether it actually fits.
  group('menstrual day marker, real font metrics', () {
    // 1.3 is the marker's own `MediaQuery.withClampedTextScaling` cap, so
    // pumping at 2.0 exercises the clamped ceiling; 1.0 is the floor.
    for (final entry in {1.0: 1.0, 2.0: 1.3}.entries) {
      testWidgets(
        'two-line marker fits the 32dp circle at textScale ${entry.key} '
        '(clamped to ${entry.value})',
        (tester) async {
          final errors = await collectLayoutErrors(
            () => _pumpMenstrualCalendar(tester, textScale: entry.key),
          );
          expect(
            errors.map((e) => e.exception.toString().split('\n').first).toList(),
            isEmpty,
          );

          final marker = find.byKey(const Key('menstrual-day-marker-2026-07-12'));
          final content = tester.getSize(
            find.descendant(of: marker, matching: find.byType(Column)),
          );
          expect(
            content.height,
            lessThanOrEqualTo(_markerDiameter),
            reason:
                'the stacked date + cycle-day lines must stay inside the '
                '32dp circle at an effective scale of ${entry.value}',
          );
          // Not the full 32: the circle's usable chord narrows away from its
          // vertical middle, and the two lines straddle it.
          expect(
            content.width,
            lessThanOrEqualTo(_markerChord),
            reason: 'the widest of the two lines must stay inside the chord',
          );
        },
      );
    }
  });

  // Same instrument as the menstrual day marker above, for the home tile's
  // and next-period card's shared `CycleBadge`: "3d late" (overdue's English
  // label) is the widest of the four badged labels ("Xd" for
  // ongoing/upcoming, "Today" for today) — the placeholder font would draw
  // all three as fontSize squares and could not tell "3d late" apart from a
  // one-character label. **Not** asserted here for zh-Hant ("逾3天"): the
  // bundled Noto Sans subset carries no CJK glyphs at all (see
  // `menstrual-status-badges/design.md`'s risks), so a CJK assertion in this
  // file would measure the platform fallback font, not the shipped one —
  // fit at that width was instead confirmed manually in a browser (noted on
  // the PR), which this test cannot substitute for or duplicate.
  group('CycleBadge, real font metrics', () {
    for (final entry in {1.0: 1.0, 2.0: 1.3}.entries) {
      testWidgets(
        '"3d late" fits the 32dp circle at textScale ${entry.key} '
        '(clamped to ${entry.value})',
        (tester) async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(entry.key)),
              child: l10nTestApp(
                theme: lightTheme,
                home: const Scaffold(
                  body: Center(
                    child: CycleBadge(
                      key: Key('badge-under-test'),
                      filled: false,
                      color: Colors.orange,
                      textColor: Colors.orange,
                      label: '3d late',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final badge = find.byKey(const Key('badge-under-test'));
          expect(
            tester.getSize(badge),
            const Size(_markerDiameter, _markerDiameter),
            reason:
                'the badge circle itself must not grow past its fixed 32dp '
                'size — the FittedBox inside it is what absorbs the label, '
                'not the circle',
          );

          final content = tester.getSize(
            find.descendant(of: badge, matching: find.byType(FittedBox)),
          );
          expect(
            content.width,
            lessThanOrEqualTo(_markerDiameter),
            reason: '"3d late" must not force the badge wider than 32dp',
          );
          expect(
            content.height,
            lessThanOrEqualTo(_markerDiameter),
            reason: '"3d late" must not force the badge taller than 32dp',
          );
        },
      );
    }
  });

  // Task 6.2 of `menstrual-status-badges`: settle the home tile's
  // `minHeight` against the real font rather than shipping design.md's
  // ~132dp estimate unverified. `overdue` is the tallest of the six
  // menstrual states — it is the only one with both a badge (line 1) and a
  // date line (line 2) stacked under the label row. Measured: at 320dp with
  // the real font this pump's error list is empty (the known 0.257px
  // section-header overflow that `home_screen_responsive_test.dart` allows
  // for is a `flutter_test` placeholder-font artifact and does not reproduce
  // here), so a bare "no errors" assertion is not vacuous.
  group('home dashboard menstrual tile, real font metrics', () {
    testWidgets(
      'the tallest menstrual state (overdue) fits the shipped minHeight '
      'at 320dp zh-Hant',
      (tester) async {
        final overdue = HomeDashboardData.allLoaded(
          weightGoal: WeightGoal(currentWeightKg: 62.5),
          bloodPressure: null,
          menstrualStatus: NextPeriodStatus(
            state: NextPeriodState.overdue,
            days: 3,
            predictedNextStart: DateTime(2026, 7, 25),
          ),
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
        final dashboard = loadedDashboardFixture()..data = overdue;

        final errors = await collectLayoutErrors(
          () => _pumpHome(
            tester,
            const Size(320, 900),
            locale: _zhHant,
            dashboard: dashboard,
          ),
        );
        expect(
          errors.map((e) => e.exception.toString().split('\n').first).toList(),
          isEmpty,
          reason:
              'the menstrual tile in its tallest (overdue) state must not '
              'overflow at 320dp with the real font',
        );

        final tile = tester.getSize(
          find.byKey(const Key('home-menstrual-prediction')),
        );
        expect(
          tile.height,
          lessThanOrEqualTo(140.0),
          reason:
              'the tile must not have silently grown past its intended '
              '~132dp — a large real-font overshoot here would still pass '
              'the overflow check above (the tile just gets taller) without '
              'this explicit ceiling',
        );
      },
    );
  });

  // Same instrument, same limits as the dashboard case above: verified to
  // fire horizontally (at a 150dp surface: `A RenderFlex overflowed by 18
  // pixels on the right`) and verified *not* to fire vertically (at a 320×200
  // surface the list is still empty — the sign-in body scrolls too).
  group('sign-in card, real font metrics', () {
    for (final width in [320.0, 360.0]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          '${width.toInt()}dp at textScale $textScale: no layout error',
          (tester) async {
            final errors = await collectLayoutErrors(
              () => _pumpLogin(
                tester,
                Size(width, 640),
                locale: _zhHant,
                textScale: textScale,
              ),
            );
            _expectTextScaleReached(tester, find.byType(LoginScreen), textScale);
            expect(
              errors.map((e) => e.exception.toString().split('\n').first).toList(),
              isEmpty,
            );
            final card = tester.getSize(find.byKey(const Key('login-card')));
            expect(card.width, lessThanOrEqualTo(width));
          },
        );
      }
    }
  });
}

/// Asserts the [expected] text scale actually reached the screen under test.
///
/// `MaterialApp` rebuilds its own `MediaQuery` from the test view, and only
/// *some* fields of an ancestor `MediaQuery` survive that. If `textScaler`
/// were not one of them, every textScale-2.0 case below would silently render
/// at 1.0 and pass as a guard that cannot fail — the exact failure shape this
/// repo has hit before. So the scale is read back from inside the tree.
void _expectTextScaleReached(
  WidgetTester tester,
  Finder screen,
  double expected,
) {
  final scaler = MediaQuery.of(tester.element(screen)).textScaler;
  expect(
    scaler.scale(16),
    16 * expected,
    reason: 'textScale $expected never reached the screen under test',
  );
}

/// The family name the theme actually applies, read from the theme rather
/// than typed again — so this file can never load a real font under a name
/// nothing renders with.
final String _appFontFamily = lightTheme.textTheme.titleMedium!.fontFamily!;

const _fontAssetPath = 'assets/fonts/NotoSans-Subset-VariableFont.ttf';

const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

/// The legibility floor for a `_SnapshotTile` value under real Noto metrics.
///
/// Deliberately the same 0.65 `home_screen_responsive_test.dart` pins with the
/// placeholder font: the point of this file is that the real font must clear
/// the same bar, not a relaxed one.
const _minValueScale = 0.65;

/// `_SnapshotTile`'s own padding (12 each side), as in the responsive guard.
const _tilePadding = 24.0;

/// Asserts the figure [part] inside tile [tileKey] is painted as one
/// un-truncated line that fits its tile and is still legible — the same trio
/// `_expectValueFitsOneLine` asserts in `home_screen_responsive_test.dart`,
/// but with the real font loaded.
///
/// Verified by mutation against `home_screen.dart`, one at a time, with the
/// real font loaded:
///
/// | mutation | result |
/// | --- | --- |
/// | `_tileValue` → plain `Text` (no `FittedBox`, no `maxLines`) | RED — line count: `Expected: <1> Actual: <2>` |
/// | value style `titleMedium` → `headlineMedium` | RED — `shrunk to 0.472×, below the legibility floor of 0.65` |
/// | drop only the `FittedBox`, keeping `maxLines: 1`/`softWrap: false` | RED — right-most glyph spills past the tile |
///
/// The third row used to be a silent survivor: with `maxLines: 1` and
/// `softWrap: false` still in place the paragraph cannot wrap, so it reports
/// one line and — because `tester.getRect(value).width` measures the *box*,
/// which an unshrunk `Text` still reports no wider than its tile once
/// clipped — the width assertion stayed quiet too. What it cannot hide is
/// where the glyphs themselves paint: [paintedTextRight] reads the painted
/// run through `localToGlobal`, so it carries the (now-missing) `FittedBox`
/// scale transform, and an unshrunk 11-digit figure paints well past the
/// tile's right edge. That is exactly the #189/#190 failure shape (a figure
/// that reads as a different, truncated number), so it is why the caller
/// pumps the 11-digit fixture at 360dp rather than anything smaller — only a
/// fixture long enough to actually overflow makes this assertion meaningful.
void _expectValueLegible(
  WidgetTester tester,
  String tileKey,
  String part, {
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

  // Closes the FittedBox-removal survivor documented above: a `Text` whose
  // box is clipped to the tile can still paint its glyphs past the tile's
  // right edge once the `FittedBox` that would have shrunk them is gone.
  // `paintedTextRight` reads the actual painted run (carrying the FittedBox
  // scale transform when present), so it catches what the rect-width check
  // above cannot.
  expect(
    paintedTextRight(tester, value),
    lessThanOrEqualTo(tile.right - _tilePadding / 2),
    reason: '$reason: right-most painted glyph spills past the tile',
  );

  final scale = paintedScaleOf(tester, value);
  expect(
    scale,
    greaterThanOrEqualTo(_minValueScale),
    reason:
        '$reason: shrunk to ${scale.toStringAsFixed(3)}×, below the legibility '
        'floor of $_minValueScale',
  );
}

/// Every arm failed with nothing this session ever fetched — the rendering
/// where the tile has no figure to keep and prints what happened instead.
HomeDashboardData _allFailedCold() {
  const from = HomeDashboardData.allLoading();
  return HomeDashboardData(
    weightGoal: ArmSlot.failedAfter(from.weightGoal),
    bloodPressure: ArmSlot.failedAfter(from.bloodPressure),
    menstrualStatus: ArmSlot.failedAfter(from.menstrualStatus),
    overallBudget: ArmSlot.failedAfter(from.overallBudget),
    netWorth: ArmSlot.failedAfter(from.netWorth),
    splitBalances: ArmSlot.failedAfter(from.splitBalances),
    dailyTarget: ArmSlot.failedAfter(from.dailyTarget),
  );
}

/// A dashboard carrying the two figures the #189 regression was about —
/// `456,700` behind 本月預算's "剩餘 …" wrapper and `9,999,999` bare on 淨值.
/// Both are thousands-grouped, which is where Noto's much wider comma
/// (+60% over Quicksand's) actually lands.
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
          remaining: 456700,
          percent: 9,
        ),
        netWorth: MonthlyNetWorth(
          month: '2026-01',
          accounts: [],
          totalAsset: 9999999,
          // Not equal to the net worth: 總負債 prints the same bare format,
          // and an identical value would make the finder match two tiles.
          totalLiability: 8765432,
          netWorth: 9999999,
          prevNetWorth: null,
          growthRate: null,
        ),
        splitBalances: [],
        // A real target, not `null`. `null` is the degraded shape — it means
        // the daily-target arm of the fan-out failed — and it makes 食物份量
        // print 尚無資料, three Han glyphs that this file's font does not
        // contain (caveat 2 above) and that therefore measure the *host's*
        // fallback font. Since this is the only test in the repo that can see
        // the real .ttf, degrading that tile would silently exclude the newest
        // and most font-sensitive string on the dashboard — `10主 7肉 2果 2菜`,
        // whose digits and spaces are exactly the Latin half this file can
        // falsify — from the one place able to measure it. It matters most
        // here: this is the fixture the textScale-2.0 case pumps, and #196's
        // `_widestFitting` decides whether the 菜 group survives by laying the
        // candidates out with a `TextPainter` under the ambient `textScaler`,
        // i.e. a real-font-width decision taken at the scale under test.
        dailyTarget: testDailyTarget,
      );

/// A dashboard printing the widest figures the finance tiles can ever hold —
/// the only fixture whose value is long enough, under real Noto metrics, to
/// need the `FittedBox` at a two-column tile width.
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
          netWorth: -99999999999,
          prevNetWorth: null,
          growthRate: null,
        ),
        splitBalances: [],
        // Same target as the other fixture, for the same reason: `null` is the
        // failed-arm shape, and pumping a screen with one tile degraded would
        // measure the easy case. It is deliberately *not* inflated to make
        // this fixture "longest" on the 食物份量 tile too — the case below
        // asserts on 本月預算 only, so this value has to be realistic, not
        // extremal. Worth recording what it renders, because it is a real-font
        // *difference*: at 360dp this tile paints all four groups
        // (`10主 7肉 2果 2菜`), while `home_screen_responsive_test.dart` pins
        // 332–385.5dp as the band where the 菜 group is dropped. Both are
        // right — that band was measured under the placeholder font, whose
        // glyphs are fontSize squares and so wider than real Noto's, and
        // `_widestFitting` re-decides per font. Nothing to reconcile; it is
        // the same font-blindness this file exists to expose.
        dailyTarget: testDailyTarget,
      );

Future<void> _pumpHome(
  WidgetTester tester,
  Size size, {
  required Locale locale,
  double textScale = 1.0,
  HomeDashboardController? dashboard,
}) async {
  await _sizeSurface(tester, size);
  final controller = HomeController(
    GetProfile(_FakeProfileRepository()),
    SignOut(_FakeAuthRepository()),
  );
  await controller.load('token-123');
  final mask = await testPrivacyMaskController();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: l10nTestApp(
        theme: lightTheme,
        locale: locale,
        home: HomeScreen(
          controller: controller,
          privacyMaskController: mask,
          dashboardController: dashboard ?? _financeAmountsFixture(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpLogin(
  WidgetTester tester,
  Size size, {
  required Locale locale,
  double textScale = 1.0,
}) async {
  await _sizeSurface(tester, size);
  final repository = _FakeAuthRepository();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: l10nTestApp(
        theme: lightTheme,
        locale: locale,
        home: LoginScreen(
          controller: LoginController(SignIn(repository)),
          localeController: await testLocaleController(),
          signUp: SignUp(repository),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The menstrual day marker's fixed circle diameter, and the usable chord
/// across it — a circle is not a square, so content wider than the chord
/// spills past the fill even when it is narrower than the diameter.
const _markerDiameter = 32.0;
const _markerChord = 28.0;

/// Pumps a [MenstrualCalendar] on a 320dp phone — the narrowest supported
/// width, where the seven `Expanded` cells are tightest — showing July 2026
/// with a period running the 10th to the 14th, so 2026-07-12 is a two-digit
/// date over a single-digit cycle day.
Future<void> _pumpMenstrualCalendar(
  WidgetTester tester, {
  required double textScale,
}) async {
  await _sizeSurface(tester, const Size(320, 900));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: l10nTestApp(
        theme: lightTheme,
        home: Scaffold(
          body: MenstrualCalendar(
            overview: MenstrualOverview(
              periods: [
                MenstrualPeriod(
                  id: 'p1',
                  startDate: DateTime(2026, 7, 10),
                  endDate: DateTime(2026, 7, 14),
                ),
              ],
              stats: const MenstrualStats(),
            ),
            clock: () => DateTime(2026, 7, 22),
            onDayTap: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _sizeSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

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
