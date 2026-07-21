import 'package:flutter/material.dart';

/// The shared inner fill bar for progress readouts: a rounded, outlined track
/// (from the theme) overlaid with a [fillColor] bar sized to [fraction] of the
/// width. [fraction] is clamped to 0..1, so an over-target caller shows a full
/// bar and a negative one shows empty. Callers own the surrounding label/readout
/// and compute their own [fraction] and [fillColor].
class FractionalProgressBar extends StatelessWidget {
  final double fraction;
  final Color fillColor;

  const FractionalProgressBar({
    super.key,
    required this.fraction,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(color: theme.colorScheme.outline, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
