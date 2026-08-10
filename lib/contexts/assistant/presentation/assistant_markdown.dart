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
  const MdBlock(this.kind, this.spans, {this.marker, this.blankBefore = false});

  final MdBlockKind kind;
  final List<MdSpan> spans;

  /// What the list item is labelled with — `•` for bullets, `1.` for numbered
  /// items (the source's own number, so `3.` stays 3 and does not renumber).
  final String? marker;

  /// Whether a blank line separated this block from the one above. Carried so
  /// a paragraph break can breathe more than a wrapped line does.
  final bool blankBefore;

  @override
  bool operator ==(Object other) =>
      other is MdBlock &&
      other.kind == kind &&
      other.marker == marker &&
      other.blankBefore == blankBefore &&
      _sameSpans(other.spans, spans);

  @override
  int get hashCode => Object.hash(kind, marker, blankBefore, Object.hashAll(spans));

  @override
  String toString() => 'MdBlock($kind, marker: $marker, blankBefore: $blankBefore, $spans)';
}

bool _sameSpans(List<MdSpan> a, List<MdSpan> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final _bullet = RegExp(r'^\s*[*-]\s+(.*)$');
final _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');

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
        parseInlineMarkdown(bullet.group(1)!),
        marker: '•',
        blankBefore: blankBefore,
      ));
    } else {
      final numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        blocks.add(MdBlock(
          MdBlockKind.numbered,
          parseInlineMarkdown(numbered.group(2)!),
          marker: '${numbered.group(1)}.',
          blankBefore: blankBefore,
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

/// Splits one line into bold and plain runs on `**`.
///
/// An opener with no closer is not a mark at all: `**note` keeps its stars, so
/// a reply cut off mid-sentence never silently loses characters. Empty bold
/// (`****`) collapses to nothing rather than an empty styled span.
List<MdSpan> parseInlineMarkdown(String line) {
  final spans = <MdSpan>[];
  var rest = line;

  while (true) {
    final open = rest.indexOf('**');
    if (open < 0) break;
    final close = rest.indexOf('**', open + 2);
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
    // The gutter holds glyphs, so its width is measured from the widest
    // marker actually present, at the ambient text scale — a fixed width in
    // logical pixels clips "10." at 200% and the user loses the number.
    final gutter = _gutterWidth(context, blocks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _gapAbove(blocks[i])),
            child: _blockRow(blocks[i], bold, gutter),
          ),
      ],
    );
  }

  /// The widest marker in [blocks], laid out at the ambient scale, plus a
  /// small gap before the text. Zero when nothing is a list item.
  double _gutterWidth(BuildContext context, List<MdBlock> blocks) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final block in blocks) {
      final marker = block.marker;
      if (marker == null) continue;
      final painter = TextPainter(
        text: TextSpan(text: marker, style: style),
        textScaler: scaler,
        textDirection: direction,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest == 0 ? 0 : widest + scaler.scale(6);
  }

  double _gapAbove(MdBlock block) {
    if (block.blankBefore) return 10;
    return block.kind == MdBlockKind.paragraph ? 4 : 2;
  }

  Widget _blockRow(MdBlock block, TextStyle bold, double gutter) {
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
      children: [
        // A fixed-width gutter, so wrapped list text lines up under itself
        // instead of under the marker.
        SizedBox(
          width: gutter,
          child: Text(block.marker!, style: style),
        ),
        Expanded(child: body),
      ],
    );
  }
}
