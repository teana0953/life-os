import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// A small, de-emphasized line showing when a data-bearing screen last loaded
/// its data successfully — placed at the top of the overview, trends, and the
/// day-keyed tracker screens.
///
/// [lastLoadedAt] is `null` before the first successful load, and this renders
/// nothing then (an empty `SizedBox`): showing "never" would be noise while the
/// first load is in flight or after a failure with no prior success. Once set,
/// it shows "Updated HH:mm" — the clock time formatted via [TimeOfDay.format],
/// so it follows the system 12/24-hour setting. Plain text (screen-reader
/// legible); it never conveys meaning by colour alone.
class LastLoadedLabel extends StatelessWidget {
  final DateTime? lastLoadedAt;

  const LastLoadedLabel({super.key, required this.lastLoadedAt});

  @override
  Widget build(BuildContext context) {
    final at = lastLoadedAt;
    if (at == null) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final time = TimeOfDay.fromDateTime(at).format(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        loc.lastUpdatedAt(time),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
