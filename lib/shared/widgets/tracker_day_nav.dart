import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../date/day_format.dart';

/// Adds a browsable "viewed day" (with its day-switching app bar) to a day-keyed
/// tracker screen (water / vitals / bowel / exercise) that was previously scoped
/// to the diet shell's shared day. The host provides its initial day, clock, and
/// a per-controller reload; the mixin owns the viewed-date state, the day
/// switching, and the [TrackerDayNav] app bar.
mixin TrackerDayScreen<T extends StatefulWidget> on State<T> {
  /// The day the screen opened on (usually `widget.day`, `YYYY-MM-DD`).
  String get initialDay;

  /// Returns the current time (usually `widget.clock`).
  DateTime Function() get clock;

  /// Reloads the tracker's controller for [day] (usually
  /// `controller.load(idToken, day)`).
  void reloadDay(String day);

  late DateTime _viewedDate = DateTime.parse(initialDay);

  /// The currently viewed day as a `YYYY-MM-DD` string — use this for reads and
  /// writes so the screen always acts on the browsed day, not just today.
  String get viewedDay => dayString(_viewedDate);

  /// Switch the viewed day and reload it. The screen doesn't self-load on mount
  /// (the scaffold pre-loaded today), so only a change needs a fetch.
  void setDay(DateTime date) {
    setState(() => _viewedDate = date);
    reloadDay(viewedDay);
  }

  /// A back-able app bar (title [title]) with a day switcher below it.
  PreferredSizeWidget dayAppBar(String title) {
    final now = clock();
    return AppBar(
      title: Text(title),
      bottom: TrackerDayNav(
        viewedDate: _viewedDate,
        today: DateTime(now.year, now.month, now.day),
        onChanged: setDay,
      ),
    );
  }
}

/// A compact day switcher for a tracker screen's app bar: `‹ | <date, tap to
/// pick a day> | ›`. Used by the day-keyed trackers (water / vitals / bowel /
/// exercise) so each can browse a past day on its own, after the shared diet
/// shell (which owned the day) was replaced by the flat record hub.
///
/// [onChanged] fires with the newly selected date (date-only). The "next day"
/// control is disabled on [today]; picking opens a bounded date picker. Sits in
/// an app bar's `bottom`, so the app bar keeps its title + back button above it.
class TrackerDayNav extends StatelessWidget implements PreferredSizeWidget {
  final DateTime viewedDate;
  final DateTime today;
  final ValueChanged<DateTime> onChanged;

  const TrackerDayNav({
    super.key,
    required this.viewedDate,
    required this.today,
    required this.onChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(50);

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: viewedDate,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isToday = daysBetween(viewedDate, today) == 0;
    // No date text here — the viewed day is already shown in the screen's own
    // header; this bar is just the controls, so the date isn't shown twice.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          key: const Key('tracker-day-prev'),
          tooltip: loc.dietDayPrevTooltip,
          // Calendar-component arithmetic (not Duration math) so a DST
          // boundary can't shift the day.
          onPressed: () => onChanged(DateUtils.addDaysToDate(viewedDate, -1)),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          key: const Key('tracker-day-pick'),
          tooltip: loc.dietCalendarOpenTooltip,
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_today),
        ),
        IconButton(
          key: const Key('tracker-day-next'),
          tooltip: loc.dietDayNextTooltip,
          onPressed: isToday
              ? null
              : () => onChanged(DateUtils.addDaysToDate(viewedDate, 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
