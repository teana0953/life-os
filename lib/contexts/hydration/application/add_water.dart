import '../domain/water_repository.dart';

/// Use case: add water to a day's total (a negative amount corrects it down).
/// Returns the updated total.
class AddWater {
  final WaterRepository _repository;

  AddWater(this._repository);

  Future<int> call(String idToken, {required String day, required int addMl}) {
    return _repository.addWater(idToken, day: day, addMl: addMl);
  }
}
