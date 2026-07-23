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
        weight: [SeriesPoint(day: DateTime(2026, 7, 1), value: 65)],
        bodyFat: [SeriesPoint(day: DateTime(2026, 7, 1), value: 20)],
        systolic: [SeriesPoint(day: DateTime(2026, 7, 1), value: 120)],
        diastolic: [SeriesPoint(day: DateTime(2026, 7, 1), value: 80)],
        pulse: [SeriesPoint(day: DateTime(2026, 7, 1), value: 70)],
        glucose: [SeriesPoint(day: DateTime(2026, 7, 1), value: 95)],
        spo2: [SeriesPoint(day: DateTime(2026, 7, 1), value: 98)],
      );

      expect(seriesFor(series, VitalsMetric.weight).single.value, 65);
      expect(seriesFor(series, VitalsMetric.bodyFat).single.value, 20);
      expect(seriesFor(series, VitalsMetric.systolic).single.value, 120);
      expect(seriesFor(series, VitalsMetric.diastolic).single.value, 80);
      expect(seriesFor(series, VitalsMetric.pulse).single.value, 70);
      expect(seriesFor(series, VitalsMetric.glucose).single.value, 95);
      expect(seriesFor(series, VitalsMetric.spo2).single.value, 98);
    });
  });
}
