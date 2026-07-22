import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_calendar.dart';

import '../../../support/l10n_test_app.dart';

void main() {
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
  });
}
