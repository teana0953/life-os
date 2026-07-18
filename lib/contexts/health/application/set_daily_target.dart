import '../domain/daily_target.dart';
import '../domain/daily_target_repository.dart';

/// Use case: set (upsert) a day's base portion goals.
class SetDailyTarget {
  final DailyTargetRepository _repository;

  SetDailyTarget(this._repository);

  Future<DailyTarget> call(
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
  }) {
    return _repository.setTarget(
      idToken,
      day: day,
      baseStaple: baseStaple,
      baseMeat: baseMeat,
      baseFruit: baseFruit,
      baseVeg: baseVeg,
      bonusStaple: bonusStaple,
      bonusMeat: bonusMeat,
      bonusFruit: bonusFruit,
      bonusVeg: bonusVeg,
    );
  }
}
