import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/date/day_format.dart';
import '../domain/care_history_period.dart';

const _spanKey = 'care_history_period_span';
const _fromKey = 'care_history_period_from';
const _toKey = 'care_history_period_to';

/// The spans the period selector offers. A stored value outside this set
/// would leave the `SegmentedButton` with nothing selected, so it is treated
/// as absent instead.
const _allowedSpans = {7, 30, 90};

/// Persists the care-history screen's chosen **period** across launches
/// (mirrors `ThemeController`: constructor-injected [SharedPreferences],
/// read synchronously at construction).
///
/// Deliberately only the period. The item/category/status filter is *not*
/// persisted: a filter restored days later would silently hide most of the
/// list for a user who no longer remembers setting it, which reads as lost
/// data rather than as a filter.
///
/// Every read validates: an unrecognized span, an unparseable date, or a
/// range wider than the backend accepts is ignored rather than restored, so
/// a prefs file written by another version can't wedge the screen on a
/// period that only ever errors.
class CareHistoryFilterStore {
  final SharedPreferences _prefs;

  CareHistoryFilterStore(this._prefs);

  /// The stored period, or `null` when nothing valid is stored (the caller
  /// keeps its own default).
  CareHistoryPeriod? readPeriod() {
    final span = _prefs.getInt(_spanKey);
    if (span != null) {
      return _allowedSpans.contains(span) ? CareHistoryPeriod.span(span) : null;
    }
    final from = _prefs.getString(_fromKey);
    final to = _prefs.getString(_toKey);
    if (from == null || to == null) return null;
    final fromDate = tryParseDayString(from);
    final toDate = tryParseDayString(to);
    if (fromDate == null || toDate == null) return null;
    final length = daysBetween(fromDate, toDate) + 1;
    if (length < 1 || length > careHistoryMaxRangeDays) return null;
    return CareHistoryPeriod.custom(from, to);
  }

  /// Stores [period], clearing the keys belonging to the other kind — a
  /// leftover span would otherwise win over a newly picked custom range on
  /// the next launch.
  Future<void> writePeriod(CareHistoryPeriod period) async {
    switch (period) {
      case CareHistorySpanPeriod(:final days):
        await _prefs.setInt(_spanKey, days);
        await _prefs.remove(_fromKey);
        await _prefs.remove(_toKey);
      case CareHistoryCustomPeriod(:final from, :final to):
        await _prefs.remove(_spanKey);
        await _prefs.setString(_fromKey, from);
        await _prefs.setString(_toKey, to);
    }
  }
}
