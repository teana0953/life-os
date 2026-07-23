/// A single daily point in a vitals metric series: a date-only [day] and its
/// numeric [value].
class SeriesPoint {
  final DateTime day;
  final double value;

  const SeriesPoint({required this.day, required this.value});

  factory SeriesPoint.fromJson(Map<String, dynamic> json) => SeriesPoint(
    day: _parseDay(json['day'] as String),
    value: (json['value'] as num).toDouble(),
  );
}

/// Per-metric daily series over a date range, as returned by
/// `GET /api/vitals/range`. Each field is the list of that metric's daily
/// points (empty when the metric has no readings in the range). The backend's
/// snake_case keys are exactly `weight, body_fat, systolic, diastolic, pulse,
/// glucose, spo2` (note `body_fat` / `spo2`).
class VitalsSeries {
  final List<SeriesPoint> weight;
  final List<SeriesPoint> bodyFat;
  final List<SeriesPoint> systolic;
  final List<SeriesPoint> diastolic;
  final List<SeriesPoint> pulse;
  final List<SeriesPoint> glucose;
  final List<SeriesPoint> spo2;

  const VitalsSeries({
    required this.weight,
    required this.bodyFat,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.glucose,
    required this.spo2,
  });

  factory VitalsSeries.fromJson(Map<String, dynamic> json) => VitalsSeries(
    weight: _points(json['weight']),
    bodyFat: _points(json['body_fat']),
    systolic: _points(json['systolic']),
    diastolic: _points(json['diastolic']),
    pulse: _points(json['pulse']),
    glucose: _points(json['glucose']),
    spo2: _points(json['spo2']),
  );

  static List<SeriesPoint> _points(Object? raw) => [
    for (final p in (raw as List? ?? const []))
      SeriesPoint.fromJson(p as Map<String, dynamic>),
  ];
}

/// A date range with its per-metric daily series.
class VitalsRange {
  final DateTime from;
  final DateTime to;
  final VitalsSeries series;

  const VitalsRange({
    required this.from,
    required this.to,
    required this.series,
  });

  factory VitalsRange.fromJson(Map<String, dynamic> json) => VitalsRange(
    from: _parseDay(json['from'] as String),
    to: _parseDay(json['to'] as String),
    series: VitalsSeries.fromJson(
      (json['series'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    ),
  );
}

/// The metrics the trend card can plot, one at a time.
enum VitalsMetric { weight, bodyFat, systolic, diastolic, pulse, glucose, spo2 }

/// The series for [metric] within [series].
List<SeriesPoint> seriesFor(VitalsSeries series, VitalsMetric metric) =>
    switch (metric) {
      VitalsMetric.weight => series.weight,
      VitalsMetric.bodyFat => series.bodyFat,
      VitalsMetric.systolic => series.systolic,
      VitalsMetric.diastolic => series.diastolic,
      VitalsMetric.pulse => series.pulse,
      VitalsMetric.glucose => series.glucose,
      VitalsMetric.spo2 => series.spo2,
    };

/// Parses a "YYYY-MM-DD" string into a date-only [DateTime] (local midnight).
DateTime _parseDay(String day) {
  final parts = day.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
