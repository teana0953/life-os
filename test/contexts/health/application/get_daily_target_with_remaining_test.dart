import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTargetWithRemaining? targetToReturn;
  String? receivedIdToken;
  String? receivedDay;

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    receivedIdToken = idToken;
    receivedDay = day;
    return targetToReturn!;
  }

  @override
  Future<DailyTarget> setTarget(
    String idToken, {
    required String day,
    required double baseStaple,
    required double baseMeat,
    required double baseFruit,
    required double baseVeg,
    double? bonusStaple,
    double? bonusMeat,
    double? bonusFruit,
    double? bonusVeg,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  group('GetDailyTargetWithRemaining', () {
    test('returns the target with remaining via the repository', () async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = DailyTargetWithRemaining.fromJson({
          'day': '2026-07-18',
          'base': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
          'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
          'effective': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
          'logged': {'staple': 9, 'meat': 3, 'fruit': 1, 'veg': 0},
          'remaining': {'staple': 3, 'meat': 3, 'fruit': 3, 'veg': 3},
        });
      final getTarget = GetDailyTargetWithRemaining(repository);

      final result = await getTarget('token-123', '2026-07-18');

      expect(result.remaining.staple, 3);
      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedDay, '2026-07-18');
    });
  });
}
