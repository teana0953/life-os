import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/month_nav_header.dart';

import '../../support/l10n_test_app.dart';

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
      final label = _dataForLabel(tester, '2026-07');
      expect(label, isNotNull);
      expect(label!.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });
}

/// The semantics data of the live-tree node whose merged label is [label].
///
/// Walks the real `SemanticsOwner` tree rather than reading a widget's cached
/// node, so it can only pass when the node actually reaching the platform
/// carries the flags.
SemanticsData? _dataForLabel(WidgetTester tester, String label) {
  var root = tester.getSemantics(find.byType(MaterialApp));
  while (root.parent != null) {
    root = root.parent!;
  }
  SemanticsData? found;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    // Nodes merged into an ancestor never reach the platform on their own —
    // only the surviving node is what a screen reader reads.
    if (!node.isMergedIntoParent && data.label == label) found ??= data;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return found;
}
