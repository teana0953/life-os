import '../../../shared/date/day_format.dart';

/// The longest range `/api/care/range` accepts — the backend rejects a wider
/// one with 400 `range must not exceed 366 days`
/// (`life-os-backend/src/adapters/http/routes/care.ts`, `MAX_RANGE_DAYS`).
/// The custom-range picker is bounded by this instead of letting the user
/// pick a range that can only come back as an error.
const careHistoryMaxRangeDays = 366;

/// The period a care-history load covers: either a rolling span of days
/// ending today ([CareHistoryPeriod.span]) or a fixed pair of dates the user
/// picked ([CareHistoryPeriod.custom]).
///
/// A value type: the controller compares the period its loaded days describe
/// against the currently selected one to detect (and repair) a mismatch, so
/// two equal periods must compare equal.
sealed class CareHistoryPeriod {
  const CareHistoryPeriod();

  const factory CareHistoryPeriod.span(int days) = CareHistorySpanPeriod;

  /// [from]/[to] are inclusive `YYYY-MM-DD` calendar dates.
  const factory CareHistoryPeriod.custom(String from, String to) =
      CareHistoryCustomPeriod;

  /// The `from`/`to` to request for this period, given the current time.
  ({String from, String to}) resolve(DateTime now);

  /// The rolling span's length in days — `null` for a custom range, which is
  /// anchored to fixed dates rather than to a length.
  int? get spanDays;

  /// The calendar days covered, counting both ends.
  int get lengthInDays;
}

class CareHistorySpanPeriod extends CareHistoryPeriod {
  final int days;

  const CareHistorySpanPeriod(this.days);

  @override
  ({String from, String to}) resolve(DateTime now) =>
      dayRangeEndingOn(days, now);

  @override
  int? get spanDays => days;

  @override
  int get lengthInDays => days;

  @override
  bool operator ==(Object other) =>
      other is CareHistorySpanPeriod && other.days == days;

  @override
  int get hashCode => Object.hash(CareHistorySpanPeriod, days);
}

class CareHistoryCustomPeriod extends CareHistoryPeriod {
  final String from;
  final String to;

  const CareHistoryCustomPeriod(this.from, this.to);

  @override
  ({String from, String to}) resolve(DateTime now) => (from: from, to: to);

  @override
  int? get spanDays => null;

  @override
  int get lengthInDays =>
      daysBetween(parseDayString(from), parseDayString(to)) + 1;

  @override
  bool operator ==(Object other) =>
      other is CareHistoryCustomPeriod && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(CareHistoryCustomPeriod, from, to);
}
