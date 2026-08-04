import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// A small, de-emphasized line showing when a data-bearing screen last loaded
/// its data successfully — placed at the top of the overview, trends, and the
/// day-keyed tracker screens.
///
/// [lastLoadedAt] is `null` before the first successful load, and this renders
/// nothing then (an empty `SizedBox`): showing "never" would be noise while the
/// first load is in flight or after a failure with no prior success. Once set,
/// it shows "Updated HH:mm" — 24-hour, via `DateFormat('HH:mm')`, deliberately
/// **not** following the system 12/24-hour setting. It shares a screen with
/// reading/meal times that are always rendered 24-hour, and a locale-following
/// label put two clock notations side by side ("Updated 9:30 PM" above chips
/// reading "21:30"). Plain text (screen-reader legible); it never conveys
/// meaning by colour alone.
class LastLoadedLabel extends StatelessWidget {
  final DateTime? lastLoadedAt;

  const LastLoadedLabel({super.key, required this.lastLoadedAt});

  @override
  Widget build(BuildContext context) {
    final at = lastLoadedAt;
    if (at == null) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final time = DateFormat('HH:mm').format(at);
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
