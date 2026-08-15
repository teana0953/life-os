import '../domain/water_day.dart';
import '../domain/water_repository.dart';

class GetWaterDay {
  final WaterRepository _repository;

  GetWaterDay(this._repository);

  Future<WaterDay> call(String idToken, String day) {
    return _repository.getDay(idToken, day);
  }
}
