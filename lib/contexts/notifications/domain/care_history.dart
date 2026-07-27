import 'care_today.dart';

/// A single day's care slots within a history range — [slots] reuses the
/// existing [CareTodaySlot] (the backend's `/api/care/range` serializes each
/// slot the same way `/api/care/today` does), not a redefined shape.
class CareHistoryDay {
  final String date;
  final List<CareTodaySlot> slots;

  const CareHistoryDay({required this.date, required this.slots});
}

/// A day's adherence state, purely derived from its slots (mirrors
/// CareFlow's `calcMedicationAdherence`): [noSchedule] when the day has no
/// slots. Among days with slots, a slot is either *due*
/// ([CareTodayStatus.done]/`skipped`/`missed`/`overdue` — `overdue` means
/// past due with no record, i.e. genuinely late, not "not yet due") or
/// *not yet due* ([CareTodayStatus.pending] only). [full] is every due slot
/// done (any remaining slots are merely pending, so nothing has actually
/// fallen short — this keeps the day state consistent with the rate in
/// [careHistorySummary], which excludes pending from its denominator the
/// same way); [partial] is some but not all due slots done; [missed] is at
/// least one due slot and none of them done (this includes an all-skipped
/// or all-overdue day, not only an all-explicitly-missed one); [upcoming]
/// is no due slots at all — every slot is still pending — which is what
/// keeps *today's* cell from reading as missed every morning before
/// anything is due. Only [CareTodayStatus.done] counts as done —
/// skipped/missed/pending/overdue do not.
enum CareDayState { full, partial, missed, upcoming, noSchedule }

/// The day-state legend classification for [day]. A pure function of
/// [CareHistoryDay.slots] — see [CareDayState] for each state's meaning.
CareDayState careDayState(CareHistoryDay day) {
  if (day.slots.isEmpty) return CareDayState.noSchedule;
  final doneCount = day.slots
      .where((s) => s.status == CareTodayStatus.done)
      .length;
  // "Due" is everything except still-pending slots — mirrors
  // careHistorySummary's denominator so the day state and the rate always
  // tell the same story about the same day.
  final dueCount = day.slots
      .where((s) => s.status != CareTodayStatus.pending)
      .length;
  if (dueCount == 0) return CareDayState.upcoming;
  if (doneCount == dueCount) return CareDayState.full;
  if (doneCount == 0) return CareDayState.missed;
  return CareDayState.partial;
}

/// The headline summary for a history range: [adherenceRate] is the total
/// done slots over the total *due* slots across [days] — slots still
/// pending (not yet due) are excluded from the denominator so a morning
/// with nothing logged yet doesn't read as a 0% rate, but `overdue` slots
/// (past due with no record — genuinely late) are included and drag the
/// rate down like any other unfulfilled slot (`null` when there are no due
/// slots at all — done is always a subset of due slots, so this never needs
/// clamping); [daysWithDose] counts days with at least one
/// done slot; [missedCount] sums slots whose *status* is
/// [CareTodayStatus.missed] (distinct from the day-state "missed" in
/// [CareDayState], which also covers all-skipped days).
class CareHistorySummary {
  final double? adherenceRate;
  final int daysWithDose;
  final int missedCount;

  const CareHistorySummary({
    required this.adherenceRate,
    required this.daysWithDose,
    required this.missedCount,
  });
}

/// Derives [CareHistorySummary] from [days]. A pure function — see the
/// field docs on [CareHistorySummary] for each derivation.
CareHistorySummary careHistorySummary(List<CareHistoryDay> days) {
  var doneSum = 0;
  var dueSum = 0;
  var daysWithDose = 0;
  var missedCount = 0;
  for (final day in days) {
    final doneInDay = day.slots
        .where((s) => s.status == CareTodayStatus.done)
        .length;
    final dueInDay = day.slots
        .where((s) => s.status != CareTodayStatus.pending)
        .length;
    doneSum += doneInDay;
    dueSum += dueInDay;
    if (doneInDay > 0) daysWithDose++;
    missedCount += day.slots
        .where((s) => s.status == CareTodayStatus.missed)
        .length;
  }
  return CareHistorySummary(
    adherenceRate: dueSum == 0 ? null : doneSum / dueSum,
    daysWithDose: daysWithDose,
    missedCount: missedCount,
  );
}

/// The count of days in [days] falling into each [CareDayState] — every
/// state is present in the result, defaulting to 0 (never a sparse map), so
/// a legend can read each state's count directly. A pure function of
/// [careDayState] applied per day.
Map<CareDayState, int> careDayStateCounts(List<CareHistoryDay> days) {
  final counts = {for (final state in CareDayState.values) state: 0};
  for (final day in days) {
    final state = careDayState(day);
    counts[state] = counts[state]! + 1;
  }
  return counts;
}

/// Whether every day in [days] has no scheduled slots — the backend's
/// `days` array is dense (one entry per calendar date, `items: []` when
/// nothing is scheduled), so `days.isEmpty` is never true; this is the real
/// empty-state check.
bool careHistoryIsEmpty(List<CareHistoryDay> days) =>
    days.every((d) => d.slots.isEmpty);

/// Port for the backend's `/api/care/range` (read) and `/api/care/log`
/// (write) endpoints. [editSlot] is a `PUT` that overwrites a slot's
/// outcome — distinct in semantics from [CareTodayRepository.logSlot]
/// (`POST`), so it gets its own port rather than reusing that one.
abstract class CareHistoryRepository {
  Future<List<CareHistoryDay>> getRange(String idToken, String from, String to);

  /// [doneTime], when given, overwrites the slot's completion instant —
  /// omitted (not sent as `null`) when absent, per the backend's "unspecified
  /// = don't touch this field" semantics. Never sent when [status] is
  /// [CareLogStatus.skipped], even if the caller passes one.
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
    DateTime? doneTime,
  });
}
