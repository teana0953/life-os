import 'water_day.dart';

/// Port for reading a day's water intake, adding water, and setting the
/// day's target.
abstract class WaterRepository {
  Future<WaterDay> getDay(String idToken, String day);

  /// Adds [addMl] to the day's total (a negative value corrects it down; the
  /// backend clamps the stored total at zero). Returns the updated total.
  Future<int> addWater(String idToken, {required String day, required int addMl});

  /// Sets the day's target. Returns the updated target.
  Future<int> setTarget(
    String idToken, {
    required String day,
    required int targetMl,
  });
}
