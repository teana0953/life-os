import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/widgets/label_value_row.dart';

import '../../support/layout_guard.dart';
import '../../support/month_label.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget value, {
  Widget label = const Text('Label'),
  double width = 300,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: LabelValueRow(label: label, value: value),
      ),
    ),
  ),
);

/// The width [text] wants when nothing is squeezing it.
Future<double> _naturalWidth(WidgetTester tester, String text) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Align(child: Text(text)))),
  );
  return tester.getRect(find.text(text)).width;
}

void main() {
  group('LabelValueRow', () {
    testWidgets('aligns a value that names no textAlign to the row edge', (
      tester,
    ) async {
      // The caller-side footgun this row is built to remove: the value used to
      // sit in a full-width `Expanded` and drew flush left inside it, silently.
      // Measured on the glyphs, not the box, so it would still catch a
      // regression that re-expands the value's slot.
      await _pump(tester, const Text('1,234'));

      final rowRight = tester.getRect(find.byType(LabelValueRow)).right;
      expect(
        paintedTextRight(tester, find.text('1,234')),
        moreOrLessEquals(rowRight, epsilon: 0.5),
      );
    });

    // The priority guard. With the flex on the value instead of the label, a
    // long label took its natural width and the amount got what was left: QA
    // measured a 0–9dp column that broke `NT$1,234,567` one digit per line and
    // grew the row from 64dp to 208dp — at 390dp through 800dp, with no
    // exception to catch it. The label is the half that must yield.
    testWidgets('a long label yields so the value stays whole', (tester) async {
      const value = 'NT\$1,234,567';
      const label = 'Long-term care savings account'; // 30 characters
      final natural = await _naturalWidth(tester, value);

      await _pump(tester, const Text(value), label: const Text(label));

      expect(
        paintedTextLineCount(tester, find.text(value)),
        1,
        reason: 'the value must not be broken across lines',
      );
      expect(
        tester.getRect(find.text(value)).width,
        greaterThanOrEqualTo(natural - 0.5),
        reason: 'the value must keep its natural width, not be squeezed',
      );
      expect(
        paintedTextLineCount(tester, find.text(label)),
        greaterThan(1),
        reason: 'the label is the half that gives way',
      );
    });

    // The other end of that priority, and the regression it produced: with the
    // value allowed the whole row, "the label yields" turned into "the label
    // gets nothing". QA measured this exact row at 320dp/2x — the label's box
    // came back `16.0..16.0`, 0dp wide, and its 27 characters broke one glyph
    // per line into 24 lines that grew the row to 960dp, with no exception to
    // catch it. Both halves are floored now, so both wrap and neither shatters.
    testWidgets('neither half collapses when both are too long for the row', (
      tester,
    ) async {
      useTextScaleFactor(tester, 2.0);
      await tester.binding.setSurfaceSize(const Size(320, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const label = 'Joint emergency fund saving'; // 27 characters
      const value = 'NT\$12,345,678'; // 8 digits

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LabelValueRow(
              gap: 12,
              label: Text(label),
              value: Text(value, textAlign: TextAlign.end),
            ),
          ),
        ),
      );

      final row = tester.getRect(find.byType(LabelValueRow));
      final labelWidth = tester.getRect(find.text(label)).width;
      final valueWidth = tester.getRect(find.text(value)).width;

      // The floors themselves, stated as fractions of the row rather than dp
      // so the numbers survive a font change.
      expect(
        labelWidth,
        greaterThanOrEqualTo(row.width * 0.3),
        reason: 'the label must keep a readable column, not collapse to 0',
      );
      expect(
        valueWidth,
        greaterThanOrEqualTo(row.width * 0.3),
        reason: 'the value must keep a readable column too',
      );
      // What the floors are *for*: a bounded number of lines on both sides.
      expect(
        paintedTextLineCount(tester, find.text(label)),
        lessThanOrEqualTo(10),
        reason: 'the label may wrap, but must not shatter (was 24)',
      );
      expect(
        paintedTextLineCount(tester, find.text(value)),
        lessThanOrEqualTo(3),
        reason: 'the value may wrap, but only a little',
      );
      expect(
        row.height,
        lessThanOrEqualTo(400),
        reason: 'the row must not blow up into a page (was 960dp)',
      );
    });
  });
}
