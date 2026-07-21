import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/presentation/amount_stepper.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

void main() {
  Widget harness({
    required double value,
    required ValueChanged<double> onChanged,
    String unitLabel = '碗',
    bool allowMeasure = false,
    bool measureMode = false,
    String? measureLabel,
    ValueChanged<bool>? onModeChanged,
    Locale locale = const Locale('en'),
  }) {
    return l10nTestApp(
      locale: locale,
      home: Scaffold(
        body: AmountStepper(
          value: value,
          onChanged: onChanged,
          unitLabel: unitLabel,
          allowMeasure: allowMeasure,
          measureMode: measureMode,
          measureLabel: measureLabel,
          onModeChanged: onModeChanged,
        ),
      ),
    );
  }

  testWidgets('tapping + increments by step, tapping - decrements', (
    tester,
  ) async {
    double value = 1;
    await tester.pumpWidget(
      harness(value: value, onChanged: (v) => value = v),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(value, 2);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    // The widget doesn't rebuild itself with the new value (state lives in
    // the caller) so this just re-applies the decrement to the same pumped
    // value.
    expect(value, 0);
  });

  testWidgets('- clamps at 0, never goes negative', (tester) async {
    double? reported;
    await tester.pumpWidget(
      harness(value: 0, onChanged: (v) => reported = v),
    );

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    expect(reported, 0);
  });

  testWidgets('typing in the field reports the parsed value', (tester) async {
    double? reported;
    await tester.pumpWidget(
      harness(value: 1, onChanged: (v) => reported = v),
    );

    await tester.enterText(find.byType(TextField), '2.5');
    await tester.pump();

    expect(reported, 2.5);
  });

  testWidgets('a value of 0 shows an empty field with a "0" hint (empty-zero convention)', (
    tester,
  ) async {
    await tester.pumpWidget(harness(value: 0, onChanged: (_) {}));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '');
    expect(field.decoration?.hintText, '0');
  });

  testWidgets('a non-zero value shows its formatted text in the field', (
    tester,
  ) async {
    await tester.pumpWidget(harness(value: 1.5, onChanged: (_) {}));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '1.5');
  });

  testWidgets('the portion/measure toggle is hidden when allowMeasure is false', (
    tester,
  ) async {
    await tester.pumpWidget(harness(value: 1, onChanged: (_) {}));

    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('a g food\'s measure segment reads 公克, and toggling reports mode changes', (
    tester,
  ) async {
    bool? reportedMode;
    final loc = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      harness(
        value: 1,
        onChanged: (_) {},
        allowMeasure: true,
        measureMode: false,
        measureLabel: loc.dietGramsLabel,
        onModeChanged: (v) => reportedMode = v,
      ),
    );

    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.text(loc.dietGramsLabel), findsOneWidget);

    await tester.tap(find.text(loc.dietGramsLabel));
    await tester.pump();

    expect(reportedMode, isTrue);
  });

  testWidgets('a ml food\'s measure segment reads 毫升, not a bare "ml"', (
    tester,
  ) async {
    final loc = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      harness(
        value: 1,
        onChanged: (_) {},
        allowMeasure: true,
        measureMode: false,
        measureLabel: loc.dietMeasureUnitMl,
      ),
    );

    expect(find.text(loc.dietMeasureUnitMl), findsOneWidget);
    expect(find.text('ml'), findsNothing);
  });

  testWidgets('portion mode always shows the caller\'s unitLabel, never g/ml', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        value: 1,
        onChanged: (_) {},
        allowMeasure: true,
        measureMode: false,
        measureLabel: '公克',
      ),
    );

    expect(find.text('碗'), findsOneWidget);
  });

  testWidgets('measure mode labels the field with the measure unit, not the portion word', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        value: 18,
        onChanged: (_) {},
        allowMeasure: true,
        measureMode: true,
        measureLabel: '顆',
      ),
    );

    // In measure mode the after-field unit follows the mode (顆), so the user
    // reads "18 顆" — never the portion word 碗, which would contradict the
    // highlighted 顆 segment.
    expect(find.text('碗'), findsNothing);
    expect(find.text('顆'), findsWidgets); // both the segment and the after-field label
  });

  testWidgets(
    'the mode toggle keeps its own line below the trio in BOTH modes (mode-stable layout)',
    (tester) async {
      // A wide surface where the old Wrap put every child on one line: the
      // assertion below only holds once the SegmentedButton is on a fixed line
      // of its own, so this is a real geometric stability check, not one an
      // on-one-line layout could pass. The same relationship must hold in both
      // modes — that invariance IS the stability this change guarantees.
      final loc = lookupAppLocalizations(const Locale('en'));

      // Portion mode: after-field label is the caller's unitLabel (碗).
      await tester.pumpWidget(
        harness(
          value: 1,
          onChanged: (_) {},
          allowMeasure: true,
          measureMode: false,
          measureLabel: loc.dietGramsLabel,
        ),
      );
      expect(
        tester.getTopLeft(find.byType(SegmentedButton<bool>)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextField)).dy),
      );
      expect(find.text('碗'), findsOneWidget);

      // Measure mode: same line relationship (segment still below the trio),
      // only the after-field label changes to the measure label.
      await tester.pumpWidget(
        harness(
          value: 1,
          onChanged: (_) {},
          allowMeasure: true,
          measureMode: true,
          measureLabel: loc.dietGramsLabel,
        ),
      );
      expect(
        tester.getTopLeft(find.byType(SegmentedButton<bool>)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextField)).dy),
      );
      expect(find.text('碗'), findsNothing);
      expect(find.text(loc.dietGramsLabel), findsWidgets);
    },
  );

  // No overflow at narrow widths in both locales. The passed unit/measure
  // labels stay at their worst-case English width ("portion(s)"/"Grams") even
  // in the zh-Hant cell: the after-field label is the row-1 element most at
  // risk of overflow, so holding it at worst case keeps zh-Hant from being a
  // strictly-easier width, while the locale still switches the segment's
  // 份量/Quantity label (exercising CJK glyph metrics).
  for (final width in [320.0, 360.0]) {
    for (final locale in testSupportedLocales) {
      for (final measureMode in [false, true]) {
        testWidgets(
          'a gram amount control does not overflow at ${width.toInt()}dp, '
          'locale=$locale, measureMode=$measureMode',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await tester.pumpWidget(
              harness(
                value: 18,
                onChanged: (_) {},
                unitLabel: 'portion(s)',
                allowMeasure: true,
                measureMode: measureMode,
                measureLabel: 'Grams',
                locale: locale,
              ),
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('measureLabelFor maps g to Grams and ml to Milliliters, null otherwise', (
    tester,
  ) async {
    final loc = lookupAppLocalizations(const Locale('en'));

    expect(measureLabelFor('g', loc), loc.dietGramsLabel);
    expect(measureLabelFor('ml', loc), loc.dietMeasureUnitMl);
    expect(measureLabelFor(null, loc), isNull);
  });

  testWidgets('measureLabelFor returns a household unit word verbatim, and treats empty as null', (
    tester,
  ) async {
    final loc = lookupAppLocalizations(const Locale('en'));

    expect(measureLabelFor('顆', loc), '顆');
    expect(measureLabelFor('碗', loc), '碗');
    expect(measureLabelFor('', loc), isNull);
  });
}
