import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/hydration/application/add_water.dart';
import 'package:life_os/contexts/hydration/application/get_water_day.dart';
import 'package:life_os/contexts/hydration/application/set_water_target.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';

class FakeWaterRepository implements WaterRepository {
  WaterDay? dayToReturn;
  String? receivedDay;
  int? receivedAddMl;
  int? receivedTargetMl;

  @override
  Future<WaterDay> getDay(String idToken, String day) async {
    receivedDay = day;
    return dayToReturn!;
  }

  @override
  Future<int> addWater(
    String idToken, {
    required String day,
    required int addMl,
  }) async {
    receivedDay = day;
    receivedAddMl = addMl;
    return 750;
  }

  @override
  Future<int> setTarget(
    String idToken, {
    required String day,
    required int targetMl,
  }) async {
    receivedDay = day;
    receivedTargetMl = targetMl;
    return targetMl;
  }
}

void main() {
  test('GetWaterDay delegates to the repository', () async {
    final repository = FakeWaterRepository()
      ..dayToReturn = const WaterDay(
        day: '2026-07-18',
        totalMl: 500,
        targetMl: 2000,
        remainingMl: 1500,
      );

    final result = await GetWaterDay(repository)('token', '2026-07-18');

    expect(result.totalMl, 500);
    expect(repository.receivedDay, '2026-07-18');
  });

  test('AddWater delegates to the repository and returns the new total', () async {
    final repository = FakeWaterRepository();

    final total = await AddWater(repository)('token', day: '2026-07-18', addMl: 250);

    expect(total, 750);
    expect(repository.receivedAddMl, 250);
  });

  test('SetWaterTarget delegates to the repository', () async {
    final repository = FakeWaterRepository();

    final target = await SetWaterTarget(repository)(
      'token',
      day: '2026-07-18',
      targetMl: 2000,
    );

    expect(target, 2000);
    expect(repository.receivedTargetMl, 2000);
  });
}
