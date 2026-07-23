import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_exceptions.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';

class FakeVitalsRepository implements VitalsRepository {
  @override
  Future<VitalsRange> getRange(
    String idToken,
    DateTime from,
    DateTime to,
  ) async => VitalsRange(
    from: from,
    to: to,
    series: const VitalsSeries(
      weight: [],
      bodyFat: [],
      systolic: [],
      diastolic: [],
      pulse: [],
      glucose: [],
      spo2: [],
    ),
  );

  VitalsDay dayToReturn = const VitalsDay(
    day: '2026-07-18',
    weightKg: null,
    bodyFatPct: null,
    bpReadings: [],
    glucoseReadings: [],
    spo2Readings: [],
  );

  Object? getError;
  Object? saveError;

  VitalsDay? savedDay;

  @override
  Future<VitalsDay> getDay(String idToken, String day) async {
    if (getError != null) throw getError!;
    return dayToReturn;
  }

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) async {
    if (saveError != null) throw saveError!;
    savedDay = day;
    return day;
  }
}

VitalsController _controller(
  FakeVitalsRepository repository, {
  TimeOfDay Function()? clock,
}) => VitalsController(
  GetVitalsDay(repository),
  SaveVitalsDay(repository),
  clock: clock ?? TimeOfDay.now,
);

void main() {
  group('VitalsController.load', () {
    test('loads a day and populates the editable draft', () async {
      final repository = FakeVitalsRepository()
        ..dayToReturn = const VitalsDay(
          day: '2026-07-18',
          weightKg: 65.5,
          bodyFatPct: 20,
          bpReadings: [
            BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
          ],
          glucoseReadings: [
            GlucoseReading(label: '餐前', value: 95, time: '07:45'),
          ],
          spo2Readings: [Spo2Reading(spo2: 98, pulse: null, time: '10:00')],
        );
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, VitalsStatus.loaded);
      expect(controller.weightKg, 65.5);
      expect(controller.bodyFatPct, 20);
      expect(controller.bpReadings.single.systolic, 120);
      expect(controller.glucoseReadings.single.label, '餐前');
      expect(controller.spo2Readings.single.spo2, 98);
    });

    test('a 401 surfaces needsReauth rather than crashing', () async {
      final repository = FakeVitalsRepository()
        ..getError = const VitalsReauthenticationRequired();
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, VitalsStatus.needsReauth);
    });

    test('a fetch failure surfaces an error state', () async {
      final repository = FakeVitalsRepository()
        ..getError = const VitalsFetchFailure('boom');
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, VitalsStatus.error);
      expect(controller.error, VitalsError.fetchFailed);
    });

    test('loading a different day resets the draft to that day', () async {
      final repository = FakeVitalsRepository()
        ..dayToReturn = const VitalsDay(
          day: '2026-07-18',
          weightKg: 65,
          bodyFatPct: null,
          bpReadings: [
            BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
          ],
          glucoseReadings: [],
          spo2Readings: [],
        );
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      // The user edits the draft...
      controller.setWeight(70);
      controller.addBpReading();

      // ...then a different day loads, resetting the draft.
      repository.dayToReturn = const VitalsDay(
        day: '2026-07-17',
        weightKg: null,
        bodyFatPct: null,
        bpReadings: [],
        glucoseReadings: [],
        spo2Readings: [],
      );
      await controller.load('token', '2026-07-17');

      expect(controller.weightKg, isNull);
      expect(controller.bpReadings, isEmpty);
    });
  });

  group('VitalsController draft mutations', () {
    test('setWeight/setBodyFat accept null (unrecorded), without saving',
        () async {
      final repository = FakeVitalsRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      controller.setWeight(65.5);
      controller.setBodyFat(null);

      expect(controller.weightKg, 65.5);
      expect(controller.bodyFatPct, isNull);
      expect(repository.savedDay, isNull);
    });

    test('add / update a field / remove a reading in each list', () async {
      final controller = _controller(FakeVitalsRepository());
      await controller.load('token', '2026-07-18');

      controller.addBpReading();
      controller.updateBpReading(
        0,
        controller.bpReadings[0].copyWith(systolic: 120, diastolic: 80),
      );
      expect(controller.bpReadings.single.systolic, 120);
      controller.removeBpReading(0);
      expect(controller.bpReadings, isEmpty);

      controller.addGlucoseReading();
      controller.updateGlucoseReading(
        0,
        controller.glucoseReadings[0].copyWith(label: '餐前', value: 95),
      );
      expect(controller.glucoseReadings.single.value, 95);

      controller.addSpo2Reading();
      controller.updateSpo2Reading(
        0,
        controller.spo2Readings[0].copyWith(spo2: 98),
      );
      expect(controller.spo2Readings.single.spo2, 98);
    });

    test('a newly added reading defaults its time to now (HH:mm, zero-padded)',
        () async {
      final controller = _controller(
        FakeVitalsRepository(),
        clock: () => const TimeOfDay(hour: 9, minute: 5),
      );
      await controller.load('token', '2026-07-18');

      controller.addBpReading();
      controller.addGlucoseReading();
      controller.addSpo2Reading();

      expect(controller.bpReadings.single.time, '09:05');
      expect(controller.glucoseReadings.single.time, '09:05');
      expect(controller.spo2Readings.single.time, '09:05');
    });
  });

  group('VitalsController.save', () {
    test('upserts the whole draft and reflects the saved state', () async {
      final repository = FakeVitalsRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      controller.setWeight(65.5);
      controller.addBpReading();
      controller.updateBpReading(
        0,
        const BpReading(
          systolic: 120,
          diastolic: 80,
          pulse: null,
          time: '08:30',
        ),
      );
      controller.addGlucoseReading();
      controller.updateGlucoseReading(
        0,
        const GlucoseReading(label: '餐前', value: 95, time: '07:45'),
      );
      await controller.save('token', '2026-07-18');

      expect(repository.savedDay!.weightKg, 65.5);
      expect(repository.savedDay!.bpReadings.single.systolic, 120);
      expect(repository.savedDay!.glucoseReadings.single.label, '餐前');
      expect(controller.status, VitalsStatus.loaded);
    });

    test('a save failure surfaces error and keeps the entered draft', () async {
      final repository = FakeVitalsRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      controller.setWeight(70);
      controller.addBpReading();
      repository.saveError = const VitalsFetchFailure('boom');
      await controller.save('token', '2026-07-18');

      expect(controller.status, VitalsStatus.error);
      // The draft is untouched so the user's values survive.
      expect(controller.weightKg, 70);
      expect(controller.bpReadings, isNotEmpty);
    });

    test('coerces an empty reading time to now in the save payload', () async {
      final repository = FakeVitalsRepository()
        ..dayToReturn = const VitalsDay(
          day: '2026-07-18',
          weightKg: null,
          bodyFatPct: null,
          // Legacy/pre-time rows loaded with an empty time; re-saving must
          // never PUT an empty time (the backend requires a strict HH:mm).
          bpReadings: [
            BpReading(systolic: 120, diastolic: 80, pulse: 70, time: ''),
          ],
          glucoseReadings: [GlucoseReading(label: '餐前', value: 95, time: '')],
          spo2Readings: [Spo2Reading(spo2: 98, pulse: 70, time: '')],
        );
      final controller = _controller(
        repository,
        clock: () => const TimeOfDay(hour: 9, minute: 5),
      );
      await controller.load('token', '2026-07-18');

      await controller.save('token', '2026-07-18');

      expect(repository.savedDay!.bpReadings.single.time, '09:05');
      expect(repository.savedDay!.glucoseReadings.single.time, '09:05');
      expect(repository.savedDay!.spo2Readings.single.time, '09:05');
    });

    test('a save 401 surfaces needsReauth', () async {
      final repository = FakeVitalsRepository()
        ..saveError = const VitalsReauthenticationRequired();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      await controller.save('token', '2026-07-18');

      expect(controller.status, VitalsStatus.needsReauth);
    });

    test('drops untouched empty rows from the save payload but keeps real ones',
        () async {
      final repository = FakeVitalsRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      // A real BP reading plus an untouched (all-zero) one appended after.
      controller.addBpReading();
      controller.updateBpReading(
        0,
        const BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
      );
      controller.addBpReading();

      // A real glucose reading plus an untouched (0 / blank) one.
      controller.addGlucoseReading();
      controller.updateGlucoseReading(
        0,
        const GlucoseReading(label: '餐前', value: 95, time: '07:45'),
      );
      controller.addGlucoseReading();

      // A real SpO2 reading plus an untouched (0 / null pulse) one.
      controller.addSpo2Reading();
      controller.updateSpo2Reading(
        0,
        const Spo2Reading(spo2: 98, pulse: 70, time: '10:00'),
      );
      controller.addSpo2Reading();

      await controller.save('token', '2026-07-18');

      // Only the non-empty readings reach the repository.
      expect(
        repository.savedDay!.bpReadings,
        const [
          BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
        ],
      );
      expect(
        repository.savedDay!.glucoseReadings,
        const [GlucoseReading(label: '餐前', value: 95, time: '07:45')],
      );
      expect(
        repository.savedDay!.spo2Readings,
        const [Spo2Reading(spo2: 98, pulse: 70, time: '10:00')],
      );
    });
  });

  group('VitalsController.hasUnsavedChanges', () {
    test('is false after a load and flips true after add/edit/remove',
        () async {
      final repository = FakeVitalsRepository()
        ..dayToReturn = const VitalsDay(
          day: '2026-07-18',
          weightKg: 65,
          bodyFatPct: null,
          bpReadings: [
            BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
          ],
          glucoseReadings: [],
          spo2Readings: [],
        );
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      // A freshly loaded day has no unsaved changes even though the draft
      // reading list is a different instance from the loaded day's list
      // (compared element-wise by value, not identity).
      expect(controller.hasUnsavedChanges, isFalse);

      controller.updateBpReading(
        0,
        controller.bpReadings[0].copyWith(systolic: 121),
      );
      expect(controller.hasUnsavedChanges, isTrue);
    });

    test('editing a reading\'s time flips it true', () async {
      final repository = FakeVitalsRepository()
        ..dayToReturn = const VitalsDay(
          day: '2026-07-18',
          weightKg: 65,
          bodyFatPct: null,
          bpReadings: [
            BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
          ],
          glucoseReadings: [],
          spo2Readings: [],
        );
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');
      expect(controller.hasUnsavedChanges, isFalse);

      controller.updateBpReading(
        0,
        controller.bpReadings[0].copyWith(time: '09:15'),
      );
      expect(controller.hasUnsavedChanges, isTrue);
    });

    test('a scalar edit flips it true', () async {
      final controller = _controller(FakeVitalsRepository());
      await controller.load('token', '2026-07-18');
      expect(controller.hasUnsavedChanges, isFalse);

      controller.setWeight(60);
      expect(controller.hasUnsavedChanges, isTrue);
    });

    test('returns to false after a successful save', () async {
      final controller = _controller(FakeVitalsRepository());
      await controller.load('token', '2026-07-18');
      controller.addGlucoseReading();
      expect(controller.hasUnsavedChanges, isTrue);

      await controller.save('token', '2026-07-18');
      expect(controller.hasUnsavedChanges, isFalse);
    });
  });
}
