import 'package:flutter/foundation.dart';

import '../application/get_health_calendar.dart';
import '../domain/health_calendar.dart';
import '../domain/health_calendar_exceptions.dart';

enum HealthCalendarStatus { loading, loaded, error, needsReauth }

/// Drives the dashboard's health-calendar card: loads a month's logged days +
/// rates. The month it opens on and "today" come from an injectable [clock]
/// (only the local date is used) so tests can pin them.
///
/// Month switching carries the same two guards as [FinanceController] (this
/// repo's most repeated bug class — a shared controller showing month A on
/// screen while month B's data lands in it):
///
/// - the outgoing month's [calendar] is dropped synchronously, so a slow or
///   failed switch never leaves the old month drawn under the new month's
///   label;
/// - a response for a month the user has since left is discarded instead of
///   overwriting the month they are now looking at.
class HealthCalendarController extends ChangeNotifier {
  final GetHealthCalendar _getHealthCalendar;
  final DateTime Function() _clock;

  HealthCalendarController(
    this._getHealthCalendar, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  HealthCalendarStatus status = HealthCalendarStatus.loading;
  HealthCalendar? calendar;

  /// The month being viewed, as its first day. Starts at the clock's local
  /// month — the card opens on the current month, as it always has.
  late DateTime selectedMonth = DateTime(_clock().year, _clock().month);

  /// Reloads the month currently being viewed. (Retries go through here, so a
  /// retry refreshes what the user is looking at, not whatever month it was
  /// when the app started.)
  Future<void> load(String idToken) =>
      loadMonth(idToken, selectedMonth.year, selectedMonth.month);

  /// Switches to [year]/[month] and loads its summary, passing the local
  /// `today` — which stays the real today whichever month is being viewed, so
  /// days-elapsed is judged against the user's calendar day, not server UTC.
  Future<void> loadMonth(String idToken, int year, int month) async {
    final isMonthChange =
        year != selectedMonth.year || month != selectedMonth.month;
    // Set synchronously, so a switch started after this one can tell this one
    // is stale by the time its response arrives.
    selectedMonth = DateTime(year, month);
    if (isMonthChange) calendar = null;
    status = HealthCalendarStatus.loading;
    notifyListeners();

    final now = _clock();
    final today =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)}';

    bool stale() =>
        selectedMonth.year != year || selectedMonth.month != month;

    try {
      final loaded = await _getHealthCalendar(
        idToken,
        year: year,
        month: month,
        today: today,
      );
      if (stale()) return;
      calendar = loaded;
      status = HealthCalendarStatus.loaded;
    } on HealthCalendarReauthenticationRequired {
      if (stale()) return;
      status = HealthCalendarStatus.needsReauth;
    } on HealthCalendarFetchFailure {
      if (stale()) return;
      status = HealthCalendarStatus.error;
    } catch (_) {
      if (stale()) return;
      status = HealthCalendarStatus.error;
    }
    notifyListeners();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
