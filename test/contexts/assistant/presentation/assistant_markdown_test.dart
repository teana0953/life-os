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

    test('treats a run of three stars as literal, not a partial bold match', () {
      // A `**` matched out of the middle of `***` would bold `*重要` and leave
      // a stray `*` on screen — half swallowed, half leaked, violating the
      // "never swallowed" contract for syntax this parser doesn't know. An
      // odd-length run can never split into whole `**` pairs.
      expect(parseInlineMarkdown('***重要***的一筆'), const [MdSpan('***重要***的一筆')]);
    });

    test('still bolds a normal pair next to an unrelated run of three stars', () {
      expect(
        parseInlineMarkdown('**重要**的事，***不是***這個'),
        const [
          MdSpan('重要', bold: true),
          MdSpan('的事，***不是***這個'),
        ],
      );
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

    test('expands a tab to two spaces of indent instead of counting as zero', () {
      final blocks = parseAssistantMarkdown('* 醫療\n\t* 掛號 100');
      expect(blocks[0].level, 0);
      expect(blocks[1].level, 1);
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

      // The box the marker is painted into must leave a gap before the body
      // text, not sit flush against it. `getSize` on the marker `Text` can't
      // tell them apart here — the SizedBox hands it a tight width
      // constraint, so it reports the box's own width back regardless of
      // glyph content. Measure the glyphs directly instead, with the exact
      // style the Text widget was actually given (so this can't drift from
      // whatever `effectiveStyle` production code merges to) — removing the
      // gutter's `+ 6px` gap makes the box exactly as wide as the glyphs,
      // which stays green against `greaterThanOrEqualTo` above but fails
      // this strict `>`.
      final markerStyle = tester.widget<Text>(find.text('10.')).style;
      final glyphs = TextPainter(
        text: TextSpan(text: '10.', style: markerStyle),
        textScaler: const TextScaler.linear(2.0),
        textDirection: TextDirection.ltr,
      )..layout();
      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(of: find.text('10.'), matching: find.byType(SizedBox)).first,
      );
      expect(sizedBox.width, greaterThan(glyphs.width));
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

    testWidgets('a nested numbered item sits to the right of its parent, not flush with it', (tester) async {
      // The bullet path has the guard above; the numbered path shares the
      // same `level` field but had no widget-level guard of its own.
      await pump(tester, '1. 醫療\n    1. 掛號 100');

      final parentLeft = tester.getTopLeft(find.text('醫療')).dx;
      final childLeft = tester.getTopLeft(find.textContaining('掛號')).dx;

      expect(childLeft, greaterThan(parentLeft));
    });

    testWidgets('a deep nested item does not overflow a narrow bubble at a large text scale', (tester) async {
      // The narrow-bubble regression this fix is for: a fixed-px indent per
      // level, uncapped against the incoming width, pushes a level-3 item's
      // fixed-width Row parts (gutter + indent) past the bubble's own width
      // at large text scales — measured before this fix: a `RenderFlex
      // overflowed` exception at scale 3.0 in a 260-wide bubble.
      const maxWidth = 260.0;
      // Tall enough that the (irrelevant to this test) vertical extent of a
      // wrapped multi-block reply at scale 3.0 never overflows — only the
      // horizontal Row overflow this test targets should be able to fail it.
      tester.view.physicalSize = const Size(320, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: AssistantMarkdown(
                  text: '* 醫療\n      10. 掛號費用一百元這一段故意寫得很長很長很長很長很長',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Not just "no exception" — a squeezed-to-zero body is the silent
      // failure mode this fix is also for (no error thrown, text just
      // disappears). The nested line must still have real width to read.
      final nested = tester.getSize(find.textContaining('掛號費用', findRichText: true));
      expect(nested.width, greaterThan(10));
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

      // Bold text, a numbered step and a nested bullet all in one fixture:
      // each is a distinct way the merged announcement can silently lose
      // content that the visible bubble still shows correctly.
      await pump(
        tester,
        '請先**確認金額**：\n1. 開啟設定\n2. 貼上金鑰\n* 醫療：NT\$ 21,200\n  * 掛號 100',
      );

      // The bullet glyph must not be spoken at all — matched as a substring,
      // not as a whole label. `bySemanticsLabel('•')` compares the entire
      // label, so once the glyph is folded into the merged announcement it
      // matches nothing and stays green with the bullet being read aloud.
      expect(find.bySemanticsLabel(RegExp('•')), findsNothing);

      final semanticsWidget = tester.widget<Semantics>(
        find.descendant(of: find.byType(AssistantMarkdown), matching: find.byType(Semantics)),
      );
      // One label, in reading order, that: keeps bold text (a mutant that
      // drops bold spans from the label — e.g. `s.bold ? '' : s.text` — would
      // silently lose "確認金額" here, undetectable since ExcludeSemantics
      // makes this label the only thing assistive tech can read); keeps the
      // numbered markers "1." / "2." (a mutant that empties the marker
      // string would drop the step numbers while every other assertion
      // above stays green); and prefixes the nested item so "掛號 100"
      // doesn't read as another top-level line beside "醫療".
      expect(
        semanticsWidget.properties.label,
        '請先確認金額：\n1. 開啟設定\n2. 貼上金鑰\n醫療：NT\$ 21,200\n－ 掛號 100',
      );
      handle.dispose();
    });
  });
}
