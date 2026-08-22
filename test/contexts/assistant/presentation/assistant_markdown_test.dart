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
      // `## 標題` used to be listed here; headings became supported on purpose
      // (openspec change assistant-markdown-headings), so this test now names
      // marks that are still genuinely unsupported. Deleting it instead would
      // erase the record that the behaviour changed deliberately.
      final blocks = parseAssistantMarkdown('| a | b |\n`code`\n##### 太深');

      expect(blocks.map((b) => b.spans.single.text).toList(), const [
        '| a | b |',
        '`code`',
        '##### 太深',
      ]);
    });
  });

  group('headings and thematic breaks', () {
    test('reads a third-level heading, hashes removed', () {
      final blocks = parseAssistantMarkdown('### 本月支出');

      expect(blocks.single.kind, MdBlockKind.heading);
      expect(blocks.single.headingLevel, 3);
      expect(blocks.single.spans, const [MdSpan('本月支出')]);
      // The list-nesting field must stay untouched, or the layout indents the
      // heading by its own level (design D1).
      expect(blocks.single.level, 0);
      expect(blocks.single.marker, isNull);
    });

    test('recognises every supported level', () {
      final blocks = parseAssistantMarkdown('# 一\n## 二\n### 三\n#### 四');

      expect(blocks.map((b) => b.headingLevel).toList(), [1, 2, 3, 4]);
      expect(blocks.every((b) => b.kind == MdBlockKind.heading), isTrue);
    });

    test('runs a heading through the inline pass', () {
      final blocks = parseAssistantMarkdown('### 本月**總計**');

      expect(blocks.single.spans, const [
        MdSpan('本月'),
        MdSpan('總計', bold: true),
      ]);
    });

    test('leaves a fifth-level heading literal', () {
      // `#{1,4}` consumes four hashes, then demands whitespace and finds a
      // fifth `#` — the line falls through to paragraph with no extra guard.
      final blocks = parseAssistantMarkdown('##### 太深');

      expect(blocks.single.kind, MdBlockKind.paragraph);
      expect(blocks.single.spans, const [MdSpan('##### 太深')]);
    });

    test('leaves a hash with no space literal', () {
      final blocks = parseAssistantMarkdown('#tag');

      expect(blocks.single.kind, MdBlockKind.paragraph);
      expect(blocks.single.spans, const [MdSpan('#tag')]);
    });

    test('leaves a hash run with no words literal', () {
      final blocks = parseAssistantMarkdown('###');

      expect(blocks.single.kind, MdBlockKind.paragraph);
      expect(blocks.single.spans, const [MdSpan('###')]);
    });

    test('reads three dashes as a thematic break carrying no text', () {
      final blocks = parseAssistantMarkdown('第一段\n---\n第二段');

      expect(blocks.map((b) => b.kind).toList(), const [
        MdBlockKind.paragraph,
        MdBlockKind.thematicBreak,
        MdBlockKind.paragraph,
      ]);
      expect(blocks[1].spans, isEmpty);
      expect(blocks[1].marker, isNull);
    });

    test('reads a longer dash run as one break, not several', () {
      final blocks = parseAssistantMarkdown('-----');

      expect(blocks.single.kind, MdBlockKind.thematicBreak);
    });

    test('leaves a dash run shorter than three as literal text', () {
      // This is the guard that `-{3,}` → `-{1,}` has to break. `- 醫療` does
      // not: the break rule is anchored at `\s*$`, so a dash with words after
      // it never matches however few dashes the rule accepts — that mutation
      // survives against the bullet test alone.
      final blocks = parseAssistantMarkdown('-\n--');

      expect(blocks.map((b) => b.kind).toList(), const [
        MdBlockKind.paragraph,
        MdBlockKind.paragraph,
      ]);
      expect(blocks.map((b) => b.spans.single.text).toList(), const ['-', '--']);
    });

    test('keeps a dash followed by text a bullet, not a break', () {
      // The break rule runs before the bullet rule (design D2); this is the
      // pair that pins the precedence — relaxing `-{3,}` to `-{1,}` turns
      // this bullet into a divider.
      final blocks = parseAssistantMarkdown('- 醫療');

      expect(blocks.single.kind, MdBlockKind.bullet);
      expect(blocks.single.marker, '•');
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

      // There must be a visible gap between the marker and the body text,
      // not the marker sitting flush against it. Measured on-screen rather
      // than via the marker's own SizedBox width — an end-aligned marker
      // whose gap is folded into its own box (instead of a separate spacer
      // after it) reports the same box width either way, but the gap ends
      // up on the WRONG side: before the marker's glyphs, not after them.
      // That regression stays invisible to a width-only assertion and only
      // shows up by comparing where the marker's glyphs actually end
      // against where the body text actually starts.
      final markerRight = tester.getTopRight(find.text('10.')).dx;
      final bodyLeft = tester.getTopLeft(find.textContaining('居住', findRichText: true)).dx;
      expect(bodyLeft, greaterThan(markerRight));
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
      // Not just "no exception" — a body squeezed down to a sliver is the
      // silent failure mode this fix is also for (no error thrown, but the
      // line wraps to one glyph per row for hundreds of logical pixels of
      // height). `greaterThan(10)` stayed green even at 32 logical px — far
      // narrower than a single glyph at this text scale. The invariant that
      // actually pins readability: the body column must be a substantial
      // share of the bubble's own width (measured here: ~45% once the
      // level-3 gutter/indent take their share), not some fixed pixel count
      // that a large text scale can dwarf.
      final nested = tester.getSize(find.textContaining('掛號費用', findRichText: true));
      expect(nested.width, greaterThan(maxWidth * 0.4));
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

      // Read the RENDERED semantics tree, not the `Semantics` widget's own
      // constructor argument — `tester.widget<Semantics>(...).properties.label`
      // reports whatever string the widget was built with even if that node
      // never reaches the platform's semantics tree at all (e.g. an
      // `ExcludeSemantics` wrapped around the outside instead of the inside,
      // which would make the entire reply disappear for a screen-reader
      // user while this assertion stayed green because it never looked at
      // what actually got rendered).
      final node = tester.getSemantics(
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
        node.label,
        '請先確認金額：\n1. 開啟設定\n2. 貼上金鑰\n醫療：NT\$ 21,200\n－ 掛號 100',
      );
      handle.dispose();
    });

    // The style a rendered line is actually painted with, found by the line's
    // own plain text. Read off the widget tree rather than re-derived from the
    // factors under test, so the assertions compare against hard-coded
    // literals and orderings (design D8).
    TextStyle lineStyle(WidgetTester tester, String plainText) {
      final finder = find.byWidgetPredicate(
        (w) => w is Text && w.textSpan is TextSpan && (w.textSpan! as TextSpan).toPlainText() == plainText,
      );
      return tester.widget<Text>(finder).style!;
    }

    testWidgets('renders the four heading levels at strictly decreasing sizes, none below body text', (tester) async {
      await pump(tester, '# 一\n## 二\n### 三\n#### 四\n本文');

      final h1 = lineStyle(tester, '一').fontSize!;
      final h2 = lineStyle(tester, '二').fontSize!;
      final h3 = lineStyle(tester, '三').fontSize!;
      final h4 = lineStyle(tester, '四').fontSize!;
      final body = lineStyle(tester, '本文').fontSize!;

      // Ordering plus the floor, as two separate claims: equalising two
      // factors breaks the first, and a factor below 1.0 breaks the second.
      expect(h1, greaterThan(h2));
      expect(h2, greaterThan(h3));
      expect(h3, greaterThan(h4));
      expect(h4, greaterThanOrEqualTo(body));
      expect(body, 14.0);
    });

    testWidgets('renders a heading bold even though its source has no stars', (tester) async {
      await pump(tester, '### 本月支出\n這是一段內文');

      expect(lineStyle(tester, '本月支出').fontWeight, FontWeight.w700);
      // Not just "the heading is heavy" — a renderer that bolds every line
      // would pass the assertion above on its own.
      expect(lineStyle(tester, '這是一段內文').fontWeight, isNot(FontWeight.w700));
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('renders bold inside a heading heavier than the heading itself', (tester) async {
      await pump(tester, '### 本月**總計**');

      final rich = tester.widget<Text>(find.byWidgetPredicate(
        (w) => w is Text && w.textSpan is TextSpan && (w.textSpan! as TextSpan).toPlainText() == '本月總計',
      ));
      final children = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
      final plain = children.firstWhere((s) => s.text == '本月');
      final bold = children.firstWhere((s) => s.text == '總計');

      expect(plain.style!.fontWeight, FontWeight.w700);
      expect(bold.style!.fontWeight!.index, greaterThan(plain.style!.fontWeight!.index));
    });

    testWidgets('draws a thematic break as a rule that fills a tight width but only spans the widest line under a loose one', (tester) async {
      const maxWidth = 300.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: maxWidth,
                child: AssistantMarkdown(
                  text: '第一段\n---\n第二段',
                  style: TextStyle(fontSize: 14, color: Color(0xFF000000)),
                ),
              ),
            ),
          ),
        ),
      );

      final rule = find.descendant(
        of: find.byType(AssistantMarkdown),
        matching: find.byType(ColoredBox),
      );
      expect(rule, findsOneWidget);
      // A rule that spans nothing is invisible and no "is it drawn" assertion
      // can see the difference — the width is the guard.
      //
      // This width comes from the tight `SizedBox` forwarding its own
      // constraint through `IntrinsicWidth`, not from the rule choosing to
      // fill the available space — under the real bubble's loose
      // constraints (below), the same markup produces a rule far narrower
      // than 300, matching its widest sibling line instead.
      expect(tester.getSize(rule).width, maxWidth);
      expect(tester.getSize(rule).height, 1.0);
      expect(find.textContaining('-'), findsNothing);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const AssistantMarkdown(
                  text: '第一段內容比較長\n---\n第二段',
                  style: TextStyle(fontSize: 14, color: Color(0xFF000000)),
                ),
              ),
            ),
          ),
        ),
      );

      final looseRule = find.descendant(
        of: find.byType(AssistantMarkdown),
        matching: find.byType(ColoredBox),
      );
      final looseRuleWidth = tester.getSize(looseRule).width;

      // Measured from a *separate*, rule-free pump of the same first line —
      // not from the `第一段` Text still on screen above. Inside the
      // `hasRule` column, `CrossAxisAlignment.stretch` tightens every
      // child's width to the column's own (the rule's) width, so reading
      // `第一段`'s size there would just read the rule's width back at
      // itself and pass even if the rule stopped tracking content
      // entirely. The fixture's widest line is also well past the 48px
      // floor, so a floor bug can't masquerade as this passing either.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const AssistantMarkdown(
                  text: '第一段內容比較長\n第二段',
                  style: TextStyle(fontSize: 14, color: Color(0xFF000000)),
                ),
              ),
            ),
          ),
        ),
      );
      final firstLineWidth = tester.getSize(find.text('第一段內容比較長')).width;

      expect(looseRuleWidth, firstLineWidth);
    });

    testWidgets('gives a thematic break a floor width when the reply has no other block', (tester) async {
      final handle = tester.ensureSemantics();

      // Pumped under the same loose constraints the real bubble gives
      // (Align + a wide ConstrainedBox, not a tight Directionality) — under
      // tight constraints IntrinsicWidth's own constraints.tighten clamps
      // the column to the ambient width regardless of ruleMinWidth, so a
      // floor of 0 would pass here just as easily as 48.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const AssistantMarkdown(
                  text: '---',
                  style: TextStyle(fontSize: 14, color: Color(0xFF000000)),
                ),
              ),
            ),
          ),
        ),
      );

      final rule = find.descendant(
        of: find.byType(AssistantMarkdown),
        matching: find.byType(ColoredBox),
      );
      expect(rule, findsOneWidget);
      // With no other block to follow, the rule (and the whole bubble)
      // used to collapse to zero width and render nothing. Asserted against
      // the actual floor, not just "some positive width", so a mutation to
      // the floor's value (e.g. shrinking or inflating it) turns this red.
      expect(tester.getSize(rule).width, 48.0);

      // ...and the announcement fell silent along with it — no block
      // survives the "drop the rule" filter, so the label must fall back to
      // the raw text instead of joining to an empty string.
      final node = tester.getSemantics(
        find.descendant(of: find.byType(AssistantMarkdown), matching: find.byType(Semantics)),
      );
      expect(node.label, '---');
      handle.dispose();
    });

    testWidgets('draws the rule at an alpha that clears the 3:1 non-text-contrast floor', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AssistantMarkdown(
              text: '第一段\n---\n第二段',
              style: TextStyle(fontSize: 14, color: Color(0xFF000000)),
            ),
          ),
        ),
      );

      final rule = tester.widget<ColoredBox>(find.descendant(
        of: find.byType(AssistantMarkdown),
        matching: find.byType(ColoredBox),
      ));
      // At 0.24 (the originally-shipped value) this measures ~1.5:1 against
      // the app's cream surface — an effectively invisible hairline. 0.6 is
      // the alpha that clears the WCAG 3:1 non-text-contrast floor.
      expect(rule.color.a, closeTo(0.6, 0.001));
    });

    testWidgets('scales the rule thickness with the ambient text scale', (tester) async {
      await pump(tester, '第一段\n---\n第二段');
      final ruleFinder = find.descendant(
        of: find.byType(AssistantMarkdown),
        matching: find.byType(ColoredBox),
      );
      final thicknessAt1 = tester.getSize(ruleFinder).height;

      await pump(tester, '第一段\n---\n第二段', textScale: 2.0);
      final thicknessAt2 = tester.getSize(ruleFinder).height;

      expect(thicknessAt2, greaterThan(thicknessAt1));
    });

    testWidgets('gives a thematic break more room above and below it than a paragraph break', (tester) async {
      await pump(tester, '第一句\n第二句\n\n第三句');
      // Bottom-to-top, matching how the rule's own gaps are measured below —
      // top-to-top would fold the "第二句" line's own height into the number
      // and compare it against a gap that doesn't have one.
      final blankGap = tester.getTopLeft(find.text('第三句')).dy -
          tester.getBottomLeft(find.text('第二句')).dy;

      await pump(tester, '第一句\n---\n第二句');
      final aboveRule = tester.getTopLeft(find.byType(ColoredBox)).dy -
          tester.getBottomLeft(find.text('第一句')).dy;
      final belowRule = tester.getTopLeft(find.text('第二句')).dy -
          tester.getBottomLeft(find.byType(ColoredBox)).dy;

      expect(aboveRule, greaterThan(blankGap));
      expect(belowRule, greaterThan(blankGap));
    });

    testWidgets('gives a heading more room above it than a paragraph break or a wrapped line', (tester) async {
      // All four measured gaps sit below a body-sized line, so the differences
      // are the _gapAbove values alone and not mixed line heights.
      await pump(tester, '第一句\n### 標題\n第二句\n\n第三句\n第四句');

      final headingGap = tester.getTopLeft(find.text('標題')).dy -
          tester.getTopLeft(find.text('第一句')).dy;
      final blankGap = tester.getTopLeft(find.text('第三句')).dy -
          tester.getTopLeft(find.text('第二句')).dy;
      final wrappedGap = tester.getTopLeft(find.text('第四句')).dy -
          tester.getTopLeft(find.text('第三句')).dy;

      expect(headingGap, greaterThan(blankGap));
      expect(blankGap, greaterThan(wrappedGap));
    });

    testWidgets('gives the line below a heading more room than a wrapped line', (tester) async {
      await pump(tester, '### 標題\n第一句\n第二句');
      final belowHeadingGap = tester.getTopLeft(find.text('第一句')).dy -
          tester.getBottomLeft(find.text('標題')).dy;
      final wrappedGap = tester.getTopLeft(find.text('第二句')).dy -
          tester.getBottomLeft(find.text('第一句')).dy;

      // Pins _gapAbove's "previous block is a heading" branch (design D5's 6):
      // collapsing it to the wrapped-line value must turn this red.
      expect(belowHeadingGap, greaterThan(wrappedGap));
    });

    testWidgets('speaks the heading and stays silent about the rule, in one label', (tester) async {
      final handle = tester.ensureSemantics();

      await pump(tester, '總覽如下：\n### 本月支出\n---\n* 醫療：21,200');

      final node = tester.getSemantics(
        find.descendant(of: find.byType(AssistantMarkdown), matching: find.byType(Semantics)),
      );
      // Hard-coded expectation, not a re-derivation: the break must be
      // dropped from the joined lines, not joined as `''` — an empty line in
      // the announcement is a pause some screen readers speak (design D7).
      expect(node.label, '總覽如下：\n本月支出\n醫療：21,200');
      handle.dispose();
    });

    testWidgets('leaves the bullet gutter and the leading edge alone around a heading', (tester) async {
      await pump(tester, '* 醫療\n### 小計\n* 其他');
      final withHeading = tester.getTopLeft(find.text('醫療')).dx;
      final headingLeft = tester.getTopLeft(find.text('小計')).dx;
      final afterHeading = tester.getTopLeft(find.text('其他')).dx;

      await pump(tester, '* 醫療\n* 其他');
      final withoutHeading = tester.getTopLeft(find.text('醫療')).dx;

      expect(afterHeading, withHeading);
      // Comparing the two replies is what catches a `_markerWidth` that
      // measures heading text: the two bullet groups above stay aligned with
      // each other even when the gutter widens for both.
      expect(withHeading, withoutHeading);
      expect(headingLeft, lessThan(withHeading));
    });

    testWidgets('does not indent a heading that follows a nested bullet', (tester) async {
      await pump(tester, '* 醫療\n    * 掛號 100\n### 小計');

      final topLevel = tester.getTopLeft(find.text('•').first).dx;
      final nested = tester.getTopLeft(find.text('掛號 100')).dx;
      final heading = tester.getTopLeft(find.text('小計')).dx;

      // The nested item proves the indent is live at all; without it, storing
      // headingLevel into `level` could be invisible.
      expect(nested, greaterThan(topLevel));
      expect(heading, topLevel);
    });

    testWidgets('scales heading sizes with the ambient text scale exactly once', (tester) async {
      await pump(tester, '# 一\n本文');
      final h1At1 = tester.getSize(find.text('一')).height;
      final bodyAt1 = tester.getSize(find.text('本文')).height;

      await pump(tester, '# 一\n本文', textScale: 2.0);
      final h1At2 = tester.getSize(find.text('一')).height;
      final bodyAt2 = tester.getSize(find.text('本文')).height;

      expect(h1At2, greaterThan(h1At1));
      expect(h1At2, greaterThanOrEqualTo(bodyAt2));
      expect(bodyAt2, greaterThan(bodyAt1));
      // Text applies the ambient TextScaler to fontSize itself (design D3);
      // a `scaler.scale(...)` around the heading's fontSize scales it twice
      // and lands at ~4x, not ~2x. This upper bound is the only assertion
      // that can tell double-scaling from correct scaling — the lower bounds
      // above stay green under it.
      expect(h1At2, lessThan(h1At1 * 3));
    });
  });
}
