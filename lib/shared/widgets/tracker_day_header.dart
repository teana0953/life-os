import 'package:flutter/material.dart';

import '../date/day_format.dart';

/// The shared "viewed date + today/history title" header used at the top of a
/// daily tracker's first section card (water, bowel): a [titleLarge] title
/// that reads [todayTitle] when [day] is today (resolved via [clock] and
/// [daysBetween]) and [historyTitle] otherwise, above the full [fullDateLabel]
/// for the viewed day in [bodyMedium]/`onSurfaceVariant`.
///
/// Behavior- and pixel-preserving extraction of the header previously inlined
/// in `water_screen.dart`. Styles derive from [Theme] (never hard-coded).
class TrackerDayHeader extends StatelessWidget {
  final String day;
  final DateTime Function() clock;
  final String todayTitle;
  final String historyTitle;

  const TrackerDayHeader({
    super.key,
    required this.day,
    required this.clock,
    required this.todayTitle,
    required this.historyTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewedDate = DateTime.parse(day);
    final now = clock();
    final isToday =
        daysBetween(viewedDate, DateTime(now.year, now.month, now.day)) == 0;
    final title = isToday ? todayTitle : historyTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          fullDateLabel(context, viewedDate),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
