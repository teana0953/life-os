import 'package:flutter/material.dart';

import '../date/day_format.dart';
import 'tracker_day_nav_header.dart';

/// Adds a browsable "viewed day" (with the shared [TrackerDayNavHeader]) to a
/// day-keyed tracker screen (water / vitals / bowel / exercise) that was
/// previously scoped to the diet shell's shared day. The host provides its
/// initial day, clock, and a per-controller reload; the mixin owns the
/// viewed-date state, the day switching, the default date picker, and building
/// the header.
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

  DateTime get _today {
    final now = clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Switch the viewed day and reload it. The screen doesn't self-load on mount
  /// (the scaffold pre-loaded today), so only a change needs a fetch.
  void setDay(DateTime date) {
    setState(() => _viewedDate = date);
    reloadDay(viewedDay);
  }

  /// Opens a bounded date picker (the simpler trackers' calendar — diet uses its
  /// own logged-days month grid instead) and switches to the picked day.
  Future<void> openDefaultCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewedDate,
      firstDate: DateTime(2020),
      lastDate: _today,
    );
    if (picked != null) {
      setDay(DateTime(picked.year, picked.month, picked.day));
    }
  }

  /// The shared mascot + title + day-selector header, wired to this screen's day
  /// state. Place it at the top of the screen body (above the content cards).
  Widget dayNavHeader({
    required String todayTitle,
    required String historyTitle,
  }) {
    final today = _today;
    final isToday = daysBetween(_viewedDate, today) == 0;
    return TrackerDayNavHeader(
      viewedDate: _viewedDate,
      today: today,
      todayTitle: todayTitle,
      historyTitle: historyTitle,
      // Calendar-component arithmetic (not Duration math) so a DST boundary
      // can't shift the day.
      onPrevious: () => setDay(DateUtils.addDaysToDate(_viewedDate, -1)),
      onNext: isToday
          ? null
          : () => setDay(DateUtils.addDaysToDate(_viewedDate, 1)),
      onOpenCalendar: openDefaultCalendar,
    );
  }
}
