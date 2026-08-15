import '../domain/water_repository.dart';

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
