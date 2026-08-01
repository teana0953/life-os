import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/month_picker_dialog.dart';

import '../../support/l10n_test_app.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

/// Opens the picker from a button and returns getters for what it eventually
/// returned — including `null` for a dismissal, which is only distinguishable
/// from "still open" via [completed].
Future<({DateTime? Function() result, bool Function() completed})> _open(
  WidgetTester tester, {
  required DateTime initialMonth,
  DateTime? firstMonth,
  DateTime? lastMonth,
  Locale locale = const Locale('en'),
}) async {
  DateTime? result;
  var completed = false;
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const Key('open-picker'),
            onPressed: () async {
              result = await showMonthPicker(
                context,
                initialMonth: initialMonth,
                firstMonth: firstMonth,
                lastMonth: lastMonth,
              );
              completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-picker')));
  await tester.pumpAndSettle();
  return (result: () => result, completed: () => completed);
}

bool _monthEnabled(WidgetTester tester, int month) =>
    tester
        .widget<ButtonStyleButton>(
          find.descendant(
            of: find.byKey(Key('month-picker-month-$month')),
            // `byType` is exact, and the cells are `FilledButton`/
            // `OutlinedButton` subclasses.
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        )
        .onPressed !=
    null;

bool _yearArrowEnabled(WidgetTester tester, String which) =>
    tester
        .widget<IconButton>(find.byKey(Key('month-picker-year-$which')))
        .onPressed !=
    null;

// `getSemanticsData()`, not the node's own `flagsCollection`: the cell merges
// its `selected` annotation into the button's node, and only the merged data
// is what reaches the platform.
bool _monthSelected(WidgetTester tester, int month) => tester
    .getSemantics(find.byKey(Key('month-picker-month-$month')))
    .getSemanticsData()
    .flagsCollection
    .isSelected;

void main() {
  group('showMonthPicker', () {
    testWidgets(
      'stepping the year back twice and tapping March returns 2024-03-01',
      (tester) async {
        final picker = await _open(tester, initialMonth: DateTime(2026, 7));

        await tester.tap(find.byKey(const Key('month-picker-year-previous')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('month-picker-year-previous')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const Key('month-picker-year-label')))
              .data,
          '2024',
        );

        await tester.tap(find.byKey(const Key('month-picker-month-3')));
        await tester.pumpAndSettle();

        expect(picker.result(), DateTime(2024, 3, 1));
      },
    );

    testWidgets('stepping the year forward moves the label', (tester) async {
      await _open(tester, initialMonth: DateTime(2026, 7));

      await tester.tap(find.byKey(const Key('month-picker-year-next')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('month-picker-year-label')))
            .data,
        '2027',
      );
    });

    testWidgets('dismissing returns null', (tester) async {
      final picker = await _open(tester, initialMonth: DateTime(2026, 7));

      // Tap the barrier outside the dialog.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(picker.completed(), isTrue);
      expect(picker.result(), isNull);
    });

    testWidgets(
      'months after lastMonth and the forward year arrow are disabled',
      (tester) async {
        await _open(
          tester,
          initialMonth: DateTime(2026, 7),
          lastMonth: DateTime(2026, 7),
        );

        expect(_monthEnabled(tester, 7), isTrue);
        expect(_monthEnabled(tester, 8), isFalse);
        expect(_monthEnabled(tester, 12), isFalse);
        expect(_yearArrowEnabled(tester, 'next'), isFalse);
        expect(_yearArrowEnabled(tester, 'previous'), isTrue);
      },
    );

    testWidgets(
      'months before firstMonth and the back year arrow are disabled',
      (tester) async {
        await _open(
          tester,
          initialMonth: DateTime(2026, 7),
          firstMonth: DateTime(2026, 3),
        );

        expect(_monthEnabled(tester, 2), isFalse);
        expect(_monthEnabled(tester, 3), isTrue);
        expect(_yearArrowEnabled(tester, 'previous'), isFalse);
        expect(_yearArrowEnabled(tester, 'next'), isTrue);
      },
    );

    testWidgets('a disabled month does nothing when tapped', (tester) async {
      final picker = await _open(
        tester,
        initialMonth: DateTime(2026, 7),
        lastMonth: DateTime(2026, 7),
      );

      await tester.tap(
        find.byKey(const Key('month-picker-month-8')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(picker.completed(), isFalse);
      expect(picker.result(), isNull);
    });

    testWidgets('the viewed month is marked selected, not by color alone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(tester, initialMonth: DateTime(2026, 7));

      expect(_monthSelected(tester, 7), isTrue);
      expect(_monthSelected(tester, 6), isFalse);
      handle.dispose();
    });

    testWidgets('the selected mark follows the year, not just the month', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(tester, initialMonth: DateTime(2026, 7));

      await tester.tap(find.byKey(const Key('month-picker-year-previous')));
      await tester.pumpAndSettle();

      expect(_monthSelected(tester, 7), isFalse);
      handle.dispose();
    });

    testWidgets('the built-in 1970 sanity bound stops year stepping back', (
      tester,
    ) async {
      await _open(tester, initialMonth: DateTime(1970, 5));

      expect(_yearArrowEnabled(tester, 'previous'), isFalse);
      expect(_yearArrowEnabled(tester, 'next'), isTrue);
    });

    testWidgets('the built-in 2100 sanity bound stops year stepping forward', (
      tester,
    ) async {
      await _open(tester, initialMonth: DateTime(2100, 5));

      expect(_yearArrowEnabled(tester, 'next'), isFalse);
      expect(_yearArrowEnabled(tester, 'previous'), isTrue);
    });

    testWidgets(
      'title and year arrows are localized; months use short intl names',
      (tester) async {
        await _open(tester, initialMonth: DateTime(2026, 7));

        expect(find.text(_loc.monthPickerTitle), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('month-picker-year-previous')),
              )
              .tooltip,
          _loc.monthPickerPreviousYearTooltip,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('month-picker-year-next')),
              )
              .tooltip,
          _loc.monthPickerNextYearTooltip,
        );
        expect(
          find.text(DateFormat.MMM('en').format(DateTime(2026, 3))),
          findsOneWidget,
        );
      },
    );

    testWidgets('Chinese months use the short form (3月, not 三月)', (
      tester,
    ) async {
      await _open(
        tester,
        initialMonth: DateTime(2026, 7),
        locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );

      expect(find.text('3月'), findsOneWidget);
      expect(find.text('三月'), findsNothing);
    });
  });

  group('month cell semantics', () {
    testWidgets(
      'the selected month is one node carrying label + button + selected',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _open(tester, initialMonth: DateTime(2026, 7));

        final julyLabel = DateFormat.MMM('en').format(DateTime(2026, 7));
        final july = _dataForLabel(tester, julyLabel);
        expect(
          july,
          isNotNull,
          reason: 'no semantics node in the live tree is labelled $julyLabel',
        );
        // All three on the *same* node: a screen reader reads one node, so
        // "selected" on a separate, unlabelled parent is never announced.
        expect(july!.flagsCollection.isButton, isTrue);
        expect(july.flagsCollection.isSelected, isTrue);

        final juneLabel = DateFormat.MMM('en').format(DateTime(2026, 6));
        final june = _dataForLabel(tester, juneLabel);
        expect(june, isNotNull);
        expect(june!.flagsCollection.isButton, isTrue);
        expect(june.flagsCollection.isSelected, isFalse);
        handle.dispose();
      },
    );
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
