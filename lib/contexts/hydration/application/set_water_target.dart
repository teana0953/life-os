import '../domain/water_repository.dart';

/// Use case: set a day's water target. Returns the updated target.
class SetWaterTarget {
  final WaterRepository _repository;

  SetWaterTarget(this._repository);

  Future<int> call(
    String idToken, {
    required String day,
    required int targetMl,
  }) {
    return _repository.setTarget(idToken, day: day, targetMl: targetMl);
  }
}
