import 'health_calendar.dart';

/// Port for the monthly health-calendar summary.
abstract class HealthCalendarRepository {
  /// Fetches the summary for [year]/[month]; [today] (`YYYY-MM-DD`, the user's
  /// local date) bounds the current month's elapsed days.
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  });
}
