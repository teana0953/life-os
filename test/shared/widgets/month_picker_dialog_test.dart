import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:life_os/shared/widgets/month_picker_dialog.dart';

import '../../support/l10n_test_app.dart';
import '../../support/semantics_tree.dart';

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
  ThemeData? theme,
}) async {
  DateTime? result;
  var completed = false;
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      theme: theme,
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
        final july = semanticsDataForLabel(tester, julyLabel);
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
        final june = semanticsDataForLabel(tester, juneLabel);
        expect(june, isNotNull);
        expect(june!.flagsCollection.isButton, isTrue);
        expect(june.flagsCollection.isSelected, isFalse);
        handle.dispose();
      },
    );
  });

  group('month cell sizing', () {
    // The uiux leg measured 40dp-tall, wrapping cells under the default
    // dialog/button padding at 320dp — below the 48dp touch minimum. These
    // measure the laid-out render boxes and the real paragraph, so they can
    // only pass when the cells genuinely fit.
    for (final width in [320.0, 360.0, 390.0]) {
      for (final locale in testSupportedLocales) {
        for (final entry in {'default': null, 'app': lightTheme}.entries) {
          testWidgets(
            'cells are >=48dp tall and unwrapped at ${width.toInt()}dp / '
            '${locale.toLanguageTag()} / ${entry.key} theme',
            (tester) async {
              await tester.binding.setSurfaceSize(Size(width, 800));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              await _open(
                tester,
                initialMonth: DateTime(2026, 7),
                locale: locale,
                theme: entry.value,
              );

              for (var month = 1; month <= 12; month++) {
                final cell = find.byKey(Key('month-picker-month-$month'));
                expect(
                  tester.getSize(cell).height,
                  greaterThanOrEqualTo(48.0),
                  reason: 'month $month is below the 48dp touch minimum',
                );
                final paragraph = tester.renderObject<RenderParagraph>(
                  find.descendant(of: cell, matching: find.byType(RichText)),
                );
                // The height one line of this exact span occupies, laid out
                // unconstrained — a laid-out cell taller than that wrapped,
                // whether or not `maxLines` is in place to stop it.
                final oneLine =
                    TextPainter(
                      text: paragraph.text,
                      textDirection: paragraph.textDirection,
                      textScaler: paragraph.textScaler,
                    )..layout();
                expect(
                  paragraph.size.height,
                  lessThanOrEqualTo(oneLine.height + 0.5),
                  reason: 'month $month wrapped onto more than one line',
                );
                expect(
                  paragraph.didExceedMaxLines,
                  isFalse,
                  reason: 'month $month is truncated by maxLines',
                );
              }
            },
          );
        }
      }
    }
  });

  group('year list', () {
    testWidgets('tapping the year label opens a list and picking a year '
        'returns to the months', (tester) async {
      final picker = await _open(tester, initialMonth: DateTime(2026, 7));

      await tester.tap(find.byKey(const Key('month-picker-year-label')));
      await tester.pumpAndSettle();

      // The list replaces the grid — the two are not both live at once.
      expect(find.byKey(const Key('month-picker-year-2024')), findsOneWidget);
      expect(find.byKey(const Key('month-picker-month-1')), findsNothing);

      await tester.tap(find.byKey(const Key('month-picker-year-2024')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('month-picker-year-label')))
            .data,
        '2024',
      );
      expect(find.byKey(const Key('month-picker-month-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('month-picker-month-3')));
      await tester.pumpAndSettle();
      expect(picker.result(), DateTime(2024, 3, 1));
    });

    testWidgets('the list opens near the current year, not at 1970', (
      tester,
    ) async {
      await _open(tester, initialMonth: DateTime(2026, 7));
      await tester.tap(find.byKey(const Key('month-picker-year-label')));
      await tester.pumpAndSettle();

      // Only the years around the current one are built, which is what
      // "scrolled to the current year" means for a lazy list.
      expect(find.byKey(const Key('month-picker-year-2026')), findsOneWidget);
      expect(find.byKey(const Key('month-picker-year-1970')), findsNothing);
      expect(find.byKey(const Key('month-picker-year-2100')), findsNothing);
    });

    testWidgets('a far year is reachable by scrolling the list', (
      tester,
    ) async {
      final picker = await _open(tester, initialMonth: DateTime(2026, 7));
      await tester.tap(find.byKey(const Key('month-picker-year-label')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('month-picker-year-1999')),
        -100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('month-picker-year-1999')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month-picker-month-2')));
      await tester.pumpAndSettle();

      expect(picker.result(), DateTime(1999, 2, 1));
    });

    testWidgets('the list only offers years the bounds can reach', (
      tester,
    ) async {
      await _open(
        tester,
        initialMonth: DateTime(2026, 7),
        firstMonth: DateTime(2025, 4),
        lastMonth: DateTime(2027, 8),
      );
      await tester.tap(find.byKey(const Key('month-picker-year-label')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('month-picker-year-2025')), findsOneWidget);
      expect(find.byKey(const Key('month-picker-year-2027')), findsOneWidget);
      expect(find.byKey(const Key('month-picker-year-2024')), findsNothing);
      expect(find.byKey(const Key('month-picker-year-2028')), findsNothing);
    });
  });

  group('out-of-bounds initialMonth', () {
    testWidgets('an initialMonth before firstMonth is clamped in, not a dead '
        'end', (tester) async {
      final picker = await _open(
        tester,
        initialMonth: DateTime(2020, 5),
        firstMonth: DateTime(2026, 3),
        lastMonth: DateTime(2026, 12),
      );

      expect(
        tester
            .widget<Text>(find.byKey(const Key('month-picker-year-label')))
            .data,
        '2026',
      );
      expect(_monthEnabled(tester, 3), isTrue);
      expect(_monthSelected(tester, 3), isTrue);

      await tester.tap(find.byKey(const Key('month-picker-month-4')));
      await tester.pumpAndSettle();
      expect(picker.result(), DateTime(2026, 4, 1));
    });

    testWidgets('an initialMonth after lastMonth is clamped in', (
      tester,
    ) async {
      await _open(
        tester,
        initialMonth: DateTime(2030, 5),
        firstMonth: DateTime(2024, 1),
        lastMonth: DateTime(2026, 9),
      );

      expect(
        tester
            .widget<Text>(find.byKey(const Key('month-picker-year-label')))
            .data,
        '2026',
      );
      expect(_monthEnabled(tester, 9), isTrue);
      expect(_monthSelected(tester, 9), isTrue);
    });
  });

  group('affordance', () {
    testWidgets('the year label shows a drop-down caret and a tooltip', (
      tester,
    ) async {
      await _open(tester, initialMonth: DateTime(2026, 7));

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('month-picker-year-label')),
          matching: find.byWidgetPredicate(
            (w) => w is Tooltip && w.message == _loc.monthPickerYearTooltip,
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
