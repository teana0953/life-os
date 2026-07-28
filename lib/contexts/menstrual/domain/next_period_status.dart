import 'menstrual_period.dart';

/// Which of the six things the overview's next-period card has to say.
enum NextPeriodState {
  /// Today falls inside a recorded period. Takes precedence over everything
  /// else — including an overdue prediction.
  ongoing,

  /// Nothing recorded at all. Distinct from [needsOneMore]: one more recording
  /// still yields no prediction, so promising one here would be a lie.
  noRecords,

  /// Exactly one period recorded — a cycle length needs two.
  needsOneMore,

  /// The predicted next start is later than today.
  upcoming,

  /// The predicted next start is today.
  today,

  /// The predicted next start has passed. Never rolled forward into the
  /// future: a stale date is the signal that recording has lapsed.
  overdue,
}

/// What the overview says about the next period: the [state], the day count
/// that goes with it, and the predicted next start when there is one.
///
/// [days] means the day *of* the ongoing period (the start day is day 1) for
/// [NextPeriodState.ongoing], the days until the prediction for
/// [NextPeriodState.upcoming], and the days since it for
/// [NextPeriodState.overdue]. It is null for the remaining states.
///
/// [predictedNextStart] is null whenever the backend derived no prediction —
/// including while a period is ongoing, which is exactly the state of someone
/// recording for the first time. Nothing may assume it is non-null.
class NextPeriodStatus {
  final NextPeriodState state;
  final int? days;
  final DateTime? predictedNextStart;

  const NextPeriodStatus({
    required this.state,
    this.days,
    this.predictedNextStart,
  });
}

/// The number of calendar days from [from] to [to]. Both are stripped to their
/// date components and anchored in UTC first: the recorded dates are local
/// midnights while the clock carries a time of day, so subtracting them
/// directly would lose a whole day every afternoon (and a DST transition would
/// shift the rest). Mirrors `shared/date/day_format.dart`'s `daysBetween`,
/// duplicated rather than imported to keep this domain file free of the
/// Flutter dependency that file carries.
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// Reads [overview] as of [today] into the one thing the overview card says.
///
/// The branch order is the priority order: an ongoing period first (with the
/// prediction alongside it, when there is one), then the two "not enough data"
/// states, then the prediction relative to today.
NextPeriodStatus computeNextPeriodStatus(
  MenstrualOverview overview,
  DateTime today,
) {
  final predicted = overview.stats.predictedNextStart;

  // Scan every period, not just `lastPeriod` (which is the largest *start*
  // date): a back-filled period that starts earlier and ends later is the one
  // covering today, and the tracker's calendar marks today from all of them.
  MenstrualPeriod? ongoing;
  for (final period in overview.periods) {
    final end = period.endDate;
    final started = _daysBetween(period.startDate, today) >= 0;
    final notEnded = end == null || _daysBetween(today, end) >= 0;
    if (!started || !notEnded) continue;
    if (ongoing == null ||
        _daysBetween(ongoing.startDate, period.startDate) > 0) {
      ongoing = period;
    }
  }

  if (ongoing != null) {
    return NextPeriodStatus(
      state: NextPeriodState.ongoing,
      // The start day is day 1, and the count is deliberately uncapped: a
      // period left open long ago reading "day 45" is what says it was never
      // closed.
      days: _daysBetween(ongoing.startDate, today) + 1,
      predictedNextStart: predicted,
    );
  }

  if (predicted == null) {
    return NextPeriodStatus(
      state: overview.periods.isEmpty
          ? NextPeriodState.noRecords
          : NextPeriodState.needsOneMore,
    );
  }

  final delta = _daysBetween(today, predicted);
  if (delta > 0) {
    return NextPeriodStatus(
      state: NextPeriodState.upcoming,
      days: delta,
      predictedNextStart: predicted,
    );
  }
  if (delta == 0) {
    return NextPeriodStatus(
      state: NextPeriodState.today,
      predictedNextStart: predicted,
    );
  }
  return NextPeriodStatus(
    state: NextPeriodState.overdue,
    days: -delta,
    predictedNextStart: predicted,
  );
}
