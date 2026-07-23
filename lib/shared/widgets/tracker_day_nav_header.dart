import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../date/day_format.dart';
import 'mascot.dart';

/// A "today"/"yesterday" chip label for [viewedDate] relative to [today], or
/// `null` for any other day (which shows just the date, no chip).
String? _dayChipLabel(AppLocalizations loc, DateTime viewedDate, DateTime today) {
  final diff = daysBetween(viewedDate, today);
  if (diff == 0) return loc.dietDayToday;
  if (diff == 1) return loc.dietDayYesterday;
  return null;
}

/// The shared day header at the top of every daily tracker (diet, water,
/// vitals, bowel, exercise): a mascot + today/history title row above a
/// `‹ [chip] date 📅 ›` day selector. Tapping the date (or its label) opens
/// [onOpenCalendar] — the diet module's rich logged-days month calendar, or a
/// plain bounded date picker for the simpler trackers. [onNext] is `null` on
/// today (disabling the "next day" arrow).
///
/// Extracted from the diet shell's original `_DayNavBar` so all trackers share
/// one date-selection design (the date shows in the selector itself, not just
/// in a content card). The date sits on its own full-width row so it isn't
/// squeezed to an ellipsis on narrow phones.
class TrackerDayNavHeader extends StatelessWidget {
  final DateTime viewedDate;
  final DateTime today;
  final String todayTitle;
  final String historyTitle;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOpenCalendar;

  const TrackerDayNavHeader({
    super.key,
    required this.viewedDate,
    required this.today,
    required this.todayTitle,
    required this.historyTitle,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isToday = daysBetween(viewedDate, today) == 0;
    final title = isToday ? todayTitle : historyTitle;
    final chipLabel = _dayChipLabel(loc, viewedDate, today);
    final dateText = fullDateLabel(context, viewedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Mascot(size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: const Key('day-nav-previous'),
              tooltip: loc.dietDayPrevTooltip,
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Tooltip(
                message: loc.dietCalendarOpenTooltip,
                child: Semantics(
                  button: true,
                  child: InkWell(
                    key: const Key('day-nav-label'),
                    onTap: onOpenCalendar,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Row(
                        // Centre the [chip · date · calendar] group between the
                        // prev/next arrows rather than letting it hug the left.
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (chipLabel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                chipLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // Ellipsize only as a last resort — with the date on
                          // its own full-width row it normally shows in full.
                          Flexible(
                            child: Text(
                              dateText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.calendar_month,
                            size: 16,
                            color: theme.colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('day-nav-next'),
              tooltip: loc.dietDayNextTooltip,
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
