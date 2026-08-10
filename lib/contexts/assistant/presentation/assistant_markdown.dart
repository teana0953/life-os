import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The slice of Markdown the assistant actually emits — bold, bullet and
/// numbered lists, paragraph breaks — and nothing else.
///
/// The model writes Markdown whether or not anyone asked it to, and a bubble
/// that renders none of it shows `**NT$ 23,847**` to the user (issue #152).
/// The answer here is a parser for the handful of marks that show up in real
/// replies rather than a Markdown package: everything outside this list —
/// headings, tables, links, code fences — stays **literal text**, which is a
/// deliberate limit, not an oversight. A mark this parser does not know is
/// shown as the user typed it, never swallowed.
enum MdBlockKind { paragraph, bullet, numbered }

/// A run of text inside one line, bold or not.
@immutable
class MdSpan {
  const MdSpan(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      other is MdSpan && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() => bold ? 'MdSpan.bold("$text")' : 'MdSpan("$text")';
}

/// One source line: its kind, its list marker if it has one, and its content.
@immutable
class MdBlock {
  const MdBlock(
    this.kind,
    this.spans, {
    this.marker,
    this.blankBefore = false,
    this.level = 0,
  });

  final MdBlockKind kind;
  final List<MdSpan> spans;

  /// What the list item is labelled with — `•` for bullets, `1.` for numbered
  /// items (the source's own number, so `3.` stays 3 and does not renumber).
  final String? marker;

  /// Whether a blank line separated this block from the one above. Carried so
  /// a paragraph break can breathe more than a wrapped line does.
  final bool blankBefore;

  /// How many levels of leading indent the source line had, capped at 3.
  /// Only meaningful for list items — a nested `    * 掛號` under `* 醫療`
  /// must not read as another top-level item.
  final int level;

  @override
  bool operator ==(Object other) =>
      other is MdBlock &&
      other.kind == kind &&
      other.marker == marker &&
      other.blankBefore == blankBefore &&
      other.level == level &&
      _sameSpans(other.spans, spans);

  @override
  int get hashCode =>
      Object.hash(kind, marker, blankBefore, level, Object.hashAll(spans));

  @override
  String toString() =>
      'MdBlock($kind, marker: $marker, blankBefore: $blankBefore, level: $level, $spans)';
}

bool _sameSpans(List<MdSpan> a, List<MdSpan> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final _bullet = RegExp(r'^(\s*)[*-]\s+(.*)$');
final _numbered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');

/// Every two leading spaces is one nesting level, capped at 3 — deep enough
/// for a real reply's category → item breakdown, shallow enough that a
/// model's stray extra space doesn't run the gutter off the bubble. A tab is
/// expanded to two spaces first, or it would count as zero indent and the
/// nested item would flatten to a sibling of its parent.
int _indentLevel(String leadingSpaces) =>
    (leadingSpaces.replaceAll('\t', '  ').length / 2).floor().clamp(0, 3);

/// Splits [source] into one block per non-blank line.
///
/// Blank lines are not blocks; they set [MdBlock.blankBefore] on the line that
/// follows, which is the only thing the spacing needs from them.
List<MdBlock> parseAssistantMarkdown(String source) {
  final blocks = <MdBlock>[];
  var blankBefore = false;
  var first = true;

  for (final raw in source.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      // Leading blanks must not push the first block down — the bubble's own
      // padding is the gap above it.
      if (!first) blankBefore = true;
      continue;
    }

    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      blocks.add(MdBlock(
        MdBlockKind.bullet,
        parseInlineMarkdown(bullet.group(2)!),
        marker: '•',
        blankBefore: blankBefore,
        level: _indentLevel(bullet.group(1)!),
      ));
    } else {
      final numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        blocks.add(MdBlock(
          MdBlockKind.numbered,
          parseInlineMarkdown(numbered.group(3)!),
          marker: '${numbered.group(2)}.',
          blankBefore: blankBefore,
          level: _indentLevel(numbered.group(1)!),
        ));
      } else {
        blocks.add(MdBlock(
          MdBlockKind.paragraph,
          parseInlineMarkdown(line.trimLeft()),
          blankBefore: blankBefore,
        ));
      }
    }
    blankBefore = false;
    first = false;
  }
  return blocks;
}

/// Finds the next `**` in [s] at or after [from] that can pair off cleanly —
/// the run of consecutive stars it sits in has even length, so it splits
/// into whole `**` delimiters with none left over. A run of odd length like
/// `***` cannot: pairing off two of its stars as a delimiter always leaves
/// one star stranded, and consuming it as part of a delimiter anyway is how
/// `***重要***` used to render as bold `*重要` plus a leaked `*` — a mark
/// half-eaten, not shown as typed. An even run (`**`, `****`, ...) is
/// unaffected — that's the existing, tested "empty bold" shape.
int _findDelimiter(String s, int from) {
  var i = s.indexOf('**', from);
  while (i >= 0) {
    var start = i;
    while (start > 0 && s[start - 1] == '*') {
      start--;
    }
    var end = i + 2;
    while (end < s.length && s[end] == '*') {
      end++;
    }
    if ((end - start).isEven) return i;
    i = s.indexOf('**', i + 1);
  }
  return -1;
}

/// Splits one line into bold and plain runs on `**`.
///
/// An opener with no closer is not a mark at all: `**note` keeps its stars, so
/// a reply cut off mid-sentence never silently loses characters. Empty bold
/// (`****`) collapses to nothing rather than an empty styled span.
List<MdSpan> parseInlineMarkdown(String line) {
  final spans = <MdSpan>[];
  var rest = line;

  while (true) {
    final open = _findDelimiter(rest, 0);
    if (open < 0) break;
    final close = _findDelimiter(rest, open + 2);
    if (close < 0) break;

    if (open > 0) spans.add(MdSpan(rest.substring(0, open)));
    final bold = rest.substring(open + 2, close);
    if (bold.isNotEmpty) spans.add(MdSpan(bold, bold: true));
    rest = rest.substring(close + 2);
  }

  if (rest.isNotEmpty) spans.add(MdSpan(rest));
  // A line that was nothing but `****` still needs a span, or the row would
  // have no height and the reply would appear to skip a line.
  if (spans.isEmpty) spans.add(const MdSpan(''));
  return spans;
}

/// Renders [text] as the assistant's Markdown slice, in [style].
///
/// Used for the assistant's bubbles only. The user's own message is shown as
/// typed — someone who writes `*` means the character, and re-formatting the
/// words they can see in the composer would be the app rewriting them.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final blocks = parseAssistantMarkdown(text);
    final bold = style.copyWith(fontWeight: FontWeight.w700);
    // Measured with the style Text actually paints with — Text merges the
    // ambient DefaultTextStyle onto whatever it's given, and measuring the
    // raw `style` instead silently under-sizes the gutter whenever the
    // caller passes a style with gaps (assistant_screen.dart only sets
    // `color`, so it merges up to the theme's Quicksand body style).
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final effectiveBold = DefaultTextStyle.of(context).style.merge(bold);
    final scaler = MediaQuery.textScalerOf(context);
    // The gutter holds glyphs, so its width is measured from the widest
    // marker actually present, at the ambient text scale — a fixed width in
    // logical pixels clips "10." at 200% and the user loses the number. The
    // gap sits between the marker and the body text and is kept separate
    // from the marker's own box, or a `TextAlign.end` marker would render it
    // on the wrong (leading) side, flush against the body instead of before
    // it.
    final markerWidth = _markerWidth(context, blocks, effectiveStyle);
    final markerGap = markerWidth == 0 ? 0.0 : scaler.scale(6);
    final gutter = markerWidth + markerGap;
    // One indent step per nesting level, so `    * 掛號` under `* 醫療` reads
    // as a child, not another top-level category.
    final indentUnit = scaler.scale(16);

    // A screen-reader user hears the reply once, in reading order, the same
    // as before this widget existed — not one swipe per block plus a
    // announced "•" for every bullet. The rendered tree stays excluded; this
    // label is the only thing assistive tech sees.
    final semanticLabel = blocks
        .map((b) {
          // The bullet glyph itself is decoration, not content — reading it
          // aloud ("bullet") on every item is noise. A numbered marker is
          // content (it is the step number), so that one stays.
          final marker = (b.marker == null || b.marker == '•') ? '' : '${b.marker} ';
          // A nested item's marker alone doesn't say it's a child — flattened
          // into the announcement, "掛號 100" under "醫療" would read as
          // another top-level line, same misreading the visual indent was
          // built to prevent. One `－` per nesting level, a symbol rather
          // than a language-specific word, so it needs no l10n.
          final levelPrefix = b.level > 0 ? '${'－' * b.level} ' : '';
          return levelPrefix + marker + b.spans.map((s) => s.text).join();
        })
        .join('\n');

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve room for the gutter and a body column wide enough to
        // actually read, so a deep nesting level can't push the Row's
        // fixed-width parts past the bubble's own width — without this, a
        // level-3 item in a narrow bubble at a large text scale overflows
        // horizontally instead of wrapping. A fixed 32px floor is fine at
        // scale 1.0 but is narrower than a single glyph at scale 3.0 — the
        // body doesn't overflow, it just wraps to one character per line
        // for hundreds of logical pixels of height. Scaling the floor with
        // the ambient font size keeps a multi-character-wide column at any
        // text scale.
        final minBodyWidth = scaler.scale((effectiveStyle.fontSize ?? 14) * 8);
        final maxTotalIndent = constraints.hasBoundedWidth
            ? (constraints.maxWidth - gutter - minBodyWidth).clamp(0.0, double.infinity)
            : double.infinity;
        final perLevelIndent = math.min(indentUnit, maxTotalIndent / 3);

        return Semantics(
          label: semanticLabel,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < blocks.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      top: i == 0 ? 0 : _gapAbove(blocks[i], scaler),
                      left: blocks[i].level * perLevelIndent,
                    ),
                    child: _blockRow(blocks[i], effectiveStyle, effectiveBold, markerWidth, markerGap),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The widest marker in [blocks], laid out at the ambient scale in
  /// [effectiveStyle]. The gap before the body text is added by the caller,
  /// not here — folding it into this width and end-aligning the marker text
  /// inside it puts the gap on the wrong (leading) side of the marker.
  /// Zero when nothing is a list item.
  double _markerWidth(BuildContext context, List<MdBlock> blocks, TextStyle effectiveStyle) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final block in blocks) {
      final marker = block.marker;
      if (marker == null) continue;
      final painter = TextPainter(
        text: TextSpan(text: marker, style: effectiveStyle),
        textScaler: scaler,
        textDirection: direction,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  // Scaled with the ambient text scale like the gutter and indent are — at
  // 200% a paragraph break and a wrapped line would otherwise collapse
  // toward the same gap once the (unscaled) text around them has doubled in
  // height.
  double _gapAbove(MdBlock block, TextScaler scaler) {
    if (block.blankBefore) return scaler.scale(10);
    return scaler.scale(block.kind == MdBlockKind.paragraph ? 4 : 2);
  }

  Widget _blockRow(
    MdBlock block,
    TextStyle style,
    TextStyle bold,
    double markerWidth,
    double markerGap,
  ) {
    final body = Text.rich(
      TextSpan(
        children: [
          for (final span in block.spans)
            TextSpan(text: span.text, style: span.bold ? bold : style),
        ],
      ),
      style: style,
    );
    if (block.marker == null) return body;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A fixed-width marker box, so wrapped list text lines up under
        // itself instead of under the marker.
        SizedBox(
          width: markerWidth,
          child: Text(block.marker!, style: style, textAlign: TextAlign.end),
        ),
        // The gap belongs between the marker and the body, not inside the
        // end-aligned marker box (where it would sit to the marker's left).
        SizedBox(width: markerGap),
        Flexible(child: body),
      ],
    );
  }
}
