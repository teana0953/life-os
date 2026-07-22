import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';

class _FakeVitalsRepository implements VitalsRepository {
  String? gotDay;
  VitalsDay? savedDay;

  @override
  Future<VitalsDay> getDay(String idToken, String day) async {
    gotDay = day;
    return VitalsDay(
      day: day,
      weightKg: 60,
      bodyFatPct: null,
      bpReadings: const [],
      glucoseReadings: const [],
      spo2Readings: const [],
    );
  }

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) async {
    savedDay = day;
    return day;
  }
}

void main() {
  test('GetVitalsDay delegates to the repository', () async {
    final repository = _FakeVitalsRepository();
    final day = await GetVitalsDay(repository)('token', '2026-07-18');

    expect(repository.gotDay, '2026-07-18');
    expect(day.weightKg, 60);
  });

  test('SaveVitalsDay delegates to the repository', () async {
    final repository = _FakeVitalsRepository();
    const payload = VitalsDay(
      day: '2026-07-18',
      weightKg: 65,
      bodyFatPct: null,
      bpReadings: [
        BpReading(systolic: 120, diastolic: 80, pulse: null, time: '08:30'),
      ],
      glucoseReadings: [],
      spo2Readings: [],
    );

    final saved = await SaveVitalsDay(repository)('token', payload);

    expect(repository.savedDay, payload);
    expect(saved.weightKg, 65);
  });
}
