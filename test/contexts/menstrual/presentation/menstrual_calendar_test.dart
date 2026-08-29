import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/next_period_status.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_calendar.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('marking helpers', () {
    test('a day within a closed period range is a period day', () {
      final periods = [
        MenstrualPeriod(
          id: 'p1',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 5),
        ),
      ];
      final today = DateTime(2026, 5, 20);

      expect(isMenstrualPeriodDay(DateTime(2026, 5, 1), periods, today), isTrue);
      expect(isMenstrualPeriodDay(DateTime(2026, 5, 3), periods, today), isTrue);
      expect(isMenstrualPeriodDay(DateTime(2026, 5, 5), periods, today), isTrue);
      expect(
        isMenstrualPeriodDay(DateTime(2026, 5, 6), periods, today),
        isFalse,
      );
      expect(
        isMenstrualPeriodDay(DateTime(2026, 4, 30), periods, today),
        isFalse,
      );
    });

    test('an open period is marked from its start through today', () {
      final periods = [
        MenstrualPeriod(id: 'p1', startDate: DateTime(2026, 6, 1)),
      ];
      final today = DateTime(2026, 6, 3);

      expect(isMenstrualPeriodDay(DateTime(2026, 6, 1), periods, today), isTrue);
      expect(isMenstrualPeriodDay(DateTime(2026, 6, 3), periods, today), isTrue);
      expect(
        isMenstrualPeriodDay(DateTime(2026, 6, 4), periods, today),
        isFalse,
      );
    });

    test('cycle day counts from the start of a closed period', () {
      final periods = [
        MenstrualPeriod(
          id: 'p1',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 5),
        ),
      ];
      final today = DateTime(2026, 5, 20);

      expect(menstrualCycleDay(DateTime(2026, 5, 1), periods, today), 1);
      expect(menstrualCycleDay(DateTime(2026, 5, 3), periods, today), 3);
      expect(menstrualCycleDay(DateTime(2026, 5, 5), periods, today), 5);
      expect(menstrualCycleDay(DateTime(2026, 5, 6), periods, today), isNull);
      expect(menstrualCycleDay(DateTime(2026, 4, 30), periods, today), isNull);
    });

    test('an open period counts through today and no further', () {
      final periods = [
        MenstrualPeriod(id: 'p1', startDate: DateTime(2026, 6, 1)),
      ];
      final today = DateTime(2026, 6, 4);

      expect(menstrualCycleDay(DateTime(2026, 6, 4), periods, today), 4);
      // Still inside the visible month, but after today: an open period is
      // bounded by today, not by the month.
      expect(menstrualCycleDay(DateTime(2026, 6, 5), periods, today), isNull);
      expect(menstrualCycleDay(DateTime(2026, 6, 30), periods, today), isNull);
    });

    test('overlapping periods resolve to the later start, not the earlier', () {
      final periods = [
        MenstrualPeriod(
          id: 'earlier',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 6),
        ),
        MenstrualPeriod(
          id: 'later',
          startDate: DateTime(2026, 5, 3),
          endDate: DateTime(2026, 5, 8),
        ),
      ];
      final today = DateTime(2026, 5, 20);

      expect(menstrualCycleDay(DateTime(2026, 5, 3), periods, today), 1);
    });

    test('an unclosed period is not capped', () {
      final today = DateTime(2026, 6, 10);
      final periods = [
        MenstrualPeriod(
          id: 'p1',
          startDate: today.subtract(const Duration(days: 40)),
        ),
      ];

      expect(menstrualCycleDay(today, periods, today), 41);
    });

    // The calendar duplicates the largest-start overlap rule that
    // `computeNextPeriodStatus` applies for the overview card; this pins the
    // spec scenario that the two can never disagree about today.
    test("today's number matches the overview card's ongoing day count", () {
      final overview = MenstrualOverview(
        periods: [
          MenstrualPeriod(
            id: 'earlier',
            startDate: DateTime(2026, 5, 1),
            endDate: DateTime(2026, 5, 12),
          ),
          MenstrualPeriod(id: 'later', startDate: DateTime(2026, 5, 3)),
        ],
        stats: const MenstrualStats(),
      );
      final today = DateTime(2026, 5, 6);

      final status = computeNextPeriodStatus(overview, today);
      expect(status.state, NextPeriodState.ongoing);
      expect(
        menstrualCycleDay(today, overview.periods, today),
        status.days,
      );
    });

    test('predicted next start matches only that day', () {
      const stats = MenstrualStats(predictedNextStart: null);
      expect(isPredictedNextStart(DateTime(2026, 7, 24), stats), isFalse);

      final withPrediction = MenstrualStats(
        predictedNextStart: DateTime(2026, 7, 24),
      );
      expect(
        isPredictedNextStart(DateTime(2026, 7, 24), withPrediction),
        isTrue,
      );
      expect(
        isPredictedNextStart(DateTime(2026, 7, 23), withPrediction),
        isFalse,
      );
    });
  });

  group('MenstrualCalendar widget', () {
    Widget calendar(MenstrualOverview overview) => l10nTestApp(
      home: Scaffold(
        body: MenstrualCalendar(
          overview: overview,
          clock: () => DateTime(2026, 7, 22),
          onDayTap: (_) {},
        ),
      ),
    );

    testWidgets('renders the visible month and advances on next-month', (
      tester,
    ) async {
      await tester.pumpWidget(
        calendar(
          const MenstrualOverview(periods: [], stats: MenstrualStats()),
        ),
      );

      expect(
        find.text(DateFormat.yMMM().format(DateTime(2026, 7))),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('menstrual-next-month')));
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat.yMMM().format(DateTime(2026, 8))),
        findsOneWidget,
      );
    });

    testWidgets('marks each day of a period range', (tester) async {
      final overview = MenstrualOverview(
        periods: [
          MenstrualPeriod(
            id: 'p1',
            startDate: DateTime(2026, 7, 1),
            endDate: DateTime(2026, 7, 5),
          ),
        ],
        stats: const MenstrualStats(),
      );
      await tester.pumpWidget(calendar(overview));

      for (final d in [1, 2, 3, 4, 5]) {
        final marker = tester.widget<Container>(
          find.byKey(Key('menstrual-day-marker-2026-07-0$d')),
        );
        final decoration = marker.decoration as BoxDecoration;
        expect(
          decoration.color,
          isNotNull,
          reason: 'day $d should be filled as a period day',
        );
      }
      final unmarked = tester.widget<Container>(
        find.byKey(const Key('menstrual-day-marker-2026-07-06')),
      );
      expect((unmarked.decoration as BoxDecoration).color, isNull);
    });

    testWidgets('marks the predicted next start distinctly (outline, not fill)',
        (tester) async {
      final overview = MenstrualOverview(
        periods: const [],
        stats: MenstrualStats(predictedNextStart: DateTime(2026, 7, 24)),
      );
      await tester.pumpWidget(calendar(overview));

      final marker = tester.widget<Container>(
        find.byKey(const Key('menstrual-day-marker-2026-07-24')),
      );
      final decoration = marker.decoration as BoxDecoration;
      expect(decoration.color, isNull, reason: 'predicted day is not filled');
      expect(decoration.border, isNotNull, reason: 'predicted day is outlined');
    });

    testWidgets('a period day cell exposes a period Semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final overview = MenstrualOverview(
        periods: [
          MenstrualPeriod(
            id: 'p1',
            startDate: DateTime(2026, 7, 1),
            endDate: DateTime(2026, 7, 5),
          ),
        ],
        stats: const MenstrualStats(),
      );
      await tester.pumpWidget(calendar(overview));

      final expected = loc.menstrualDaySemanticPeriod(
        DateFormat.yMMMd().format(DateTime(2026, 7, 3)),
        3,
      );
      expect(find.bySemanticsLabel(expected), findsOneWidget);
      handle.dispose();
    });

    testWidgets('renders a legend explaining the two markers', (tester) async {
      await tester.pumpWidget(
        calendar(
          const MenstrualOverview(periods: [], stats: MenstrualStats()),
        ),
      );

      expect(find.byKey(const Key('menstrual-legend')), findsOneWidget);
      expect(find.text(loc.menstrualLegendPeriod), findsOneWidget);
      expect(find.text(loc.menstrualLegendPredicted), findsOneWidget);
      expect(find.text(loc.menstrualLegendCycleDay), findsOneWidget);
    });

    testWidgets('the legend lays out on a 320dp phone at a 2.0 text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await expectNoLayoutErrors(() async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: calendar(
              const MenstrualOverview(periods: [], stats: MenstrualStats()),
            ),
          ),
        );
      });

      expect(find.text(loc.menstrualLegendPeriod), findsOneWidget);
      expect(find.text(loc.menstrualLegendPredicted), findsOneWidget);
      expect(find.text(loc.menstrualLegendCycleDay), findsOneWidget);
    });

    testWidgets('a period day marker shows the date and the cycle day', (
      tester,
    ) async {
      // The period deliberately starts mid-month so the day-of-month (12) and
      // the cycle day (3) are different strings — a period starting on the
      // 1st makes them identical and the assertion unfalsifiable.
      final overview = MenstrualOverview(
        periods: [
          MenstrualPeriod(
            id: 'p1',
            startDate: DateTime(2026, 7, 10),
            endDate: DateTime(2026, 7, 14),
          ),
        ],
        stats: const MenstrualStats(),
      );
      await tester.pumpWidget(calendar(overview));

      final marker = find.byKey(const Key('menstrual-day-marker-2026-07-12'));
      expect(
        find.descendant(of: marker, matching: find.text('12')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: marker, matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets(
      'non-period days, the predicted next start and today carry no cycle day',
      (tester) async {
        final overview = MenstrualOverview(
          periods: [
            MenstrualPeriod(
              id: 'p1',
              startDate: DateTime(2026, 7, 10),
              endDate: DateTime(2026, 7, 14),
            ),
          ],
          stats: MenstrualStats(predictedNextStart: DateTime(2026, 7, 24)),
        );
        await tester.pumpWidget(calendar(overview));

        // 07-16 is an ordinary day, 07-24 the predicted next start, 07-22 the
        // injected clock's today: each renders one number, its own date.
        for (final day in ['16', '24', '22']) {
          final marker = find.byKey(Key('menstrual-day-marker-2026-07-$day'));
          expect(
            find.descendant(of: marker, matching: find.byType(Text)),
            findsOneWidget,
            reason: 'day $day should render only its day-of-month number',
          );
          expect(
            find.descendant(of: marker, matching: find.text(day)),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('the marker text scale is clamped to 1.3 and does not overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final overview = MenstrualOverview(
        periods: [
          MenstrualPeriod(
            id: 'p1',
            startDate: DateTime(2026, 7, 10),
            endDate: DateTime(2026, 7, 14),
          ),
        ],
        stats: const MenstrualStats(),
      );

      await expectNoLayoutErrors(() async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: calendar(overview),
          ),
        );
      });

      final marker = find.byKey(const Key('menstrual-day-marker-2026-07-12'));
      final scaler = MediaQuery.of(
        tester.element(find.descendant(of: marker, matching: find.text('3'))),
      ).textScaler;
      expect(scaler.scale(10), 13.0);

      // The legend keeps the unclamped scale — only the marker is capped.
      final legendScaler = MediaQuery.of(
        tester.element(find.text(loc.menstrualLegendCycleDay)),
      ).textScaler;
      expect(legendScaler.scale(10), 20.0);
    });
  });
}
