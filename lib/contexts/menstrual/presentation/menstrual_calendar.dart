import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/date/month_grid.dart';
import '../../../shared/widgets/month_picker_dialog.dart';
import '../../../shared/widgets/shrink_to_fit_text.dart';
import '../domain/menstrual_period.dart';

/// Strips the time-of-day, keeping only the calendar date.
DateTime menstrualDateOnly(DateTime time) =>
    DateTime(time.year, time.month, time.day);

String _dayString(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Which day of its period [day] is — the period's `startDate` is day 1 — or
/// null when no period covers it. A closed period covers
/// `[startDate, endDate]`; an open period (no end date) covers
/// `[startDate, today]`.
///
/// Where several periods cover [day], the count comes from the one with the
/// largest `startDate`, the same tie-break `computeNextPeriodStatus` applies
/// for the overview card — the two must never disagree about a day. The rule
/// is duplicated rather than shared because the domain function answers only
/// about today and returns a card state, not a per-date number.
///
/// Uncapped on purpose: an open period reading "41" is the signal that it was
/// never closed.
int? menstrualCycleDay(
  DateTime day,
  List<MenstrualPeriod> periods,
  DateTime today,
) {
  final d = menstrualDateOnly(day);
  final todayOnly = menstrualDateOnly(today);
  DateTime? covering;
  for (final period in periods) {
    final start = menstrualDateOnly(period.startDate);
    final end = period.endDate == null
        ? todayOnly
        : menstrualDateOnly(period.endDate!);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    if (covering == null || start.isAfter(covering)) covering = start;
  }
  if (covering == null) return null;
  // Anchored in UTC before subtracting so a DST transition inside the range
  // cannot shave the count by a day.
  return DateTime.utc(d.year, d.month, d.day)
          .difference(DateTime.utc(covering.year, covering.month, covering.day))
          .inDays +
      1;
}

/// Whether [day] falls within any of [periods]' inclusive ranges, with the
/// same range rules as [menstrualCycleDay].
bool isMenstrualPeriodDay(
  DateTime day,
  List<MenstrualPeriod> periods,
  DateTime today,
) => menstrualCycleDay(day, periods, today) != null;

/// Whether [day] is the predicted next start date in [stats].
bool isPredictedNextStart(DateTime day, MenstrualStats stats) {
  final predicted = stats.predictedNextStart;
  if (predicted == null) return false;
  return menstrualDateOnly(day) == menstrualDateOnly(predicted);
}

/// A month grid (Sunday-first) that marks each recorded period's days and the
/// predicted next start with a distinct marker, with previous/next month
/// navigation. Tapping a day calls [onDayTap]; a null [onDayTap] renders the
/// day cells non-interactive (used while a mutation is in flight). Colors come from
/// [Theme.of(context)] only. Mirrors the diet shell's calendar rendering, kept
/// separate so the diet calendar's behavior is untouched.
class MenstrualCalendar extends StatefulWidget {
  final MenstrualOverview overview;

  /// Returns the current time, used to resolve "today" (and to bound an open
  /// period's marked range). Defaults to [DateTime.now]; tests inject a fixed
  /// clock.
  final DateTime Function() clock;

  final void Function(DateTime day)? onDayTap;

  const MenstrualCalendar({
    super.key,
    required this.overview,
    required this.onDayTap,
    this.clock = DateTime.now,
  });

  @override
  State<MenstrualCalendar> createState() => _MenstrualCalendarState();
}

class _MenstrualCalendarState extends State<MenstrualCalendar> {
  late DateTime _visibleMonth = DateTime(
    widget.clock().year,
    widget.clock().month,
  );

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  /// No first/last bound, matching the ‹ › arrows (which have none either), so
  /// nothing reachable by stepping is unreachable by jumping.
  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(context, initialMonth: _visibleMonth);
    if (picked == null || !mounted) return;
    setState(() => _visibleMonth = DateTime(picked.year, picked.month));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final today = menstrualDateOnly(widget.clock());
    final periods = widget.overview.periods;
    final stats = widget.overview.stats;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('menstrual-prev-month'),
              tooltip: loc.menstrualPrevMonth,
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              // The key stays on the `Text`; the tappable wrapper goes outside
              // it.
              child: Tooltip(
                message: loc.monthPickerOpenTooltip,
                child: Semantics(
                  button: true,
                  child: InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      // The `▾` is the visible clue that the label opens the
                      // picker — same affordance as the other three entries.
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // `Flexible` + `ShrinkToFitText` so the label gives
                          // way to the `▾` instead of overflowing on a 320dp
                          // phone — by *scaling*, not ellipsizing: an
                          // ellipsis silently ate the month digits
                          // (`2026年7月` → `202…`) once the user turned their
                          // system font size up. Same treatment as the other
                          // three month-label entries.
                          Flexible(
                            child: ShrinkToFitText(
                              text: monthYearLabel(context, _visibleMonth),
                              textKey: const Key('menstrual-month-label'),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('menstrual-next-month'),
              tooltip: loc.menstrualNextMonth,
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    MaterialLocalizations.of(context).narrowWeekdays[i],
                    key: Key('menstrual-weekday-$i'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final week in monthWeeks(_visibleMonth))
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: day == null
                      ? const SizedBox(height: 44)
                      : _MenstrualDayCell(
                          date: DateTime(
                            _visibleMonth.year,
                            _visibleMonth.month,
                            day,
                          ),
                          today: today,
                          cycleDay: menstrualCycleDay(
                            DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month,
                              day,
                            ),
                            periods,
                            today,
                          ),
                          isPredicted: isPredictedNextStart(
                            DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month,
                              day,
                            ),
                            stats,
                          ),
                          onTap: widget.onDayTap,
                        ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        // A `Wrap`, not a `Row`: the entries together are wider than a
        // 320dp phone in English, and wider still at a large text scale —
        // where a single entry alone no longer fits on one line, hence the
        // shrinkable label inside `_LegendItem` as well.
        Wrap(
          key: const Key('menstrual-legend'),
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 8,
          children: [
            _LegendItem(filled: true, label: loc.menstrualLegendPeriod),
            _LegendItem(filled: false, label: loc.menstrualLegendPredicted),
            _LegendItem(
              filled: true,
              markerLabel: '1',
              label: loc.menstrualLegendCycleDay,
            ),
          ],
        ),
      ],
    );
  }
}

/// One entry in the calendar legend: a small marker matching the day-cell
/// styling (filled circle for a period day, outline ring for the predicted
/// next start) followed by its [label]. Colors come from [Theme.of(context)].
class _LegendItem extends StatelessWidget {
  final bool filled;

  /// Digits drawn inside the marker, for the entry that explains the cycle-day
  /// number. Null for the entries whose marker is the whole point.
  final String? markerLabel;

  final String label;

  const _LegendItem({
    required this.filled,
    required this.label,
    this.markerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? theme.colorScheme.primary : null,
            border: filled
                ? null
                : Border.all(color: theme.colorScheme.primary, width: 2),
          ),
          child: markerLabel == null
              ? null
              : Text(
                  markerLabel!,
                  textScaler: TextScaler.noScaling,
                  style: theme.textTheme.labelSmall?.copyWith(
                    height: 1,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        // Wraps onto a second line rather than pushing the row past the
        // screen: at a 2x text scale one entry is wider than a 320dp phone.
        //
        // Loose, and unlike the label/value rows elsewhere it must stay that
        // way — not because `Expanded` would fail (the `Wrap` above hands
        // each entry a bounded width, so it lays out fine) but because it
        // would stretch every entry to a full line, leaving the `Wrap`'s
        // `WrapAlignment.center` nothing to centre.
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// A single day cell in [MenstrualCalendar]: a filled primary circle when the
/// day is a period day, a primary outline ring when it is the predicted next
/// start (distinct from a period day), and a plain number otherwise. Colors
/// come from [Theme.of(context)] only.
class _MenstrualDayCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;

  /// Which day of its period this is (start date = day 1), or null when the
  /// day belongs to no period — which is also what makes it a period day.
  final int? cycleDay;

  final bool isPredicted;
  final void Function(DateTime day)? onTap;

  const _MenstrualDayCell({
    required this.date,
    required this.today,
    required this.cycleDay,
    required this.isPredicted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dayString = _dayString(date);
    final isToday = menstrualDateOnly(date) == today;
    final dateLabel = mediumDateLabel(context, date);

    final String semanticLabel;
    if (cycleDay != null) {
      semanticLabel = loc.menstrualDaySemanticPeriod(dateLabel, cycleDay!);
    } else if (isPredicted) {
      semanticLabel = loc.menstrualDaySemanticPredicted(dateLabel);
    } else if (isToday) {
      semanticLabel = loc.menstrualDaySemanticToday(dateLabel);
    } else {
      semanticLabel = dateLabel;
    }

    final textColor = cycleDay != null
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return InkWell(
      key: Key('menstrual-day-$dayString'),
      onTap: onTap == null ? null : () => onTap!(date),
      child: Semantics(
        label: semanticLabel,
        button: true,
        enabled: onTap != null,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              // Two stacked lines total ~23dp at scale 1.0 and pass the 32dp
              // circle just past 1.3x, so the marker — and only the marker,
              // not the legend or the statistics — caps the scale there
              // rather than overflowing or growing the circle and breaking
              // the 44dp row rhythm every calendar in the app shares. The
              // uncapped number stays available through the semantic label
              // above.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Container(
                  key: Key('menstrual-day-marker-$dayString'),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cycleDay != null ? theme.colorScheme.primary : null,
                    border: isPredicted
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : (isToday
                              ? Border.all(
                                  color: theme.colorScheme.outline,
                                  width: 1,
                                )
                              : null),
                  ),
                  child: cycleDay == null
                      ? Text(
                          '${date.day}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${date.day}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '$cycleDay',
                              style: theme.textTheme.labelSmall?.copyWith(
                                height: 1,
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
