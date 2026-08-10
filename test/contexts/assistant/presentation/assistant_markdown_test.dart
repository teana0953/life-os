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

    test('reads an indented bullet as a nested level, not another top-level item', () {
      // A category → item breakdown ("醫療" then, indented under it, "掛號")
      // must not flatten to two siblings — the child's amount would read as
      // another top-level category.
      final blocks = parseAssistantMarkdown('* 醫療\n    * 掛號 100');

      expect(blocks[0].level, 0);
      expect(blocks[1].level, 2);
    });

    test('caps nesting at level 3 rather than growing without bound', () {
      final blocks = parseAssistantMarkdown('        * 深到不合理');
      expect(blocks.single.level, 3);
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

    testWidgets('list item layout hugs content, not the width of its container', (tester) async {
      // Without mainAxisSize.min and Flexible, a list item Row stretches to
      // fill the 560px ConstrainedBox, pushing the content to the edge. This
      // catches the bug by measuring the actual Row width against half of a
      // wide surrounding constraint — an invariant, not a number tied to
      // today's content — and ensuring it is far smaller than that.
      const maxWidth = 560.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
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

      // Scoped to AssistantMarkdown's own Row, not the first Row in the tree —
      // future content (nesting, MaterialApp scaffolding) can add other Rows
      // without this silently narrowing to `.first` and losing its target.
      final row = find.descendant(
        of: find.byType(AssistantMarkdown),
        matching: find.byType(Row),
      );
      expect(row, findsOneWidget);

      final rowSize = tester.getSize(row);
      // The content is "• " + "hi". If the Row stretched to the constraint,
      // this would fail. If someone reverts to Expanded, this test turns red.
      expect(rowSize.width, lessThan(maxWidth / 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a nested bullet sits to the right of its parent, not flush with it', (tester) async {
      await pump(tester, '* 醫療\n    * 掛號 100');

      final parentLeft = tester.getTopLeft(find.text('醫療')).dx;
      final childLeft = tester.getTopLeft(find.textContaining('掛號')).dx;

      // A `getTopLeft` comparison, not merely `find.textContaining('掛號')`
      // succeeding — the latter stays green even flattened to the same
      // indent as the parent.
      expect(childLeft, greaterThan(parentLeft));
    });

    testWidgets('a paragraph break after a blank line breathes more than a wrapped line', (tester) async {
      await pump(tester, '第一句\n\n第二句\n第三句');

      final firstTop = tester.getTopLeft(find.text('第一句')).dy;
      final blankGapTop = tester.getTopLeft(find.text('第二句')).dy;
      final noBlankGapTop = tester.getTopLeft(find.text('第三句')).dy;

      final afterBlank = blankGapTop - firstTop;
      final afterNoBlank = noBlankGapTop - blankGapTop;
      // Pins _gapAbove's blankBefore branch: collapsing it to the same value
      // as the non-blank gap must turn this red.
      expect(afterBlank, greaterThan(afterNoBlank));
    });

    testWidgets('the marker is measured with the style Text actually paints, not a narrower default', (tester) async {
      // assistant_screen.dart's real call site passes a style with only
      // `color` set — no fontSize — which Text then merges up to the ambient
      // DefaultTextStyle (here, deliberately much larger than the engine's
      // unstyled default of 14, mirroring the reviewer's repro). Measuring
      // the gutter from the raw, unmerged style under-sizes it, clipping and
      // wrapping the marker.
      // No Scaffold: `Scaffold`'s `Material` inserts its own DefaultTextStyle
      // from the theme (fontSize 14, same as the engine default this bug
      // hides behind), which would mask the very mismatch under test.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 28),
              child: AssistantMarkdown(
                text: '10. 居住',
                style: TextStyle(color: Color(0xFF000000)),
              ),
            ),
          ),
        ),
      );

      // What "10." needs at fontSize 28, measured with nothing constraining it.
      final painter = TextPainter(
        text: const TextSpan(text: '10.', style: TextStyle(fontSize: 28)),
        textDirection: TextDirection.ltr,
      )..layout();
      final needed = painter.width;

      expect(tester.getSize(find.text('10.')).width, greaterThanOrEqualTo(needed));
      // Wrapped onto two lines (as "1" / "0.") is the visible symptom of a
      // too-narrow gutter; asserting merely that the text is *found* would
      // stay green even wrapped.
      expect(find.text('10.'), findsOneWidget);
    });

    testWidgets('the reply reads as one announcement, not one swipe per line with the bullet glyph spoken', (tester) async {
      final handle = tester.ensureSemantics();

      await pump(tester, '總花費 **NT\$ 23,847**\n* 醫療：NT\$ 21,200\n* 其他：NT\$ 1,120');

      // The bullet glyph must not be spoken at all — matched as a substring,
      // not as a whole label. `bySemanticsLabel('•')` compares the entire
      // label, so once the glyph is folded into the merged announcement it
      // matches nothing and stays green with the bullet being read aloud.
      expect(find.bySemanticsLabel(RegExp('•')), findsNothing);
      // The whole reply is reachable as a single node's label.
      expect(
        find.bySemanticsLabel(RegExp(r'總花費.*醫療.*其他', dotAll: true)),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
