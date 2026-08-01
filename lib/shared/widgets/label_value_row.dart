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
/// together don't fit. The value's box therefore ends at the row's right edge
/// by construction — the `Expanded` label is what pushes it there — so nothing
/// has to opt into `TextAlign.end` to read flush right.
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
/// ## The degenerate case
///
/// The value is capped at the row's width (minus [gap]) rather than left
/// unbounded, so a value too wide for the row wraps instead of overflowing. It
/// then leaves the `Expanded` label nothing, and the *label* is what degrades —
/// which is the right way round: labels are prose and wrap, values are numbers
/// and must stay legible. Callers that pass `textAlign: TextAlign.end` on the
/// value keep those wrapped lines right-aligned; a bare `Text` wraps
/// left-aligned inside a box that still ends at the row's edge.
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
          Expanded(child: label),
          SizedBox(width: gap),
          ConstrainedBox(
            // Non-flex, so `RenderFlex` lays it out *before* dividing what is
            // left — that is what makes it take its natural width. Minus the
            // gap: at 320dp/2x a value that fills the row left the gap with
            // nowhere to go, a RenderFlex overflow exactly [gap] wide.
            constraints: BoxConstraints(
              maxWidth: (constraints.maxWidth - gap).clamp(0.0, double.infinity),
            ),
            child: value,
          ),
        ],
      ),
    );
  }
}
