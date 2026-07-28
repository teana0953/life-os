import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// The slim row an overview card appends below its content when a reload of
/// content that is *already on screen* failed: it says the card wasn't
/// updated and carries a retry for that card alone (each overview card has
/// its own source, so one failing says nothing about the others).
///
/// Sits at the end of the card because the four overview cards' layouts
/// differ wildly (a two-line card, a whole-month calendar) and the end is the
/// one place that takes an extra row without touching any of them.
///
/// Carries its own padding rather than taking a layout parameter: cards that
/// each passed their own would drift apart, which is the inconsistency this
/// exists to remove. A card whose own padding sits on its outer surface must
/// move that padding onto its content instead, or the notice inherits it
/// twice.
class StaleNotice extends StatelessWidget {
  /// Reloads this card — and only this card.
  final VoidCallback onRetry;

  const StaleNotice({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loc.cardRefreshFailed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            key: const Key('stale-notice-retry'),
            onPressed: onRetry,
            child: Text(loc.retry),
          ),
        ],
      ),
    );
  }
}
