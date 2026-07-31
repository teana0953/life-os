/// Pure `YYYY-MM` string month arithmetic for the finance ledger. Every
/// function here is integer/string math (`DateTime.utc` is used only as a
/// days-in-month helper, never `DateTime.now()` or local-time construction),
/// so this file is inherently `TZ=UTC flutter test`-safe.
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
