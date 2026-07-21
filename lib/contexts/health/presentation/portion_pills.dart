import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';

String _formatPortion(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

/// Renders one pill per non-zero food-group portion among
/// `{staple, meat, fruit, veg}`, colored via [DietCategoryColors] and
/// labeled with the category name and value (D2 in design.md). Zero-value
/// groups are omitted entirely, so an entry with e.g. 0 staple and 1 meat
/// shows a single "meat 1" pill rather than a lone "0". Pure and presentation-
/// only; laid out in a [Wrap] so it never overflows.
class PortionPills extends StatelessWidget {
  final double staple;
  final double meat;
  final double fruit;
  final double veg;

  const PortionPills({
    super.key,
    required this.staple,
    required this.meat,
    required this.fruit,
    required this.veg,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dietColors = theme.extension<DietCategoryColors>();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (staple != 0)
          _Pill(
            label: loc.dietCategoryStaple,
            value: staple,
            color: dietColors?.staple,
          ),
        if (meat != 0)
          _Pill(
            label: loc.dietCategoryMeat,
            value: meat,
            color: dietColors?.meat,
          ),
        if (fruit != 0)
          _Pill(
            label: loc.dietCategoryFruit,
            value: fruit,
            color: dietColors?.fruit,
          ),
        if (veg != 0)
          _Pill(
            label: loc.dietCategoryVeg,
            value: veg,
            color: dietColors?.veg,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;

  const _Pill({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline, width: 2),
      ),
      child: Text(
        '$label ${_formatPortion(value)}',
        style: theme.textTheme.bodyMedium,
        // Keep the label on one line so a width-starved pill stays a capsule
        // instead of wrapping its text and rounding into a blob. The Wrap
        // parent flows a too-wide pill onto the next line rather than
        // compressing it.
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
