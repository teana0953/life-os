import 'daily_target.dart';

/// Port for reading and setting a day's daily portion target.
abstract class DailyTargetRepository {
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day);

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
  });
}
