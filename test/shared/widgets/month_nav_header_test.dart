import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/month_nav_header.dart';

import '../../support/l10n_test_app.dart';
import '../../support/month_label.dart';
import '../../support/semantics_tree.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

void main() {
  group('MonthNavHeader', () {
    testWidgets('renders the month label', (tester) async {
      await tester.pumpWidget(
        l10nTestApp(
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
        l10nTestApp(
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
        l10nTestApp(
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

    testWidgets('both arrows carry a tooltip for sighted and screen-reader use', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: 'Jul 2026',
              keyPrefix: 'nw-month',
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(
        tester.widget<IconButton>(find.byKey(const Key('nw-month-previous'))).tooltip,
        _loc.monthNavPreviousTooltip,
      );
      expect(
        tester.widget<IconButton>(find.byKey(const Key('nw-month-next'))).tooltip,
        _loc.monthNavNextTooltip,
      );
    });

    testWidgets('keyPrefix isolates two instances on one screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
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

    testWidgets('without onPickMonth the label is not tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
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

      expect(
        find.ancestor(
          of: find.byKey(const Key('nw-month-label')),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('with onPickMonth tapping the label invokes it', (
      tester,
    ) async {
      var picks = 0;
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: '2026-07',
              keyPrefix: 'nw-month',
              onPrevious: () {},
              onNext: () {},
              onPickMonth: () => picks++,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('nw-month-label')));
      expect(picks, 1);
    });

    testWidgets('the label key stays on the Text when it is tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: '2026-07',
              keyPrefix: 'nw-month',
              onPrevious: () {},
              onNext: () {},
              onPickMonth: () {},
            ),
          ),
        ),
      );

      // Existing call sites read the label's text through this key.
      expect(
        tester.widget<Text>(find.byKey(const Key('nw-month-label'))).data,
        '2026-07',
      );
    });

    testWidgets('the tappable label is announced as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: '2026-07',
              keyPrefix: 'nw-month',
              onPrevious: () {},
              onNext: () {},
              onPickMonth: () {},
            ),
          ),
        ),
      );

      // Same node as the label, matching the diet / menstrual month titles —
      // a bare InkWell is only `tap`, which screen readers don't announce as
      // a button.
      final label = semanticsDataForLabel(tester, '2026-07');
      expect(label, isNotNull);
      expect(label!.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });

  group('pick-month affordance', () {
    testWidgets('the tappable label carries a caret and a tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: '2026-07',
              keyPrefix: 'nw-month',
              onPrevious: () {},
              onNext: () {},
              onPickMonth: () {},
            ),
          ),
        ),
      );

      final entry = find.ancestor(
        of: find.byKey(const Key('nw-month-label')),
        matching: find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == _loc.monthPickerOpenTooltip,
        ),
      );
      expect(entry, findsOneWidget);
      expect(
        find.descendant(
          of: entry,
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a label that opens nothing shows no caret', (tester) async {
      await tester.pumpWidget(
        l10nTestApp(
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

      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('the caret stays smaller than the label it sits beside', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: MonthNavHeader(
              monthLabel: '2026-07',
              keyPrefix: 'nw-month',
              onPrevious: () {},
              onNext: () {},
              onPickMonth: () {},
            ),
          ),
        ),
      );

      // 20 (not the 24 default): the caret is a hint next to the month, and
      // every dp it takes is a dp the label loses on a narrow phone.
      expect(
        tester.widget<Icon>(find.byIcon(Icons.arrow_drop_down)).size,
        20,
      );
    });
  });

  // The `▾` affordance cost the centred row ~48dp, which first overflowed a
  // 320dp phone and then — once the label was allowed to ellipsize — silently
  // ate the month digits (`2026年7月` → `202…`). The label must therefore
  // *scale*, never truncate.
  group('narrow-row month label', () {
    Future<void> pumpAt(WidgetTester tester, double width, String label) =>
        tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: MonthNavHeader(
                    monthLabel: label,
                    keyPrefix: 'nw-month',
                    onPrevious: () {},
                    onNext: () {},
                    onPickMonth: () {},
                  ),
                ),
              ),
            ),
          ),
        );

    // 240dp is what a 320dp phone leaves this row inside the health page's
    // 20dp padding and the card's own; 280dp is the same on a 360dp phone.
    for (final width in [240.0, 280.0, 320.0]) {
      for (final label in ['2026年7月', 'Jul 2026']) {
        testWidgets(
          '"$label" stays whole in a ${width.toInt()}dp row',
          (tester) async {
            await pumpAt(tester, width, label);

            expect(tester.takeException(), isNull);
            expectMonthLabelFullyVisible(tester, const Key('nw-month-label'));
            expect(find.text(label), findsOneWidget);
          },
        );
      }
    }

    testWidgets('it shrinks rather than losing characters when squeezed', (
      tester,
    ) async {
      await pumpAt(tester, 240, '2026年7月');

      expectMonthLabelFullyVisible(tester, const Key('nw-month-label'));
      expect(
        monthLabelScale(tester, const Key('nw-month-label')),
        lessThan(1.0),
      );
    });

    testWidgets('it keeps its full size once there is room', (tester) async {
      await pumpAt(tester, 400, '2026年7月');

      expectMonthLabelFullyVisible(tester, const Key('nw-month-label'));
      expect(monthLabelScale(tester, const Key('nw-month-label')), 1.0);
    });
  });
}
