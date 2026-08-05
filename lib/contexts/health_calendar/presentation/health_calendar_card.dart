import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/date/month_grid.dart';
import '../../../shared/widgets/card_error_retry.dart';
import '../../../shared/widgets/card_loading.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/month_nav_header.dart';
import '../../../shared/widgets/month_picker_dialog.dart';
import '../../../shared/widgets/stale_notice.dart';
import 'health_calendar_controller.dart';
import '../../../shared/auth/id_token_provider.dart';

/// The dashboard's C3 card: the current month's record calendar (a dot on every
/// day with any tracker entry) plus three adherence rings — logging rate and
/// diet-adherence rate (this month) and the weight-goal achievement rate (reused
/// from the goal card). Loading and error states render inside the card;
/// `needsReauth` is left to the [HealthScaffold]. Colors come from [Theme] only.
class HealthCalendarCard extends StatefulWidget {
  final HealthCalendarController controller;
  final IdTokenProvider idToken;

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

  Future<void> _changeMonth(int delta) async {
    final selected = widget.controller.selectedMonth;
    final target = DateTime(selected.year, selected.month + delta);
    widget.controller.loadMonth(await widget.idToken(), target.year, target.month);
  }

  Future<void> _pickMonth() async {
    // No first/last bound, matching the ‹ › arrows — nothing reachable by
    // stepping should be unreachable by jumping.
    final picked = await showMonthPicker(
      context,
      initialMonth: widget.controller.selectedMonth,
    );
    if (picked == null || !mounted) return;
    await widget.controller.loadMonth(
      await widget.idToken(),
      picked.year,
      picked.month,
    );
  }

  /// The month switcher, shown in every state — including while a month is
  /// loading and after one failed, so a switch is never a one-way trip into a
  /// card with no way back.
  Widget _monthNav(BuildContext context) => MonthNavHeader(
    monthLabel: monthYearLabel(context, widget.controller.selectedMonth),
    keyPrefix: 'health-calendar-month',
    onPrevious: () => _changeMonth(-1),
    onNext: () => _changeMonth(1),
    onPickMonth: _pickMonth,
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    if (controller.status == HealthCalendarStatus.loading &&
        controller.calendar == null) {
      return LedgeCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _monthNav(context),
            const CardLoading(indicatorKey: Key('health-calendar-loading')),
          ],
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
        child: CardErrorRetry(
          message: loc.healthCalendarLoadFailed,
          messageKey: const Key('health-calendar-error'),
          retryKey: const Key('health-calendar-retry'),
          header: [_monthNav(context)],
          onRetry: () async => controller.load(await widget.idToken()),
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
                Text(loc.healthCalendarTitle, style: theme.textTheme.titleLarge),
                // The month moved out of this row and into the switcher below:
                // the card used to be pinned to the current month, so the
                // month was a label rather than a control.
                _monthNav(context),
                const SizedBox(height: 16),
                // Each ring takes an equal third and its label wraps inside
                // it. A `Wrap` was rejected: three items at 320dp break 2+1,
                // which reads as a broken layout rather than a reflow. What
                // overflowed was never the ring (60dp fixed) but the
                // unconstrained label `Text` below it.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PercentRing(
                        ringKey: const Key('health-calendar-ring-logging'),
                        rate: calendar.loggingRate,
                        label: loc.healthCalendarLoggingRate,
                        noDataLabel: loc.healthCalendarNoData,
                      ),
                    ),
                    Expanded(
                      child: _PercentRing(
                        ringKey: const Key('health-calendar-ring-diet'),
                        rate: calendar.dietAdherenceRate,
                        label: loc.healthCalendarDietRate,
                        noDataLabel: loc.healthCalendarNoData,
                      ),
                    ),
                    Expanded(
                      child: _PercentRing(
                        ringKey: const Key('health-calendar-ring-weight'),
                        rate: widget.weightAchievementRate,
                        label: loc.healthCalendarWeightRate,
                        noDataLabel: loc.healthCalendarNoData,
                      ),
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
              onRetry: () async => controller.load(await widget.idToken()),
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
        for (final week in monthWeeks(month))
          Row(
            children: [
              for (final day in week)
                Expanded(
                  // A *minimum* height, not a fixed one: at a 2x text scale
                  // the day number alone is taller than 36dp, and a fixed box
                  // overflowed every cell in the month.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 36),
                    child: day == null
                        ? const SizedBox.shrink()
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
      mainAxisSize: MainAxisSize.min,
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
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
