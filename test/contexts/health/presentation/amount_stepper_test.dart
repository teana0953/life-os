import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/presentation/amount_stepper.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

void main() {
  Widget harness({
    required double value,
    required ValueChanged<double> onChanged,
    bool allowGrams = false,
    bool grams = false,
    ValueChanged<bool>? onModeChanged,
  }) {
    return l10nTestApp(
      home: Scaffold(
        body: AmountStepper(
          value: value,
          onChanged: onChanged,
          unitLabel: '碗',
          allowGrams: allowGrams,
          grams: grams,
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

  testWidgets('the portion/gram toggle is hidden when allowGrams is false', (
    tester,
  ) async {
    await tester.pumpWidget(harness(value: 1, onChanged: (_) {}));

    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('the portion/gram toggle appears when allowGrams is true, and reports mode changes', (
    tester,
  ) async {
    bool? reportedMode;
    await tester.pumpWidget(
      harness(
        value: 1,
        onChanged: (_) {},
        allowGrams: true,
        grams: false,
        onModeChanged: (v) => reportedMode = v,
      ),
    );

    expect(find.byType(SegmentedButton<bool>), findsOneWidget);

    final loc = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(loc.dietGramsLabel));
    await tester.pump();

    expect(reportedMode, isTrue);
  });
}
