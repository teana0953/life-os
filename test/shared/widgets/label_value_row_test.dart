import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/widgets/label_value_row.dart';

import '../../support/layout_guard.dart';

Future<void> _pump(WidgetTester tester, Widget value) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: LabelValueRow(label: const Text('Label'), value: value),
      ),
    ),
  ),
);

void main() {
  group('LabelValueRow', () {
    testWidgets('aligns a value that names no textAlign to the row edge', (
      tester,
    ) async {
      // The caller-side footgun this row is built to remove: a bare `Text`
      // inside the `Expanded` used to draw flush left in a full-width slot,
      // silently. Measured on the glyphs, not the box — the box spans the row
      // either way (see paintedTextRight).
      await _pump(tester, const Text('1,234'));

      final rowRight = tester.getRect(find.byType(LabelValueRow)).right;
      expect(
        paintedTextRight(tester, find.text('1,234')),
        moreOrLessEquals(rowRight, epsilon: 0.5),
      );
    });

    testWidgets('a value that names its own textAlign still wins', (
      tester,
    ) async {
      await _pump(
        tester,
        const Text('1,234', textAlign: TextAlign.start),
      );

      final rowRight = tester.getRect(find.byType(LabelValueRow)).right;
      expect(
        paintedTextRight(tester, find.text('1,234')),
        lessThan(rowRight - 10),
      );
    });
  });
}
