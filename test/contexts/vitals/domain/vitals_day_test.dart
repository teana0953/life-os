import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';

void main() {
  group('reading value equality', () {
    test('BpReading compares by value (incl. null pulse)', () {
      expect(
        const BpReading(systolic: 120, diastolic: 80, pulse: 70),
        const BpReading(systolic: 120, diastolic: 80, pulse: 70),
      );
      expect(
        const BpReading(systolic: 120, diastolic: 80, pulse: null),
        const BpReading(systolic: 120, diastolic: 80, pulse: null),
      );
      expect(
        const BpReading(systolic: 120, diastolic: 80, pulse: 70),
        isNot(const BpReading(systolic: 121, diastolic: 80, pulse: 70)),
      );
    });

    test('GlucoseReading compares by value', () {
      expect(
        const GlucoseReading(label: '餐前', value: 95),
        const GlucoseReading(label: '餐前', value: 95),
      );
      expect(
        const GlucoseReading(label: '餐前', value: 95),
        isNot(const GlucoseReading(label: '餐後', value: 95)),
      );
    });

    test('Spo2Reading compares by value', () {
      expect(
        const Spo2Reading(spo2: 98, pulse: null),
        const Spo2Reading(spo2: 98, pulse: null),
      );
      expect(
        const Spo2Reading(spo2: 98, pulse: 70),
        isNot(const Spo2Reading(spo2: 98, pulse: null)),
      );
    });

    test('copyWith can clear a nullable pulse to null', () {
      const reading = BpReading(systolic: 120, diastolic: 80, pulse: 70);
      expect(reading.copyWith(pulse: null).pulse, isNull);
      expect(reading.copyWith(systolic: 121).pulse, 70);
    });
  });

  group('VitalsDay JSON', () {
    test('fromJson maps snake_case and the three arrays (incl. null pulse)', () {
      final day = VitalsDay.fromJson({
        'day': '2026-07-18',
        'weight_kg': 65.5,
        'body_fat_pct': 20,
        'bp_readings': [
          {'systolic': 120, 'diastolic': 80, 'pulse': 70},
          {'systolic': 118, 'diastolic': 78, 'pulse': null},
        ],
        'glucose_readings': [
          {'label': '餐前', 'value': 95},
        ],
        'spo2_readings': [
          {'spo2': 98, 'pulse': null},
        ],
      });

      expect(day.weightKg, 65.5);
      expect(day.bodyFatPct, 20);
      expect(day.bpReadings.length, 2);
      expect(day.bpReadings[1].pulse, isNull);
      expect(day.glucoseReadings.single.label, '餐前');
      expect(day.spo2Readings.single.spo2, 98);
    });

    test('fromJson maps null scalars and empty arrays', () {
      final day = VitalsDay.fromJson({
        'day': '2026-07-18',
        'weight_kg': null,
        'body_fat_pct': null,
        'bp_readings': <dynamic>[],
        'glucose_readings': <dynamic>[],
        'spo2_readings': <dynamic>[],
      });

      expect(day.weightKg, isNull);
      expect(day.bodyFatPct, isNull);
      expect(day.bpReadings, isEmpty);
    });

    test('toJson round-trips through fromJson', () {
      const original = VitalsDay(
        day: '2026-07-18',
        weightKg: 65.5,
        bodyFatPct: null,
        bpReadings: [BpReading(systolic: 120, diastolic: 80, pulse: null)],
        glucoseReadings: [GlucoseReading(label: '餐後', value: 110)],
        spo2Readings: [Spo2Reading(spo2: 97, pulse: 66)],
      );

      final restored = VitalsDay.fromJson(original.toJson());

      expect(restored.weightKg, 65.5);
      expect(restored.bodyFatPct, isNull);
      expect(restored.bpReadings, original.bpReadings);
      expect(restored.glucoseReadings, original.glucoseReadings);
      expect(restored.spo2Readings, original.spo2Readings);
    });
  });
}
