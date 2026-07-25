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
/// slots, [full] when every slot is done, [partial] when some (but not all)
/// slots are done, [missed] when nothing is done and nothing is left
/// actionable — either a slot was explicitly marked missed, or every slot is
/// done/skipped with none still pending/overdue (this includes an
/// all-skipped day, not only an all-missed one) — and [upcoming] when
/// nothing is done yet but at least one slot is still pending/overdue, i.e.
/// nothing has actually failed yet. [upcoming] is what keeps *today's* cell
/// from reading as missed every morning before anything is due — the
/// backend already marks past unanswered slots as `missed` by the time the
/// day is over, so a day stuck with pending/overdue slots is (almost
/// always) today, not a stale unanswered day. Only [CareTodayStatus.done]
/// counts as done — skipped/missed/pending/overdue do not.
enum CareDayState { full, partial, missed, upcoming, noSchedule }

/// The day-state legend classification for [day]. A pure function of
/// [CareHistoryDay.slots] — see [CareDayState] for each state's meaning.
CareDayState careDayState(CareHistoryDay day) {
  if (day.slots.isEmpty) return CareDayState.noSchedule;
  final doneCount = day.slots
      .where((s) => s.status == CareTodayStatus.done)
      .length;
  if (doneCount == day.slots.length) return CareDayState.full;
  if (doneCount > 0) return CareDayState.partial;
  final hasMissedSlot = day.slots.any(
    (s) => s.status == CareTodayStatus.missed,
  );
  final hasNotYetDueSlot = day.slots.any(
    (s) =>
        s.status == CareTodayStatus.pending ||
        s.status == CareTodayStatus.overdue,
  );
  if (hasMissedSlot || !hasNotYetDueSlot) return CareDayState.missed;
  return CareDayState.upcoming;
}

/// The headline summary for a history range: [adherenceRate] is the total
/// done slots over the total *due* slots across [days] — slots still
/// pending/overdue (not yet due) are excluded from the denominator so a
/// morning with nothing logged yet doesn't read as a 0% rate (`null` when
/// there are no due slots at all — done is always a subset of due slots, so
/// this never needs clamping); [daysWithDose] counts days with at least one
/// done slot; [missedCount] sums slots whose *status* is
/// [CareTodayStatus.missed] (distinct from the day-state "missed" in
/// [CareDayState], which also covers all-skipped days); [totalScheduled] is
/// the total slot count, including not-yet-due ones (a different metric
/// from the rate's denominator).
class CareHistorySummary {
  final double? adherenceRate;
  final int daysWithDose;
  final int missedCount;
  final int totalScheduled;

  const CareHistorySummary({
    required this.adherenceRate,
    required this.daysWithDose,
    required this.missedCount,
    required this.totalScheduled,
  });
}

/// Derives [CareHistorySummary] from [days]. A pure function — see the
/// field docs on [CareHistorySummary] for each derivation.
CareHistorySummary careHistorySummary(List<CareHistoryDay> days) {
  var doneSum = 0;
  var dueSum = 0;
  var slotsSum = 0;
  var daysWithDose = 0;
  var missedCount = 0;
  for (final day in days) {
    final doneInDay = day.slots
        .where((s) => s.status == CareTodayStatus.done)
        .length;
    final dueInDay = day.slots
        .where(
          (s) =>
              s.status != CareTodayStatus.pending &&
              s.status != CareTodayStatus.overdue,
        )
        .length;
    doneSum += doneInDay;
    dueSum += dueInDay;
    slotsSum += day.slots.length;
    if (doneInDay > 0) daysWithDose++;
    missedCount += day.slots
        .where((s) => s.status == CareTodayStatus.missed)
        .length;
  }
  return CareHistorySummary(
    adherenceRate: dueSum == 0 ? null : doneSum / dueSum,
    daysWithDose: daysWithDose,
    missedCount: missedCount,
    totalScheduled: slotsSum,
  );
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

  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  });
}
