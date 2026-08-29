import 'package:flutter/material.dart';

/// The circular status badge the home dashboard's cycle tile and the health
/// overview's next-period card both lead with — the same 32dp circle, and the
/// same two forms, the menstrual calendar marks its days with: **filled** for
/// something that happened, **outlined** (2dp) for a prediction.
///
/// It knows nothing about menstrual states: the mapping from a state to
/// [filled] / [color] / [textColor] / [label] lives in the menstrual
/// presentation layer (`cycle_badge_style.dart`), so this file stays as free
/// of domain knowledge as the rest of `shared/widgets/`.
///
/// A space in [label] is a **line break**, not a space: "3d late" is wider
/// than a 32dp circle at any readable size, and two short stacked lines are
/// what fits (the calendar's day marker stacks two lines in the same
/// diameter). The [FittedBox] then guarantees the result stays inside the
/// circle for the labels that still do not fit — CJK, and every label past
/// the 1.3 scale clamp.
class CycleBadge extends StatelessWidget {
  final bool filled;
  final Color color;
  final Color textColor;
  final String label;

  const CycleBadge({
    super.key,
    required this.filled,
    required this.color,
    required this.textColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      // Clamped inside the badge only, like the calendar's day marker: past
      // ~1.3 the label stops being legible inside a fixed 32dp circle, and
      // the unclamped information is in the surrounding sentence and date
      // line, which keep growing with the user's setting.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : null,
            border: filled ? null : Border.all(color: color, width: 2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.replaceAll(' ', '\n'),
              textAlign: TextAlign.center,
              // `height: 1` for the same reason the calendar marker sets it:
              // at the theme's natural line height two stacked lines are
              // taller than the circle they sit in.
              style: theme.textTheme.labelSmall?.copyWith(
                height: 1,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
