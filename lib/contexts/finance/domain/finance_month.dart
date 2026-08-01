/// Pure `YYYY-MM` string month arithmetic for the finance ledger, and so
/// inherently `TZ=UTC flutter test`-safe. The invariant that buys that is
/// **no function here ever reads the ambient clock or converts between time
/// zones**: every result is derived from the digits of the input string, or —
/// for [monthStringOf] — from the calendar fields of the input [DateTime].
///
/// Two functions do build a [DateTime], and both are safe for the same
/// reason — the fields go straight in from the parsed string and only ever
/// come back out as calendar fields, with no instant-to-instant conversion
/// in between, so the zone the fields are interpreted in cannot shift them:
///
/// - [_daysInMonth] uses `DateTime.utc` purely as a calendar table.
/// - [monthDateTime] uses the local-time constructor `DateTime(y, m)`
///   because its caller formats it with a locale-aware month formatter,
///   which reads `year`/`month` back off the same fields.
///
/// Verified under UTC, UTC+8, UTC+14 and UTC-11. If you ever add a function
/// that subtracts two `DateTime`s, calls `toUtc`/`toLocal`, or touches
/// `DateTime.now()`, this file stops being zone-agnostic — don't.
library;

/// The `YYYY-MM` month containing [date] (a `YYYY-MM-DD` string).
String monthOf(String date) => date.substring(0, 7);

/// The `YYYY-MM-DD` first day of [month] (`YYYY-MM`).
String monthStart(String month) => '$month-01';

/// The `YYYY-MM-DD` last day of [month] (`YYYY-MM`), accounting for the
/// actual days in that month (leap years included).
String monthEnd(String month) {
  final (year, monthNum) = _parse(month);
  final days = _daysInMonth(year, monthNum);
  return '$month-${days.toString().padLeft(2, '0')}';
}

/// The `YYYY-MM` month after [month], rolling into the next year at
/// December.
String nextMonth(String month) {
  final (year, monthNum) = _parse(month);
  return monthNum == 12 ? _format(year + 1, 1) : _format(year, monthNum + 1);
}

/// The `YYYY-MM` month before [month], rolling back into the previous year
/// at January.
String previousMonth(String month) {
  final (year, monthNum) = _parse(month);
  return monthNum == 1 ? _format(year - 1, 12) : _format(year, monthNum - 1);
}

/// [month] (`YYYY-MM`) as the first day of that month, for locale-aware
/// formatting (`monthYearLabel`). The fields come straight from the string
/// and are only ever read back as year/month, so the local-time constructor
/// can't shift the month.
DateTime monthDateTime(String month) {
  final (year, monthNum) = _parse(month);
  return DateTime(year, monthNum);
}

/// The `YYYY-MM` month [date] falls in — the inverse of [monthDateTime], for
/// turning a month picked in the UI back into the ledger's wire format. Only
/// the year and month *fields* are read (no instant conversion), so the zone
/// they were built in can't shift the result.
String monthStringOf(DateTime date) => _format(date.year, date.month);

(int, int) _parse(String month) {
  final parts = month.split('-');
  return (int.parse(parts[0]), int.parse(parts[1]));
}

String _format(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

int _daysInMonth(int year, int month) {
  final nextMonthFirstDay = month == 12
      ? DateTime.utc(year + 1, 1, 1)
      : DateTime.utc(year, month + 1, 1);
  return nextMonthFirstDay.subtract(const Duration(days: 1)).day;
}
