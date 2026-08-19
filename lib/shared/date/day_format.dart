import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The number of calendar days from [from] to [to] (both already date-only).
/// Anchored in UTC rather than computed via `to.difference(from).inDays` on
/// local `DateTime`s: two local midnights straddling a DST transition aren't
/// always exactly 24h apart, which would truncate `.inDays` to the wrong
/// count. UTC has no DST, so this always reflects the true calendar-day gap.
int daysBetween(DateTime from, DateTime to) {
  final fromUtc = DateTime.utc(from.year, from.month, from.day);
  final toUtc = DateTime.utc(to.year, to.month, to.day);
  return toUtc.difference(fromUtc).inDays;
}

/// The `YYYY-MM-DD` calendar-date string for [date] (its date components).
String dayString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// The `from`/`to` `YYYY-MM-DD` range for [spanDays] ending [now] (inclusive
/// of today) — anchored in UTC like [daysBetween] so a DST boundary can't
/// shift the span by a day.
({String from, String to}) dayRangeEndingOn(int spanDays, DateTime now) {
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  final fromUtc = todayUtc.subtract(Duration(days: spanDays - 1));
  return (from: dayString(fromUtc), to: dayString(todayUtc));
}

/// Parses a `YYYY-MM-DD` calendar-date string into a local, date-only
/// [DateTime] — the inverse of [dayString].
DateTime parseDayString(String s) {
  final parts = s.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// [parseDayString], but `null` for a malformed string instead of throwing
/// (design D4) — for the backend-sourced date strings the app can't fully
/// trust to be the dense, well-formed shape the API contract promises.
///
/// Shape and integer checks alone are not enough: [DateTime]'s constructor
/// silently *rolls over* out-of-range components, so `'0000-00-00'` would
/// become 1999-11-30 and `'2026-13-45'` 2027-02-14 — a wrong-but-plausible
/// date the caller then treats as known and files records under, which is
/// exactly the failure D4 exists to prevent (harder to spot than a crash).
/// The round-trip against [dayString] rejects those, and with them anything
/// else that isn't a real, canonically formatted calendar date (e.g.
/// `'2026-02-31'`).
DateTime? tryParseDayString(String s) {
  final parts = s.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  return dayString(date) == s ? date : null;
}

/// [mediumDateLabel] for a possibly-malformed `YYYY-MM-DD` string — "—" when
/// it can't be parsed (design D4), so one malformed backend record degrades
/// a single label instead of crashing the screen it's on.
String mediumDateLabelOrDash(BuildContext context, String dayString) {
  final date = tryParseDayString(dayString);
  return date == null ? '—' : mediumDateLabel(context, date);
}

/// Parses an ISO-8601 instant string (e.g. a backend `done_time`) into a
/// [DateTime] — `null` for an invalid or empty string. Pure parsing only —
/// timezone conversion (`.toLocal()`) is left to the caller so tests can
/// inject a non-identity conversion instead of relying on it here.
DateTime? parseInstant(String iso) => DateTime.tryParse(iso);

/// The full, always-shown date text, formatted per the active locale:
/// `M月d日 EEEE` for Chinese (e.g. "7月19日 星期六"), `EEE, MMM d` otherwise
/// (e.g. "Sat, Jul 19"). Shared by the diet shell header and the water screen.
String fullDateLabel(BuildContext context, DateTime viewedDate) {
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  final pattern = languageTag.startsWith('zh') ? 'M月d日 EEEE' : 'EEE, MMM d';
  return DateFormat(pattern, languageTag).format(viewedDate);
}

/// The month-and-year header text, formatted per the active locale
/// (e.g. "2026年7月" for Chinese, "Jul 2026" otherwise). `DateFormat` must be
/// given the locale explicitly — without it, it falls back to English.
String monthYearLabel(BuildContext context, DateTime month) {
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMM(languageTag).format(month);
}

/// A medium full date, formatted per the active locale (e.g. "2026年7月13日"
/// for Chinese, "Jul 13, 2026" otherwise).
String mediumDateLabel(BuildContext context, DateTime date) {
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(languageTag).format(date);
}

/// A month-and-day date without the year (e.g. "Mar 1" for English, "3月1日"
/// for Chinese) — for the care history period selector's custom segment,
/// which has to fit two dates plus a dash inside one button segment.
String monthDayLabel(BuildContext context, DateTime date) {
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.MMMd(languageTag).format(date);
}

/// A short date carrying a two-digit, apostrophe-marked year (e.g. "26'年8月
/// 14日" for Chinese, "Aug 14, 26'" otherwise) — the requested abbreviation for
/// the dashboard's menstrual prediction tile, where the four-digit year printed
/// by the full-date formats is more width than that 125–320dp tile can spend on
/// the century. Purely a presentation choice, not a fix for a missing year:
/// `MaterialLocalizations.formatShortDate` does print the year (measured:
/// "Aug 14, 2026" / "2026年8月14日"). Screens with room keep [mediumDateLabel].
/// The apostrophe is a literal inside the ICU pattern (`''` is how ICU escapes
/// one), not a post-hoc string edit.
String shortYearDateLabel(BuildContext context, DateTime date) {
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  final pattern = languageTag.startsWith('zh') ? "yy''年M月d日" : "MMM d, yy''";
  return DateFormat(pattern, languageTag).format(date);
}

/// A single narrow weekday abbreviation for [date] (e.g. "S" for Sunday in
/// English, the CLDR narrow form for Chinese), formatted per the active
/// locale — used by the care adherence heatmap's weekday header, where a
/// full weekday name wouldn't fit its capped ~24dp column (design D2/D3).
String narrowWeekdayLabel(BuildContext context, DateTime date) {
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  return DateFormat('EEEEE', languageTag).format(date);
}
