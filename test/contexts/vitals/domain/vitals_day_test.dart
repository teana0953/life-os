import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';

void main() {
  group('reading value equality', () {
    test('BpReading compares by value (incl. null pulse)', () {
      expect(
        const BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
        const BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
      );
      expect(
        const BpReading(
          systolic: 120,
          diastolic: 80,
          pulse: null,
          time: '08:30',
        ),
        const BpReading(
          systolic: 120,
          diastolic: 80,
          pulse: null,
          time: '08:30',
        ),
      );
      expect(
        const BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
        isNot(
          const BpReading(
            systolic: 121,
            diastolic: 80,
            pulse: 70,
            time: '08:30',
          ),
        ),
      );
    });

    test('a reading with a changed time is not equal to the original', () {
      const reading = BpReading(
        systolic: 120,
        diastolic: 80,
        pulse: 70,
        time: '08:30',
      );
      expect(reading, isNot(reading.copyWith(time: '09:15')));
      expect(reading.copyWith(time: '09:15').time, '09:15');
      expect(
        const GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '08:30'),
        isNot(const GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '09:15')),
      );
      expect(
        const Spo2Reading(spo2: 98, pulse: null, time: '08:30'),
        isNot(const Spo2Reading(spo2: 98, pulse: null, time: '09:15')),
      );
    });

    test('GlucoseReading compares by value', () {
      expect(
        const GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '08:30'),
        const GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '08:30'),
      );
      expect(
        const GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '08:30'),
        isNot(const GlucoseReading(label: '餐後', value: 95, mealContext: null, time: '08:30')),
      );
    });

    test('Spo2Reading compares by value', () {
      expect(
        const Spo2Reading(spo2: 98, pulse: null, time: '08:30'),
        const Spo2Reading(spo2: 98, pulse: null, time: '08:30'),
      );
      expect(
        const Spo2Reading(spo2: 98, pulse: 70, time: '08:30'),
        isNot(const Spo2Reading(spo2: 98, pulse: null, time: '08:30')),
      );
    });

    test('copyWith can clear a nullable pulse to null', () {
      const reading = BpReading(
        systolic: 120,
        diastolic: 80,
        pulse: 70,
        time: '08:30',
      );
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
        // Deliberately different from every other scalar here: three fields
        // reading from one key would still look right if they all held 20.
        'waist_cm': 78.5,
        'bp_readings': [
          {'systolic': 120, 'diastolic': 80, 'pulse': 70, 'time': '08:30'},
          {'systolic': 118, 'diastolic': 78, 'pulse': null, 'time': '09:15'},
        ],
        'glucose_readings': [
          {'label': '餐前', 'value': 95, 'time': '07:45'},
        ],
        'spo2_readings': [
          {'spo2': 98, 'pulse': null, 'time': '10:00'},
        ],
      });

      expect(day.weightKg, 65.5);
      expect(day.bodyFatPct, 20);
      expect(day.waistCm, 78.5);
      expect(day.bpReadings.length, 2);
      expect(day.bpReadings[1].pulse, isNull);
      expect(day.bpReadings[0].time, '08:30');
      expect(day.glucoseReadings.single.label, '餐前');
      expect(day.glucoseReadings.single.time, '07:45');
      expect(day.spo2Readings.single.spo2, 98);
      expect(day.spo2Readings.single.time, '10:00');
    });

    test('fromJson tolerates a legacy reading with no time (defaults to \'\')',
        () {
      final day = VitalsDay.fromJson({
        'day': '2026-07-18',
        'weight_kg': null,
        'body_fat_pct': null,
        'bp_readings': [
          {'systolic': 120, 'diastolic': 80, 'pulse': 70},
        ],
        'glucose_readings': <dynamic>[],
        'spo2_readings': <dynamic>[],
      });

      expect(day.bpReadings.single.time, '');
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
        waistCm: null,
        bpReadings: [
          BpReading(systolic: 120, diastolic: 80, pulse: null, time: '08:30'),
        ],
        glucoseReadings: [
          GlucoseReading(label: '餐後', value: 110, mealContext: null, time: '12:30'),
        ],
        spo2Readings: [Spo2Reading(spo2: 97, pulse: 66, time: '22:05')],
      );

      final restored = VitalsDay.fromJson(original.toJson());

      expect(restored.weightKg, 65.5);
      expect(restored.bodyFatPct, isNull);
      expect(restored.bpReadings, original.bpReadings);
      expect(restored.bpReadings.single.time, '08:30');
      expect(restored.glucoseReadings, original.glucoseReadings);
      expect(restored.spo2Readings, original.spo2Readings);
    });
  });
}
