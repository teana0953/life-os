import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
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
  /// `controller.load(idToken, day)`). Returns a [Future] that completes when
  /// the reload finishes, so pull-to-refresh can await it and settle its
  /// spinner only then.
  Future<void> reloadDay(String day);

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

  /// Wraps [child] (the screen's scrollable) in a pull-to-refresh. The default
  /// [onRefresh] reloads the viewed day; the spinner settles when that reload
  /// finishes. Vitals overrides [onRefresh] to confirm before discarding an
  /// unsaved draft — the three other trackers have no draft-overwrite hazard,
  /// so this shared default keeps them uncluttered.
  ///
  /// The wrapped scrollable must use [AlwaysScrollableScrollPhysics] so a day
  /// with little content still accepts the overscroll pull.
  Widget refreshable({
    required Widget child,
    Future<void> Function()? onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh ?? () => reloadDay(viewedDay),
      child: child,
    );
  }

  /// A pull-to-refresh handler for trackers whose reload OVERWRITES an editable
  /// draft (vitals, bowel) — a plain reload would silently eat unsaved edits.
  /// Pass this as [refreshable]'s `onRefresh`, wiring [hasUnsavedChanges] to the
  /// controller's flag. With no unsaved edits it reloads immediately, exactly
  /// like the shared default; with edits it confirms first and reloads only if
  /// the user accepts (cancelling keeps the draft and reloads nothing). Trackers
  /// with no draft-overwrite hazard (water, exercise) must NOT use this — they
  /// keep the plain default so they stay uncluttered.
  Future<void> refreshWithUnsavedGuard({
    required bool hasUnsavedChanges,
  }) async {
    if (!hasUnsavedChanges) {
      return reloadDay(viewedDay);
    }
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.refreshDiscardTitle),
        content: Text(loc.refreshDiscardMessage),
        actions: [
          // Discarding loses data, so the safe "cancel" is the emphasized
          // default; the destructive "discard" is the de-emphasized action.
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loc.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.cancel),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await reloadDay(viewedDay);
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
