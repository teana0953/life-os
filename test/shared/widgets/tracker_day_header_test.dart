import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/shared/widgets/tracker_day_header.dart';

import '../../support/l10n_test_app.dart';

void main() {
  group('TrackerDayHeader', () {
    testWidgets('for today shows the today title and today\'s date', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: const Scaffold(
            body: TrackerDayHeader(
              day: '2026-07-18',
              clock: _todayClock,
              todayTitle: 'Today title',
              historyTitle: 'History title',
            ),
          ),
        ),
      );
      await tester.pump();

      final expectedDate = DateFormat(
        'EEE, MMM d',
        'en',
      ).format(DateTime(2026, 7, 18));

      expect(find.text('Today title'), findsOneWidget);
      expect(find.text('History title'), findsNothing);
      expect(find.textContaining(expectedDate), findsOneWidget);
    });

    testWidgets('for a past day shows the history title and that day\'s date', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: const Scaffold(
            body: TrackerDayHeader(
              day: '2026-07-17',
              clock: _todayClock,
              todayTitle: 'Today title',
              historyTitle: 'History title',
            ),
          ),
        ),
      );
      await tester.pump();

      final expectedDate = DateFormat(
        'EEE, MMM d',
        'en',
      ).format(DateTime(2026, 7, 17));

      expect(find.text('History title'), findsOneWidget);
      expect(find.text('Today title'), findsNothing);
      expect(find.textContaining(expectedDate), findsOneWidget);
    });
  });
}

DateTime _todayClock() => DateTime(2026, 7, 18, 9);
