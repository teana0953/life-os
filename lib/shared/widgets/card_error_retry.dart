import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// The body an overview card shows when it failed to load and has nothing to
/// fall back on: the error [message] plus a retry button. Meant to sit inside
/// the caller's own card shell — it draws no card of its own.
///
/// [header] is spread straight into the column (not wrapped in a nested
/// [Column], which would stretch the card): a card that keeps controls
/// visible in its error state — a period selector whose 90-day load is the
/// one that timed out — passes them here. With a header the column aligns to
/// the start, so the message and the button are centered individually;
/// without one the column centers them itself, unchanged from before.
class CardErrorRetry extends StatelessWidget {
  final String message;
  final Key messageKey;
  final Key retryKey;
  final VoidCallback onRetry;

  /// Widgets rendered above the message, spread into the column as siblings.
  final List<Widget> header;

  /// The gap between the header and the message. The message-to-button gap is
  /// a fixed 12 across every card.
  final double headerSpacing;

  const CardErrorRetry({
    super.key,
    required this.message,
    required this.messageKey,
    required this.retryKey,
    required this.onRetry,
    this.header = const <Widget>[],
    this.headerSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final hasHeader = header.isNotEmpty;

    final message = Text(
      this.message,
      key: messageKey,
      textAlign: TextAlign.center,
      style: TextStyle(color: theme.colorScheme.error),
    );
    final retry = FilledButton(
      key: retryKey,
      onPressed: onRetry,
      child: Text(loc.retry),
    );

    return Column(
      crossAxisAlignment: hasHeader
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasHeader) ...[...header, SizedBox(height: headerSpacing)],
        if (hasHeader) Center(child: message) else message,
        const SizedBox(height: 12),
        if (hasHeader) Center(child: retry) else retry,
      ],
    );
  }
}
