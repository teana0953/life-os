import '../domain/health_calendar.dart';
import '../domain/health_calendar_repository.dart';

/// Use case: fetch a month's health-calendar summary.
class GetHealthCalendar {
  final HealthCalendarRepository repository;

  const GetHealthCalendar(this.repository);

  Future<HealthCalendar> call(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) => repository.getCalendar(idToken, year: year, month: month, today: today);
}
