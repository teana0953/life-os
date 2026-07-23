/// A month's health-calendar summary from `GET /api/health-calendar`: which days
/// had any tracker entry, plus the month's logging and diet-adherence rates.
class HealthCalendar {
  final int year;

  /// 1–12.
  final int month;

  /// The days in the month with any tracker entry, as `YYYY-MM-DD` strings.
  final Set<String> loggedDays;

  /// Days counted so far this month (day-of-month for the current month, the full
  /// month for a past month, 0 for a future month).
  final int daysElapsed;

  /// Percentage (0–100) of elapsed days with a record; null when none elapsed.
  final int? loggingRate;

  /// Percentage (0–100) of elapsed days that met the diet target; null when none
  /// elapsed.
  final int? dietAdherenceRate;

  const HealthCalendar({
    required this.year,
    required this.month,
    required this.loggedDays,
    required this.daysElapsed,
    required this.loggingRate,
    required this.dietAdherenceRate,
  });

  factory HealthCalendar.fromJson(Map<String, dynamic> json) => HealthCalendar(
    year: (json['year'] as num).toInt(),
    month: (json['month'] as num).toInt(),
    loggedDays: {
      for (final d in (json['logged_days'] as List? ?? const [])) d as String,
    },
    daysElapsed: (json['days_elapsed'] as num).toInt(),
    loggingRate: (json['logging_rate'] as num?)?.toInt(),
    dietAdherenceRate: (json['diet_adherence_rate'] as num?)?.toInt(),
  );
}
