import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/date/month_grid.dart';
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

/// Whether [day] falls within any of [periods]' inclusive ranges. A closed
/// period covers `[startDate, endDate]`; an open period (no end date) covers
/// `[startDate, today]`.
bool isMenstrualPeriodDay(
  DateTime day,
  List<MenstrualPeriod> periods,
  DateTime today,
) {
  final d = menstrualDateOnly(day);
  final todayOnly = menstrualDateOnly(today);
  for (final period in periods) {
    final start = menstrualDateOnly(period.startDate);
    final end = period.endDate == null
        ? todayOnly
        : menstrualDateOnly(period.endDate!);
    if (!d.isBefore(start) && !d.isAfter(end)) return true;
  }
  return false;
}

/// Whether [day] is the predicted next start date in [stats].
bool isPredictedNextStart(DateTime day, MenstrualStats stats) {
  final predicted = stats.predictedNextStart;
  if (predicted == null) return false;
  return menstrualDateOnly(day) == menstrualDateOnly(predicted);
}

/// A month grid (Sunday-first) that marks each recorded period's days and the
/// predicted next start with a distinct marker, with previous/next month
/// navigation. Tapping a day calls [onDayTap]. Colors come from
/// [Theme.of(context)] only. Mirrors the diet shell's calendar rendering, kept
/// separate so the diet calendar's behavior is untouched.
class MenstrualCalendar extends StatefulWidget {
  final MenstrualOverview overview;

  /// Returns the current time, used to resolve "today" (and to bound an open
  /// period's marked range). Defaults to [DateTime.now]; tests inject a fixed
  /// clock.
  final DateTime Function() clock;

  final void Function(DateTime day) onDayTap;

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
              child: Text(
                monthYearLabel(context, _visibleMonth),
                key: const Key('menstrual-month-label'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
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
                          isPeriod: isMenstrualPeriodDay(
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
        Row(
          key: const Key('menstrual-legend'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(filled: true, label: loc.menstrualLegendPeriod),
            const SizedBox(width: 20),
            _LegendItem(filled: false, label: loc.menstrualLegendPredicted),
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
  final String label;

  const _LegendItem({required this.filled, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? theme.colorScheme.primary : null,
            border: filled
                ? null
                : Border.all(color: theme.colorScheme.primary, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
  final bool isPeriod;
  final bool isPredicted;
  final void Function(DateTime day) onTap;

  const _MenstrualDayCell({
    required this.date,
    required this.today,
    required this.isPeriod,
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
    if (isPeriod) {
      semanticLabel = loc.menstrualDaySemanticPeriod(dateLabel);
    } else if (isPredicted) {
      semanticLabel = loc.menstrualDaySemanticPredicted(dateLabel);
    } else if (isToday) {
      semanticLabel = loc.menstrualDaySemanticToday(dateLabel);
    } else {
      semanticLabel = dateLabel;
    }

    final Color textColor;
    if (isPeriod) {
      textColor = theme.colorScheme.onPrimary;
    } else {
      textColor = theme.colorScheme.onSurface;
    }

    return InkWell(
      key: Key('menstrual-day-$dayString'),
      onTap: () => onTap(date),
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Container(
                key: Key('menstrual-day-marker-$dayString'),
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPeriod ? theme.colorScheme.primary : null,
                  border: isPredicted
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : (isToday
                            ? Border.all(
                                color: theme.colorScheme.outline,
                                width: 1,
                              )
                            : null),
                ),
                child: Text(
                  '${date.day}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
