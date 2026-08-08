import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';

void main() {
  group('VitalsRange.fromJson', () {
    test('parses from/to (date-only) and each snake_case series', () {
      final range = VitalsRange.fromJson({
        'from': '2026-07-01',
        'to': '2026-07-03',
        'series': {
          'weight': [
            {'day': '2026-07-01', 'value': 65.5},
            {'day': '2026-07-03', 'value': 65.0},
          ],
          'body_fat': [
            {'day': '2026-07-01', 'value': 20},
          ],
          'waist': [
            {'day': '2026-07-01', 'value': 78.5},
          ],
          'systolic': [
            {'day': '2026-07-02', 'value': 120},
          ],
          'diastolic': [
            {'day': '2026-07-02', 'value': 80},
          ],
          'pulse': [
            {'day': '2026-07-02', 'value': 70},
          ],
          'glucose': [
            {'day': '2026-07-01', 'value': 95},
          ],
          'spo2': [
            {'day': '2026-07-01', 'value': 98},
          ],
        },
      });

      expect(range.from, DateTime(2026, 7, 1));
      expect(range.to, DateTime(2026, 7, 3));
      expect(range.series.weight.length, 2);
      expect(range.series.weight.first.day, DateTime(2026, 7, 1));
      expect(range.series.weight.first.value, 65.5);
      // The snake_case keys body_fat / spo2 map to bodyFat / spo2.
      expect(range.series.bodyFat.single.value, 20);
      expect(range.series.waist.single.value, 78.5);
      expect(range.series.systolic.single.value, 120);
      expect(range.series.diastolic.single.value, 80);
      expect(range.series.pulse.single.value, 70);
      expect(range.series.glucose.single.value, 95);
      expect(range.series.spo2.single.value, 98);
    });

    test('missing series keys default to empty lists', () {
      final range = VitalsRange.fromJson({
        'from': '2026-07-01',
        'to': '2026-07-03',
        'series': <String, dynamic>{},
      });

      expect(range.series.weight, isEmpty);
      expect(range.series.bodyFat, isEmpty);
      expect(range.series.systolic, isEmpty);
      expect(range.series.diastolic, isEmpty);
      expect(range.series.pulse, isEmpty);
      expect(range.series.glucose, isEmpty);
      expect(range.series.spo2, isEmpty);
    });

    test('parses a day component to a date-only DateTime (no time)', () {
      final range = VitalsRange.fromJson({
        'from': '2026-07-01',
        'to': '2026-07-01',
        'series': {
          'weight': [
            {'day': '2026-07-01', 'value': 65},
          ],
        },
      });
      final day = range.series.weight.single.day;
      expect(day.hour, 0);
      expect(day.minute, 0);
    });
  });

  group('seriesFor', () {
    test('maps each metric to its corresponding series', () {
      final series = VitalsSeries(
        weight: [SeriesPoint(day: DateTime(2026, 7, 1), time: '', value: 65)],
        bodyFat: [SeriesPoint(day: DateTime(2026, 7, 1), time: '', value: 20)],
        // A value of its own, not an empty list: this test's whole job is
        // catching a metric wired to the wrong series, and an empty one
        // cannot be told apart from a right answer.
        waist: [SeriesPoint(day: DateTime(2026, 7, 1), time: '', value: 78.5)],
        systolic: [SeriesPoint(day: DateTime(2026, 7, 1), time: '', value: 120)],
        diastolic: [SeriesPoint(day: DateTime(2026, 7, 1), time: '', value: 80)],
        pulse: [SeriesPoint(day: DateTime(2026, 7, 1), time: '', value: 70)],
        glucose: [SeriesPoint(day: DateTime(2026, 7, 1), time: '', value: 95)],
        spo2: [SeriesPoint(day: DateTime(2026, 7, 1), time: '', value: 98)],
      );

      expect(seriesFor(series, VitalsMetric.weight).single.value, 65);
      expect(seriesFor(series, VitalsMetric.bodyFat).single.value, 20);
      expect(seriesFor(series, VitalsMetric.waist).single.value, 78.5);
      expect(seriesFor(series, VitalsMetric.systolic).single.value, 120);
      expect(seriesFor(series, VitalsMetric.diastolic).single.value, 80);
      expect(seriesFor(series, VitalsMetric.pulse).single.value, 70);
      expect(seriesFor(series, VitalsMetric.glucose).single.value, 95);
      expect(seriesFor(series, VitalsMetric.spo2).single.value, 98);
    });
  });

  group('metricsForView', () {
    test('the waist view plots waist, not the neighbouring scalar', () {
      // Every single-metric view is one line in a `switch`, and the two body
      // scalars sit next to each other in it: a view pointing at the wrong
      // one still draws a plausible chart with the right axis label.
      expect(metricsForView(TrendView.waist), const [VitalsMetric.waist]);
    });

    test('single-metric views map to one metric', () {
      expect(metricsForView(TrendView.weight), [VitalsMetric.weight]);
      expect(metricsForView(TrendView.bodyFat), [VitalsMetric.bodyFat]);
      expect(metricsForView(TrendView.glucose), [VitalsMetric.glucose]);
      expect(metricsForView(TrendView.spo2), [VitalsMetric.spo2]);
    });

    test('blood pressure & pulse view combines three metrics in draw order', () {
      expect(metricsForView(TrendView.bloodPressurePulse), [
        VitalsMetric.systolic,
        VitalsMetric.diastolic,
        VitalsMetric.pulse,
      ]);
    });
  });

  group('normalRangeFor', () {
    test('clinical metrics have fixed ranges', () {
      expect(normalRangeFor(VitalsMetric.systolic)!.min, 90);
      expect(normalRangeFor(VitalsMetric.systolic)!.max, 120);
      expect(normalRangeFor(VitalsMetric.diastolic)!.min, 60);
      expect(normalRangeFor(VitalsMetric.diastolic)!.max, 80);
      expect(normalRangeFor(VitalsMetric.pulse)!.min, 60);
      expect(normalRangeFor(VitalsMetric.pulse)!.max, 100);
      expect(normalRangeFor(VitalsMetric.glucose)!.min, 70);
      expect(normalRangeFor(VitalsMetric.glucose)!.max, 140);
      expect(normalRangeFor(VitalsMetric.spo2)!.min, 95);
      expect(normalRangeFor(VitalsMetric.spo2)!.max, 100);
    });

    test('weight derives a healthy-BMI range from height (165 cm)', () {
      final range = normalRangeFor(VitalsMetric.weight, heightCm: 165);
      expect(range!.min, 50.4);
      expect(range.max, 67.8);
    });

    test('weight has no range without a (positive) height', () {
      expect(normalRangeFor(VitalsMetric.weight), isNull);
      expect(normalRangeFor(VitalsMetric.weight, heightCm: 0), isNull);
      expect(normalRangeFor(VitalsMetric.weight, heightCm: -5), isNull);
    });

    test('body fat has no range', () {
      expect(normalRangeFor(VitalsMetric.bodyFat, heightCm: 165), isNull);
    });
  });
}
