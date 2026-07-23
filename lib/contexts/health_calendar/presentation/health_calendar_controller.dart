import 'package:flutter/foundation.dart';

import '../application/get_health_calendar.dart';
import '../domain/health_calendar.dart';
import '../domain/health_calendar_exceptions.dart';

enum HealthCalendarStatus { loading, loaded, error, needsReauth }

/// Drives the dashboard's health-calendar card: loads the current month's logged
/// days + rates. The month and "today" come from an injectable [clock] (only the
/// local date is used) so tests can pin them.
class HealthCalendarController extends ChangeNotifier {
  final GetHealthCalendar _getHealthCalendar;
  final DateTime Function() _clock;

  HealthCalendarController(
    this._getHealthCalendar, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  HealthCalendarStatus status = HealthCalendarStatus.loading;
  HealthCalendar? calendar;

  /// Loads the summary for the current (local) month, passing the local `today`
  /// so days-elapsed is judged against the user's calendar day, not server UTC.
  Future<void> load(String idToken) async {
    status = HealthCalendarStatus.loading;
    notifyListeners();

    final now = _clock();
    final today =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)}';

    try {
      calendar = await _getHealthCalendar(
        idToken,
        year: now.year,
        month: now.month,
        today: today,
      );
      status = HealthCalendarStatus.loaded;
    } on HealthCalendarReauthenticationRequired {
      status = HealthCalendarStatus.needsReauth;
    } on HealthCalendarFetchFailure {
      status = HealthCalendarStatus.error;
    } catch (_) {
      status = HealthCalendarStatus.error;
    }
    notifyListeners();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
