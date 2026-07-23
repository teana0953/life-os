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

/// A metric's normal reference range, from [min] to [max] (inclusive), in the
/// metric's own unit.
class NormalRange {
  final double min;
  final double max;

  const NormalRange(this.min, this.max);
}

/// The normal reference range for [metric], or null when the metric has none.
///
/// Blood pressure, pulse, glucose, and blood oxygen use fixed clinical ranges.
/// Weight derives its range from a healthy BMI (18.5–24.9) and [heightCm]
/// (`weight = bmi × (height/100)²`), rounded to one decimal; it has no range
/// when [heightCm] is null or not positive. Body fat has no range.
NormalRange? normalRangeFor(VitalsMetric metric, {double? heightCm}) =>
    switch (metric) {
      VitalsMetric.systolic => const NormalRange(90, 120),
      VitalsMetric.diastolic => const NormalRange(60, 80),
      VitalsMetric.pulse => const NormalRange(60, 100),
      VitalsMetric.glucose => const NormalRange(70, 140),
      VitalsMetric.spo2 => const NormalRange(95, 100),
      VitalsMetric.bodyFat => null,
      VitalsMetric.weight => (heightCm == null || heightCm <= 0)
          ? null
          : () {
              final heightM2 = (heightCm / 100) * (heightCm / 100);
              return NormalRange(
                _round1(18.5 * heightM2),
                _round1(24.9 * heightM2),
              );
            }(),
    };

/// Rounds [value] to one decimal place.
double _round1(double value) => (value * 10).round() / 10;

/// Parses a "YYYY-MM-DD" string into a date-only [DateTime] (local midnight).
DateTime _parseDay(String day) {
  final parts = day.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
