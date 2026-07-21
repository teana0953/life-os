import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/fractional_progress_bar.dart';

/// A per-category portion progress bar: a label, a rounded track filled to
/// `clamp(logged / effective, 0, 1)` in the category color, and the
/// "used / target" numbers (D1 in design.md). An `effective` of 0 or less
/// renders an empty bar rather than dividing by zero; logging past the
/// target still shows a full bar while the numbers keep the true values.
/// Pure and presentation-only.
class CategoryProgressBar extends StatelessWidget {
  final String label;
  final double logged;
  final double effective;
  final Color? color;

  /// Optional trailing label shown instead of the default "used / target"
  /// text (D3 in design.md) — e.g. a "3 remaining" phrasing. Defaults to
  /// `null`, which preserves the original used/target text, so existing
  /// call sites are unaffected.
  final String? trailingLabel;

  const CategoryProgressBar({
    super.key,
    required this.label,
    required this.logged,
    required this.effective,
    required this.color,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fraction = effective <= 0 ? 0.0 : (logged / effective).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              trailingLabel ?? loc.dietProgressOfTarget(logged, effective),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 6),
        FractionalProgressBar(
          fraction: fraction,
          fillColor: color ?? theme.colorScheme.primary,
        ),
      ],
    );
  }
}
