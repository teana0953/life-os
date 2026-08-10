import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_markdown.dart';

/// Every string the model actually put on screen in issue #152, plus the
/// shapes that decide whether a parser silently eats characters.
void main() {
  group('inline bold', () {
    test('splits a line into plain and bold runs', () {
      expect(
        parseInlineMarkdown('您本月的總花費為 **NT\$ 23,847**。'),
        const [
          MdSpan('您本月的總花費為 '),
          MdSpan('NT\$ 23,847', bold: true),
          MdSpan('。'),
        ],
      );
    });

    test('keeps an opener with no closer as literal text', () {
      // A reply cut off mid-sentence (or a model that emits one stray pair)
      // must not lose the rest of the line to an unterminated bold run.
      expect(parseInlineMarkdown('總計 **NT\$ 100'), const [MdSpan('總計 **NT\$ 100')]);
    });

    test('leaves a lone star alone', () {
      expect(parseInlineMarkdown('2 * 3 = 6'), const [MdSpan('2 * 3 = 6')]);
    });

    test('handles two bold runs on one line', () {
      expect(
        parseInlineMarkdown('**醫療**：**NT\$ 21,200**'),
        const [
          MdSpan('醫療', bold: true),
          MdSpan('：'),
          MdSpan('NT\$ 21,200', bold: true),
        ],
      );
    });

    test('gives an empty line one empty span rather than none', () {
      // A block with no spans would render as a zero-height row and the reply
      // would look like it skipped a line.
      expect(parseInlineMarkdown('****'), const [MdSpan('')]);
    });
  });

  group('blocks', () {
    test('reads the reply from the issue as a paragraph and four bullets', () {
      final blocks = parseAssistantMarkdown(
        '您本月的總花費為 **NT\$ 23,847**。\n'
        '\n'
        '**各類別花費明細如下：**\n'
        '* **醫療**：NT\$ 21,200\n'
        '- **其他**：NT\$ 1,120\n',
      );

      expect(blocks.map((b) => b.kind).toList(), const [
        MdBlockKind.paragraph,
        MdBlockKind.paragraph,
        MdBlockKind.bullet,
        MdBlockKind.bullet,
      ]);
      // Both `*` and `-` are bullets; the marker is the app's, not the
      // source's, so the two spellings look the same on screen.
      expect(blocks[2].marker, '•');
      expect(blocks[3].marker, '•');
      expect(blocks[2].spans.first, const MdSpan('醫療', bold: true));
      // Only the line after the blank line is spaced wider.
      expect(blocks[1].blankBefore, isTrue);
      expect(blocks[2].blankBefore, isFalse);
    });

    test('keeps a numbered list numbered from the source, not renumbered', () {
      final blocks = parseAssistantMarkdown('3. 第三步\n4) 第四步');

      expect(blocks.map((b) => b.marker).toList(), ['3.', '4.']);
      expect(blocks.every((b) => b.kind == MdBlockKind.numbered), isTrue);
    });

    test('does not treat a date or an amount as a list', () {
      // `2026.` never starts a line here, but `1,120` and `8/10` must not be
      // mistaken for markers either — the marker needs a digit, a dot and a
      // space, in that order.
      final blocks = parseAssistantMarkdown('8/10 花了 1,120 元');

      expect(blocks.single.kind, MdBlockKind.paragraph);
      expect(blocks.single.spans, const [MdSpan('8/10 花了 1,120 元')]);
    });

    test('drops blank lines instead of turning them into empty rows', () {
      final blocks = parseAssistantMarkdown('\n\n第一句\n\n\n第二句\n\n');

      expect(blocks.length, 2);
      // A leading blank must not push the first line down — the bubble's
      // padding is the gap above it.
      expect(blocks.first.blankBefore, isFalse);
      expect(blocks.last.blankBefore, isTrue);
    });

    test('leaves syntax it does not know as literal text', () {
      // The deliberate limit: an unsupported mark is shown, never swallowed.
      final blocks = parseAssistantMarkdown('## 標題\n| a | b |\n`code`');

      expect(blocks.map((b) => b.spans.single.text).toList(), const [
        '## 標題',
        '| a | b |',
        '`code`',
      ]);
    });
  });

  group('the widget', () {
    Future<void> pump(WidgetTester tester, String text, {double textScale = 1.0}) {
      return tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: AssistantMarkdown(
                text: text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the bold text without its stars', (tester) async {
      await pump(tester, '總花費為 **NT\$ 23,847**。');

      // The whole point of the issue: the marks must not reach the screen.
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('NT\$ 23,847', findRichText: true), findsOneWidget);
    });

    testWidgets('renders the bold run in a heavier weight than the rest', (tester) async {
      await pump(tester, '總計 **1,120** 元');

      final rich = tester.widget<Text>(find.byType(Text).first);
      final children = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
      final bold = children.firstWhere((s) => s.text == '1,120');
      final plain = children.firstWhere((s) => s.text == '總計 ');
      expect(bold.style!.fontWeight, FontWeight.w700);
      // Not just "bold is heavy" — the neighbours must stay light, or a
      // renderer that bolds everything passes the assertion above.
      expect(plain.style!.fontWeight, isNot(FontWeight.w700));
    });

    testWidgets('shows a bullet marker instead of the source star', (tester) async {
      await pump(tester, '* 醫療：NT\$ 21,200');

      expect(find.text('•'), findsOneWidget);
      expect(find.textContaining('* 醫療', findRichText: true), findsNothing);
    });

    testWidgets('gives the marker room to grow with the text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // What "10." needs at 200%, measured with nothing constraining it.
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: const Align(
              alignment: Alignment.topLeft,
              child: Text('10.', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
      );
      final needed = tester.getSize(find.text('10.')).width;

      await pump(
        tester,
        '10. **居住**：NT\$ 515,000 這一列長到需要換行才能放進去',
        textScale: 2.0,
      );

      // A gutter fixed in logical pixels clips the number here — the box the
      // marker is painted into must be at least as wide as the glyphs. This
      // comparison is the guard: asserting the marker is merely *found* stays
      // green while it is clipped.
      expect(tester.getSize(find.text('10.')).width, greaterThanOrEqualTo(needed));
      expect(tester.takeException(), isNull);
    });

    testWidgets('list item layout hugs content with mainAxisSize.min and Flexible, not stretching to container width', (tester) async {
      // Regression test for the fix in commit 87536c5: without mainAxisSize.min
      // and Flexible, a list item Row stretched to fill the 560px ConstrainedBox,
      // pushing the content to the edge. This test catches the bug by measuring
      // the actual Row width and ensuring it is far smaller than the constraint.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  color: const Color(0xFFFFFFFF),
                  padding: const EdgeInsets.all(12),
                  child: AssistantMarkdown(
                    text: '* hi',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Find the Row (the _blockRow for the list item).
      final row = find.byType(Row);
      expect(row, findsOneWidget);

      final rowSize = tester.getSize(row);
      // The content is "• " + "hi", which should be well under 100px even at
      // the default scale. If the Row stretched to the 560px constraint, this
      // would fail. If someone reverts to Expanded, this test turns red.
      expect(rowSize.width, lessThan(100));
      expect(tester.takeException(), isNull);
    });
  });
}
