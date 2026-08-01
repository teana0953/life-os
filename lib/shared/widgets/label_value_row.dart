import 'package:flutter/material.dart';

/// A "label on the left, value flush right" row that survives both a narrow
/// screen and a wide one.
///
/// Getting all three properties at once — value whole and hugging the right
/// edge, label wrapping only when it truly has to, neither able to overflow —
/// rules out the three `Row` shapes that shipped and regressed here:
///
/// * Two flex children (`Expanded`/`Flexible` on both halves) bound each half
///   to its *share* of the row, i.e. 50%, so a label that would fit wraps
///   anyway while half the row sits empty (`Total liabilities` took 3 lines at
///   390dp).
/// * A loose `Flexible` around the value shrink-wraps it and parks the slack
///   *after* it, so `TextAlign.end` aligns inside a too-narrow box and the
///   value drifts left of the row's edge — further the wider the screen.
/// * `Expanded` on the *value* (label on its natural width) gets the priority
///   backwards: the label takes what it wants and the value absorbs the
///   squeeze, so a 30-character account name left the amount a 0–9dp column
///   that broke one digit per line and blew a 64dp tile up to 208dp — at every
///   width from 390 to 800dp, and without an exception to catch it.
///
/// So the priority is the other way round, copying `_BudgetRow` in
/// `contexts/finance/presentation/budget_card.dart`: [value] is a **non-flex**
/// child, so it is laid out first and takes exactly its natural width, and
/// [label] is `Expanded` into whatever is left and yields (wraps) when the two
/// together don't fit. The value's *box* therefore ends at the row's right edge
/// by construction — the `Expanded` label is what pushes it there.
///
/// That places the box, not the glyphs. While the value fits on one line the
/// box *is* its glyphs and the distinction is invisible, which is why deleting
/// every `TextAlign.end` in the app once left the whole suite green. Once the
/// value wraps (see below, and it now can while the row still has room),
/// `TextAlign.end` is the only thing holding the continuation lines against the
/// edge. So callers whose value is a number **must** pass
/// `textAlign: TextAlign.end`; the row cannot impose it on an arbitrary
/// [value] widget.
///
/// ## What this row needs from its host
///
/// * **A bounded width.** The `LayoutBuilder` below reads
///   `constraints.maxWidth` to cap the value, and `Expanded` needs a finite
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
/// ## The degenerate case: both halves have a floor
///
/// The value is bounded rather than left unbounded, so a value too wide for the
/// row wraps instead of overflowing. Bounding it at the *whole* row (minus
/// [gap]) is not enough, though: it moves the collapse onto the label instead
/// of removing it. A value that fills the row leaves the `Expanded` label 0dp,
/// and 0dp is not "the label wraps" — QA measured a 27-character account name
/// at 320dp/2x come back as a `16.0..16.0` box broken into 24 one-glyph lines
/// that grew the row to 960dp, silently, with no exception to catch it.
///
/// So the value is capped at [_maxValueFraction] of the row instead, which
/// leaves the `Expanded` label the remaining share as a floor. Both halves can
/// wrap; neither can be squeezed to nothing. Measured on that same row at
/// 320dp/2x: label 108dp over 9 lines, value 200dp over 2, row 360dp — against
/// 0dp/24 lines/960dp before.
///
/// 0.65 rather than the 0.6 or 0.7 either side of it: at 0.7 the value wrapped
/// to the same 2 lines as at 0.65 while starving the label a further 15dp, so
/// 0.65 is strictly better; 0.6 gave a shorter row (280dp) but broke the value
/// into 3 lines, and the value is the half this row exists to keep legible.
class LabelValueRow extends StatelessWidget {
  final Widget label;
  final Widget value;

  /// Minimum space between the two halves.
  final double gap;

  /// The most of the row the value may take, and so — as its complement — the
  /// label's floor. See "The degenerate case" above for why both halves need
  /// one and why this number.
  static const double _maxValueFraction = 0.65;

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
          Expanded(child: label),
          SizedBox(width: gap),
          ConstrainedBox(
            // Non-flex, so `RenderFlex` lays it out *before* dividing what is
            // left — that is what makes it take its natural width. Minus the
            // gap: at 320dp/2x a value that fills the row left the gap with
            // nowhere to go, a RenderFlex overflow exactly [gap] wide. Times
            // [_maxValueFraction]: what is *not* handed to the value is the
            // label's floor, so neither half can be squeezed to 0dp.
            constraints: BoxConstraints(
              maxWidth:
                  (constraints.maxWidth - gap).clamp(0.0, double.infinity) *
                  _maxValueFraction,
            ),
            child: value,
          ),
        ],
      ),
    );
  }
}
