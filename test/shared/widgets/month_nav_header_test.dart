import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/widgets/month_nav_header.dart';

void main() {
  group('MonthNavHeader', () {
    testWidgets('renders the month label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: '2026-07',
              keyPrefix: 'nw-month',
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('nw-month-label')), findsOneWidget);
      expect(find.text('2026-07'), findsOneWidget);
    });

    testWidgets('previous arrow invokes onPrevious', (tester) async {
      var previousTaps = 0;
      var nextTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: '2026-07',
              keyPrefix: 'nw-month',
              onPrevious: () => previousTaps++,
              onNext: () => nextTaps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('nw-month-previous')));
      expect(previousTaps, 1);
      expect(nextTaps, 0);
    });

    testWidgets('next arrow invokes onNext', (tester) async {
      var previousTaps = 0;
      var nextTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: '2026-07',
              keyPrefix: 'nw-month',
              onPrevious: () => previousTaps++,
              onNext: () => nextTaps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('nw-month-next')));
      expect(nextTaps, 1);
      expect(previousTaps, 0);
    });

    testWidgets('keyPrefix isolates two instances on one screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MonthNavHeader(
                  monthLabel: '2026-07',
                  keyPrefix: 'finance-month',
                  onPrevious: () {},
                  onNext: () {},
                ),
                MonthNavHeader(
                  monthLabel: '2026-08',
                  keyPrefix: 'networth-month',
                  onPrevious: () {},
                  onNext: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Both key sets coexist without collision.
      expect(find.byKey(const Key('finance-month-previous')), findsOneWidget);
      expect(find.byKey(const Key('finance-month-label')), findsOneWidget);
      expect(find.byKey(const Key('finance-month-next')), findsOneWidget);
      expect(find.byKey(const Key('networth-month-previous')), findsOneWidget);
      expect(find.byKey(const Key('networth-month-label')), findsOneWidget);
      expect(find.byKey(const Key('networth-month-next')), findsOneWidget);
    });
  });
}
