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
///
/// It decides for itself whether to appear, from the card's [failed] /
/// [loading] pair, because a retry it started must not make it disappear: a
/// row that vanishes the moment the button is pressed is read as "refreshed",
/// while the request is still in the air and may yet fail. So the retry it
/// started keeps the row and turns the button into a disabled spinner until
/// that reload lands — the one piece of state worth remembering, and worth
/// remembering *here* rather than in four copies inside the four cards.
///
/// A card must keep this widget mounted for as long as either flag is set, or
/// the memory of the press is thrown away mid-flight along with the row.
class StaleNotice extends StatefulWidget {
  /// The card's last reload failed, and the content on screen is older than
  /// the user thinks.
  final bool failed;

  /// A reload of this card is in flight — this widget's own retry or not.
  final bool loading;

  /// What this marking is about: the card's own title. Four cards failing at
  /// once otherwise offer a screen-reader user four identically labelled
  /// "Retry" buttons with nothing to tell them apart.
  final String subject;

  /// Reloads this card — and only this card.
  final VoidCallback onRetry;

  const StaleNotice({
    super.key,
    required this.failed,
    required this.loading,
    required this.subject,
    required this.onRetry,
  });

  @override
  State<StaleNotice> createState() => _StaleNoticeState();
}

class _StaleNoticeState extends State<StaleNotice> {
  /// Whether the reload in flight is the one this row asked for.
  bool _retried = false;

  @override
  void didUpdateWidget(covariant StaleNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nothing is loading, so whatever this row asked for has landed — either
    // way. Forget the press, so a failure that follows gets a pressable row
    // again rather than a stuck spinner, and a later background reload isn't
    // mistaken for one the user started. Safe against clearing the press too
    // early: the card rebuilds this widget only when its controller says
    // something, and every one of them reports itself busy before the tap
    // handler returns.
    if (!widget.loading) _retried = false;
  }

  void _retry() {
    setState(() => _retried = true);
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final retrying = _retried && widget.loading;
    if (!widget.failed && !retrying) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final onTap = retrying ? null : _retry;
    // One node for the whole row, named after the card: unmarked, the copy is
    // swallowed into the card's own node (last in line behind a month of date
    // numbers, on the calendar card) and the button reads as a bare "Retry".
    return Semantics(
      container: true,
      button: true,
      enabled: !retrying,
      label: '${widget.subject}: ${loc.cardRefreshFailed}. ${loc.retry}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('stale-notice-row'),
        // The row is ~250px of copy and icon that all reads as part of the
        // retry, so all of it takes the tap — not just the button at the far
        // end. Rounded to the card's bottom corners, which this row is flush
        // against.
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        onTap: onTap,
        child: Padding(
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
                onPressed: onTap,
                // Not the button default (`colorScheme.primary`): the pastel
                // primary is a *fill* colour here, and as text on the cream
                // card it measures 1.64:1 — a quarter of the 4.5:1 AA floor.
                // Full ink clears it in both themes and still reads as the
                // action against the muted copy beside it.
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                child: retrying
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(loc.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
