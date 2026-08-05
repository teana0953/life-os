import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/health_calendar/application/get_health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_exceptions.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_repository.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_card.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/stale_notice.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';

class _FakeRepository implements HealthCalendarRepository {
  Object? error;
  int getCalls = 0;

  /// When set, `getCalendar` waits on this before completing — lets a test
  /// observe the in-flight loading state of a reload.
  Completer<void>? gate;
  HealthCalendar Function(int year, int month) build =
      (year, month) => HealthCalendar(
            year: year,
            month: month,
            loggedDays: const {'2026-07-03', '2026-07-04'},
            daysElapsed: 5,
            loggingRate: 20,
            dietAdherenceRate: 40,
          );

  @override
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) async {
    getCalls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return build(year, month);
  }
}

Future<HealthCalendarController> _pump(
  WidgetTester tester,
  _FakeRepository repo, {
  int? weightAchievementRate = 75,
  Locale locale = const Locale('en'),
}) async {
  final controller = HealthCalendarController(
    GetHealthCalendar(repo),
    clock: () => DateTime(2026, 7, 5),
  );
  await controller.load('token');
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          // Mirrors the real host (`health_scaffold.dart`'s overview/trends
          // lists): without this padding every width test here measures a
          // card 40dp wider than the one on the phone.
          padding: const EdgeInsets.all(20),
          child: HealthCalendarCard(
            controller: controller,
            idToken: () async => 'token',
            weightAchievementRate: weightAchievementRate,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('shows three rings, the month dots, and a legend', (tester) async {
    await _pump(tester, _FakeRepository());

    // Three adherence rings.
    expect(find.byKey(const Key('health-calendar-ring-logging')), findsOneWidget);
    expect(find.byKey(const Key('health-calendar-ring-diet')), findsOneWidget);
    expect(find.byKey(const Key('health-calendar-ring-weight')), findsOneWidget);

    // The month rates + the reused weight-goal rate are shown.
    expect(find.text('20%'), findsOneWidget); // logging rate
    expect(find.text('40%'), findsOneWidget); // diet adherence
    expect(find.text('75%'), findsOneWidget); // weight achievement (reused)

    // Dots mark the two logged days but not an unlogged one.
    expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
    expect(find.byKey(const Key('health-calendar-dot-4')), findsOneWidget);
    expect(find.byKey(const Key('health-calendar-dot-15')), findsNothing);

    expect(find.byKey(const Key('health-calendar-legend')), findsOneWidget);
  });

  testWidgets('a null rate shows an empty ring and no percentage', (tester) async {
    final repo = _FakeRepository()
      ..build = (year, month) => HealthCalendar(
            year: year,
            month: month,
            loggedDays: const {},
            daysElapsed: 0,
            loggingRate: null,
            dietAdherenceRate: null,
          );
    await _pump(tester, repo, weightAchievementRate: null);

    // No percentage text anywhere (all three rings are null).
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('an error with no month drawn yet shows a retry that reloads', (
    tester,
  ) async {
    final repo = _FakeRepository()..error = const HealthCalendarFetchFailure();
    final controller = HealthCalendarController(
      GetHealthCalendar(repo),
      clock: () => DateTime(2026, 7, 5),
    );
    await controller.load('token');
    await tester.pumpWidget(
      l10nTestApp(
        home: Scaffold(
          body: HealthCalendarCard(
            controller: controller,
            idToken: () async => 'token',
            weightAchievementRate: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_en.healthCalendarLoadFailed), findsOneWidget);
    // Nothing has been drawn, so there is nothing to mark as unrefreshed.
    expect(find.byType(StaleNotice), findsNothing);

    repo.error = null;
    await tester.tap(find.byKey(const Key('health-calendar-retry')));
    await tester.pumpAndSettle();

    expect(controller.status, HealthCalendarStatus.loaded);
    expect(find.byKey(const Key('health-calendar-ring-logging')), findsOneWidget);
  });

  testWidgets('a first-ever load in flight shows the loading state', (
    tester,
  ) async {
    final repo = _FakeRepository();
    final controller = HealthCalendarController(
      GetHealthCalendar(repo),
      clock: () => DateTime(2026, 7, 5),
    );
    // Deliberately not awaiting load() — status stays `loading` with no month
    // held yet. `pump`, not `pumpAndSettle`: the spinner never settles.
    await tester.pumpWidget(
      l10nTestApp(
        home: Scaffold(
          body: HealthCalendarCard(
            controller: controller,
            idToken: () async => 'token',
            weightAchievementRate: null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('health-calendar-loading')), findsOneWidget);
  });

  testWidgets(
    'a reload in flight keeps the month it already drew, unmarked — a refresh '
    'in flight is not a failure',
    (tester) async {
      final repo = _FakeRepository();
      final controller = await _pump(tester, repo);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);

      final gate = Completer<void>();
      repo.gate = gate;
      unawaited(controller.load('token'));
      await tester.pump();

      expect(find.byKey(const Key('health-calendar-loading')), findsNothing);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
      // The marking's row, not [StaleNotice] itself: the card keeps the widget
      // mounted through a reload so it can remember a retry the user pressed,
      // and it renders nothing until it has something to say.
      expect(find.byKey(const Key('stale-notice-row')), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a failed reload keeps the month it already drew and marks it as not '
    'refreshed — the largest card on the overview does not disappear',
    (tester) async {
      final repo = _FakeRepository();
      final controller = await _pump(tester, repo);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);

      repo.error = const HealthCalendarFetchFailure();
      await controller.load('token');
      await tester.pumpAndSettle();

      expect(controller.status, HealthCalendarStatus.error);
      expect(find.text(_en.healthCalendarLoadFailed), findsNothing);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
      expect(find.byKey(const Key('health-calendar-ring-logging')), findsOneWidget);
      expect(find.byType(StaleNotice), findsOneWidget);
      expect(find.text(_en.cardRefreshFailed), findsOneWidget);
    },
  );

  testWidgets(
    'a reload that 401s is not the card\'s to report — no marking, no error '
    'card, the overview\'s re-authenticate exit takes over',
    (tester) async {
      final repo = _FakeRepository();
      final controller = await _pump(tester, repo);

      repo.error = const HealthCalendarReauthenticationRequired();
      await controller.load('token');
      await tester.pumpAndSettle();

      expect(controller.status, HealthCalendarStatus.needsReauth);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
      // "Couldn't refresh, retry" would send the user round a loop that
      // cannot succeed until they sign in again.
      expect(find.byType(StaleNotice), findsNothing);
      expect(find.text(_en.healthCalendarLoadFailed), findsNothing);
    },
  );

  testWidgets('the marking\'s retry reloads the calendar and clears it on '
      'success', (tester) async {
    final repo = _FakeRepository();
    final controller = await _pump(tester, repo);
    repo.error = const HealthCalendarFetchFailure();
    await controller.load('token');
    await tester.pumpAndSettle();
    final callsBefore = repo.getCalls;

    repo.error = null;
    await tester.tap(find.byKey(const Key('stale-notice-retry')));
    await tester.pumpAndSettle();

    expect(repo.getCalls, callsBefore + 1);
    expect(find.byType(StaleNotice), findsNothing);
    expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
  });

  group('month switching', () {
    testWidgets('opens on the current month', (tester) async {
      final repo = _FakeRepository();
      await _pump(tester, repo);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('health-calendar-month-label')))
            .data,
        DateFormat.yMMM('en').format(DateTime(2026, 7)),
      );
    });

    testWidgets('the previous arrow loads the month before', (tester) async {
      final repo = _FakeRepository();
      final controller = await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('health-calendar-month-previous')));
      await tester.pumpAndSettle();

      expect(controller.selectedMonth, DateTime(2026, 6));
      expect(controller.calendar!.month, 6);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('health-calendar-month-label')))
            .data,
        DateFormat.yMMM('en').format(DateTime(2026, 6)),
      );
    });

    testWidgets('the label opens the picker and jumping loads that month', (
      tester,
    ) async {
      final repo = _FakeRepository()
        ..build = (year, month) => HealthCalendar(
              year: year,
              month: month,
              loggedDays: {'$year-${month.toString().padLeft(2, '0')}-09'},
              daysElapsed: 30,
              loggingRate: 50,
              dietAdherenceRate: 50,
            );
      final controller = await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('health-calendar-month-label')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month-picker-year-previous')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month-picker-month-2')));
      await tester.pumpAndSettle();

      expect(controller.selectedMonth, DateTime(2025, 2));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('health-calendar-month-label')))
            .data,
        DateFormat.yMMM('en').format(DateTime(2025, 2)),
      );
      // The dots belong to the month now labelled, not the one left behind.
      expect(find.byKey(const Key('health-calendar-dot-9')), findsOneWidget);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsNothing);
    });

    testWidgets('the switcher stays reachable while the new month loads', (
      tester,
    ) async {
      final repo = _FakeRepository();
      final controller = await _pump(tester, repo);

      final gate = Completer<void>();
      repo.gate = gate;
      unawaited(controller.loadMonth('token', 2026, 6));
      await tester.pump();

      // The outgoing month's dots are gone (never drawn under June's label)
      // and the switcher is still there to get back.
      expect(find.byKey(const Key('health-calendar-dot-3')), findsNothing);
      expect(find.byKey(const Key('health-calendar-loading')), findsOneWidget);
      expect(
        find.byKey(const Key('health-calendar-month-label')),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
    });

    // Regression: the month label's `▾` affordance added padding + an icon to
    // a centred, non-shrinkable Row, which blew the card's header out of a
    // narrow phone — and the first fix (ellipsis) traded that for silently
    // eating the month digits. Widget tests default to an 800x600 surface, so
    // nothing else in this mobile-first PWA's suite would have caught either.
    // The pump reproduces `health_scaffold`'s 20dp page padding: without it
    // the card under test is 40dp wider than on a real phone — exactly the
    // 40dp where the label starts losing characters.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the month label stays whole at ${width.toInt()}dp, locale=$locale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await _pump(tester, _FakeRepository(), locale: locale);

            expect(tester.takeException(), isNull);
            expectMonthLabelFullyVisible(
              tester,
              const Key('health-calendar-month-label'),
            );
            expectMonthLabelReadable(
              tester,
              const Key('health-calendar-month-label'),
            );
            final prev = tester.getRect(
              find.byKey(const Key('health-calendar-month-previous')),
            );
            final next = tester.getRect(
              find.byKey(const Key('health-calendar-month-next')),
            );
            expect(prev.left, greaterThanOrEqualTo(0));
            expect(next.right, lessThanOrEqualTo(width));
          },
        );
      }
    }
  });

  // Regression: the readable floor was computed from the **authored** font
  // size while the `FittedBox` scales `textScaler`-sized glyphs, so the width
  // cap bit `textScaler`× too early — a user on a large system font size got
  // the month digits ellipsized away (`2026年7月` → `202…`): the exact failure
  // the floor was added to prevent, reintroduced by the fix for it. Nothing in
  // this suite set a text scale at all before this.
  group('month label at a large system text scale', () {
    for (final textScale in [2.0, 3.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the month label stays whole at 320dp, textScale=$textScale, '
          'locale=$locale',
          (tester) async {
            useTextScaleFactor(tester, textScale);
            await tester.binding.setSurfaceSize(const Size(320, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await _pump(tester, _FakeRepository(), locale: locale);

            expect(tester.takeException(), isNull);
            expectMonthLabelFullyVisible(
              tester,
              const Key('health-calendar-month-label'),
            );
            expectMonthLabelPaintedReadable(
              tester,
              const Key('health-calendar-month-label'),
            );
          },
        );
      }
    }
  });

  // The floor's only *real-entry* guard. At 320dp the tightest real label
  // still paints at 14px, so deleting the `ConstrainedBox` from
  // `ShrinkToFitText` — or dropping the 12 to 6 — left every real-entry test
  // green and only the synthetic 160dp `MonthNavHeader` test red. 280dp is a
  // 320dp phone at ~115% browser zoom (this ships as a PWA) and is the first
  // width where this card's label actually reaches the floor: it holds
  // exactly 12px and ellipsizes rather than shrinking on.
  group('month label at the readable floor', () {
    for (final textScale in [1.0, 2.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the month label holds the 12px floor at 280dp, '
          'textScale=$textScale, locale=$locale',
          (tester) async {
            useTextScaleFactor(tester, textScale);
            await tester.binding.setSurfaceSize(const Size(280, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await _pump(tester, _FakeRepository(), locale: locale);

            expect(tester.takeException(), isNull);
            expectMonthLabelPaintedReadable(
              tester,
              const Key('health-calendar-month-label'),
            );
            expect(
              monthLabelPaintedFontSize(
                tester,
                const Key('health-calendar-month-label'),
              ),
              closeTo(monthLabelMinFontSize, 0.01),
              reason: 'the label should sit *on* the floor at this width',
            );
          },
        );
      }
    }
  });

  // The card's own overflow guard: the three-ring row (`spaceEvenly`, whose
  // unconstrained ring labels pushed it 12px past 320dp/en) and the month-dot
  // day cells (fixed 36dp tall, so every one of them overflowed vertically at
  // a 2x text scale). Asserts *no layout error of any kind* rather than
  // draining with `takeException()` — see `test/support/layout_guard.dart`.
  group('narrow-width layout guard', () {
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'the card lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, 1600));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              await expectNoLayoutErrors(
                () => _pump(tester, _FakeRepository(), locale: locale),
              );

              // A blank card also reports no layout error, so pin that the two
              // things this guard is about — the month grid and the ring row —
              // actually rendered.
              expect(
                find.byKey(const Key('health-calendar-month-label')),
                findsOneWidget,
              );
              for (final ring in ['logging', 'diet', 'weight']) {
                expect(
                  find.byKey(Key('health-calendar-ring-$ring')),
                  findsOneWidget,
                );
              }
            },
          );
        }
      }
    }
  });
}
