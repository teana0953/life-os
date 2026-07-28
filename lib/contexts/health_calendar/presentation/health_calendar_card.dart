import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/stale_notice.dart';
import 'health_calendar_controller.dart';

/// The dashboard's C3 card: the current month's record calendar (a dot on every
/// day with any tracker entry) plus three adherence rings — logging rate and
/// diet-adherence rate (this month) and the weight-goal achievement rate (reused
/// from the goal card). Loading and error states render inside the card;
/// `needsReauth` is left to the [HealthScaffold]. Colors come from [Theme] only.
class HealthCalendarCard extends StatefulWidget {
  final HealthCalendarController controller;
  final String idToken;

  /// The weight-goal achievement rate (0–100), reused for the third ring; null
  /// when the goal isn't set / not yet computable.
  final int? weightAchievementRate;

  const HealthCalendarCard({
    super.key,
    required this.controller,
    required this.idToken,
    required this.weightAchievementRate,
  });

  @override
  State<HealthCalendarCard> createState() => _HealthCalendarCardState();
}

class _HealthCalendarCardState extends State<HealthCalendarCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    if (controller.status == HealthCalendarStatus.loading &&
        controller.calendar == null) {
      return const LedgeCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(
              key: Key('health-calendar-loading'),
            ),
          ),
        ),
      );
    }

    // A failure with no month drawn yet → an error in place of the content
    // the card doesn't have. A failure *after* a month has been drawn keeps
    // the calendar and appends a [StaleNotice] instead (below): this is the
    // tallest card on the overview, and a failed automatic refresh removing
    // it collapses the page around the user.
    if (controller.status == HealthCalendarStatus.error &&
        controller.calendar == null) {
      return LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.healthCalendarLoadFailed,
              key: const Key('health-calendar-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('health-calendar-retry'),
              onPressed: () => controller.load(widget.idToken),
              child: Text(loc.retry),
            ),
          ],
        ),
      );
    }

    final calendar = controller.calendar!;
    final month = DateTime(calendar.year, calendar.month);
    final stale = controller.status == HealthCalendarStatus.error;
    final reloading = controller.status == HealthCalendarStatus.loading;

    // The card's padding sits on its content rather than on the [LedgeCard],
    // so the [StaleNotice] below — which brings its own, matching the other
    // three overview cards — isn't indented twice.
    return LedgeCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(loc.healthCalendarTitle, style: theme.textTheme.titleLarge),
                    ),
                    Text(
                      monthYearLabel(context, month),
                      key: const Key('health-calendar-month'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PercentRing(
                      ringKey: const Key('health-calendar-ring-logging'),
                      rate: calendar.loggingRate,
                      label: loc.healthCalendarLoggingRate,
                      noDataLabel: loc.healthCalendarNoData,
                    ),
                    _PercentRing(
                      ringKey: const Key('health-calendar-ring-diet'),
                      rate: calendar.dietAdherenceRate,
                      label: loc.healthCalendarDietRate,
                      noDataLabel: loc.healthCalendarNoData,
                    ),
                    _PercentRing(
                      ringKey: const Key('health-calendar-ring-weight'),
                      rate: widget.weightAchievementRate,
                      label: loc.healthCalendarWeightRate,
                      noDataLabel: loc.healthCalendarNoData,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MonthDots(month: month, loggedDays: calendar.loggedDays),
                const SizedBox(height: 8),
                Row(
                  key: const Key('health-calendar-legend'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      loc.healthCalendarLoggedLegend,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Kept mounted through a reload as well as a failure: the marking
          // remembers whether the reload in flight is the one it started, and
          // unmounting it mid-retry would throw that away.
          if (stale || reloading)
            StaleNotice(
              failed: stale,
              loading: reloading,
              subject: loc.healthCalendarTitle,
              onRetry: () => controller.load(widget.idToken),
            ),
        ],
      ),
    );
  }
}

/// A Sunday-first month grid; each day with an entry in [loggedDays] shows a dot.
class _MonthDots extends StatelessWidget {
  final DateTime month;
  final Set<String> loggedDays;

  const _MonthDots({required this.month, required this.loggedDays});

  /// The weeks of the month as day-of-month (or null for leading/trailing blanks).
  List<List<int?>> _weeks() {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // DateTime.sunday == 7
    final cells = <int?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var day = 1; day <= daysInMonth; day++) day,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  String _dayKey(int day) =>
      '${month.year}-${_pad(month.month)}-${_pad(day)}';

  static String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    MaterialLocalizations.of(context).narrowWeekdays[i],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final week in _weeks())
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: day == null
                        ? null
                        : _DayCell(
                            day: day,
                            logged: loggedDays.contains(_dayKey(day)),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A single day cell: the day number with a dot beneath it when logged.
class _DayCell extends StatelessWidget {
  final int day;
  final bool logged;

  const _DayCell({required this.day, required this.logged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$day',
          style: theme.textTheme.bodySmall?.copyWith(
            color: logged
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          key: logged ? Key('health-calendar-dot-$day') : null,
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: logged ? theme.colorScheme.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// A determinate ring at [rate]% with a [label] beneath. A null rate shows an
/// empty ring and no percentage (never a false number), and exposes a spoken
/// "no data" value for screen readers.
class _PercentRing extends StatelessWidget {
  final Key ringKey;
  final int? rate;
  final String label;
  final String noDataLabel;

  const _PercentRing({
    required this.ringKey,
    required this.rate,
    required this.label,
    required this.noDataLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = rate == null ? 0.0 : (rate! / 100).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label ${rate == null ? noDataLabel : '$rate%'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    key: ringKey,
                    value: value,
                    strokeWidth: 5,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                if (rate != null)
                  Text('$rate%', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
