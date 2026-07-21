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

/// The full, always-shown date text, formatted per the active locale:
/// `M月d日 EEEE` for Chinese (e.g. "7月19日 星期六"), `EEE, MMM d` otherwise
/// (e.g. "Sat, Jul 19"). Shared by the diet shell header and the water screen.
String fullDateLabel(BuildContext context, DateTime viewedDate) {
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  final pattern = languageTag.startsWith('zh') ? 'M月d日 EEEE' : 'EEE, MMM d';
  return DateFormat(pattern, languageTag).format(viewedDate);
}
