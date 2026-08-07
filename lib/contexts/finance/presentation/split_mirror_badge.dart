import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Marks a ledger row the server mirrored out of a split expense.
///
/// Shared by 明細 and the overview's recent-transactions list rather than
/// written twice: the two lists show the same transactions, and a mark on one
/// of them only teaches the user that the mark means nothing. Each list keys
/// its own instance, so a mark dropped from one screen still fails that
/// screen's own guard.
///
/// Text as well as an icon: the icon alone says "this row is different" but
/// not how, and what the user needs before tapping is that the row is not
/// theirs to delete.
class SplitMirrorBadge extends StatelessWidget {
  const SplitMirrorBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.call_split, size: 14, color: color),
        const SizedBox(width: 4),
        // `Flexible`, not a bare `Text`: the badge sits in a `ListTile`
        // subtitle beside a wrapping category name, and at a 2x text scale on
        // a 320dp screen the label is wider than the tile leaves it.
        Flexible(
          child: Text(
            loc.financeSplitMirrorBadge,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
