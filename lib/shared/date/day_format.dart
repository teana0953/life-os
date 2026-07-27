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
