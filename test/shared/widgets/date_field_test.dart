import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/widgets/date_field.dart';

import '../../support/l10n_test_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  required DateTime? value,
  required VoidCallback? onTap,
}) => tester.pumpWidget(
  l10nTestApp(
    home: Scaffold(
      body: DateField(
        fieldKey: const Key('start-field'),
        label: 'Start',
        value: value,
        placeholder: 'Pick a date',
        onTap: onTap,
      ),
    ),
  ),
);

void main() {
  group('DateField', () {
    testWidgets('shows the placeholder under the caller key when unset', (
      tester,
    ) async {
      await _pump(tester, value: null, onTap: () {});

      expect(find.byKey(const Key('start-field')), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Pick a date'), findsOneWidget);
    });

    testWidgets('shows the formatted value when set', (tester) async {
      final date = DateTime(2026, 7, 19);
      await _pump(tester, value: date, onTap: () {});

      final context = tester.element(find.byType(DateField));
      expect(find.text(mediumDateLabel(context, date)), findsOneWidget);
      expect(find.text('Pick a date'), findsNothing);
    });

    testWidgets('the date text hugs the left edge of the field', (
      tester,
    ) async {
      await _pump(tester, value: null, onTap: () {});

      // Without the centerLeft Align the text would sit in the middle of the
      // full-width button instead of at its leading edge.
      final field = tester.getRect(find.byKey(const Key('start-field')));
      final text = tester.getRect(find.text('Pick a date'));
      expect(text.left - field.left, lessThan(field.width / 4));
      expect(text.center.dx, lessThan(field.center.dx));
    });

    testWidgets('tapping the field invokes onTap', (tester) async {
      var taps = 0;
      await _pump(tester, value: null, onTap: () => taps++);

      await tester.tap(find.byKey(const Key('start-field')));
      expect(taps, 1);
    });

    testWidgets('a null onTap disables the control', (tester) async {
      await _pump(tester, value: null, onTap: null);

      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('start-field')),
      );
      expect(button.onPressed, isNull);
    });
  });
}
