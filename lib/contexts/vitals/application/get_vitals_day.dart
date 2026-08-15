import '../domain/vitals_day.dart';
import '../domain/vitals_repository.dart';

class GetVitalsDay {
  final VitalsRepository _repository;

  GetVitalsDay(this._repository);

  Future<VitalsDay> call(String idToken, String day) {
    return _repository.getDay(idToken, day);
  }
}
