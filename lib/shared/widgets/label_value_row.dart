import 'package:flutter/material.dart';

/// A "label on the left, value flush right" row that survives both a narrow
/// screen and a wide one.
///
/// Getting all three properties at once — label on its natural width, value
/// hugging the right edge, neither able to overflow — rules out the two
/// obvious `Row` shapes, both of which shipped and regressed here:
///
/// * Two flex children (`Expanded`/`Flexible` on both halves) bound each half
///   to its *share* of the row, i.e. 50%, so a label that would fit wraps
///   anyway while half the row sits empty (`Total liabilities` took 3 lines at
///   390dp).
/// * A loose `Flexible` around the value shrink-wraps it and parks the slack
///   *after* it, so `TextAlign.end` aligns inside a too-narrow box and the
///   value drifts left of the row's edge — further the wider the screen.
///
/// So [label] is a plain child, bounded by the row's own width so it wraps
/// instead of overflowing and otherwise takes only what it needs, and [value]
/// is `Expanded` into whatever is left.
///
/// ## What this row needs from its host
///
/// * **A bounded width.** The `LayoutBuilder` below reads
///   `constraints.maxWidth` to size the label, and `Expanded` needs a finite
///   row width to divide up. Put this inside a horizontally unbounded parent —
///   a `Row`/`ListView` scrolling horizontally, an unconstrained `ListTile`
///   trailing slot — and it throws instead of degrading.
/// * **No ancestor that asks for its intrinsic width.** `IntrinsicWidth`,
///   `IntrinsicHeight` and friends measure a child by interrogating it outside
///   layout; the `LayoutBuilder` here cannot answer that (it only knows a size
///   once it has been given constraints) and asserts. This is why the row works
///   as a `ListTile`'s `title` — `ListTile` lays its title out with real
///   constraints and never asks for its intrinsic width — but would not survive
///   being wrapped in an `IntrinsicWidth` to "make the columns line up".
///
/// ## Why the value's alignment is set here, not by the caller
///
/// Because [value] is `Expanded`, its box always spans to the row's right edge
/// whatever the text's length: the box position carries no alignment
/// information, so where the glyphs land is decided purely by `textAlign`. A
/// caller that passed a bare `Text` used to get `TextAlign.start` by default
/// and the value simply drew flush *left* inside a full-width slot — no
/// exception, no overflow stripe, nothing but a value that looks wrong (QA
/// measured a glyph right edge of 164.9 in a 310.8-wide slot). Nothing about
/// that failure is loud enough to catch in review, so this widget wraps [value]
/// in a `DefaultTextStyle.merge(textAlign: TextAlign.end)` and owns the
/// alignment itself. A `Text` that names its own `textAlign` still wins, so
/// callers can opt out; they just no longer have to opt *in*.
///
/// One degenerate case is left unhandled on purpose: a label long enough and
/// unbreakable enough to eat the whole row (QA needed a 56-character
/// no-break-opportunity label at 320dp) squeezes the value's slot to zero width,
/// and the value then paints outside the row — quietly, since a zero-width
/// `Expanded` is not an overflow. No real label in this app comes close, and
/// guarding it would mean truncating labels that today wrap fine.
class LabelValueRow extends StatelessWidget {
  final Widget label;
  final Widget value;

  /// Minimum space between the two halves.
  final double gap;

  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.gap = 8,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            // Minus the gap: at 320dp/2x the label alone fills the row, and
            // bounding it at the full width left the gap with nowhere to go —
            // a RenderFlex overflow exactly [gap] wide.
            constraints: BoxConstraints(
              maxWidth: (constraints.maxWidth - gap).clamp(0.0, double.infinity),
            ),
            child: label,
          ),
          SizedBox(width: gap),
          Expanded(
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.end,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}
