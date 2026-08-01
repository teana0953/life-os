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
/// is `Expanded` into whatever is left. [value] should carry
/// `textAlign: TextAlign.end` — that is what pins it to the right of its slot.
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
          Expanded(child: value),
        ],
      ),
    );
  }
}
