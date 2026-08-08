import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';

class _FakeVitalsRepository implements VitalsRepository {
  DateTime? gotFrom;
  DateTime? gotTo;

  @override
  Future<VitalsRange> getRange(String idToken, DateTime from, DateTime to) async {
    gotFrom = from;
    gotTo = to;
    return VitalsRange(
      from: from,
      to: to,
      series: const VitalsSeries(
        weight: [],
        bodyFat: [],
        waist: [],
        systolic: [],
        diastolic: [],
        pulse: [],
        glucose: [],
        spo2: [],
      ),
    );
  }

  @override
  Future<VitalsDay> getDay(String idToken, String day) => throw UnimplementedError();

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) => throw UnimplementedError();
}

void main() {
  test('GetVitalsTrends delegates to the repository', () async {
    final repository = _FakeVitalsRepository();
    final range = await GetVitalsTrends(repository)(
      'token',
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 22),
    );

    expect(repository.gotFrom, DateTime(2026, 7, 1));
    expect(repository.gotTo, DateTime(2026, 7, 22));
    expect(range.from, DateTime(2026, 7, 1));
  });
}
