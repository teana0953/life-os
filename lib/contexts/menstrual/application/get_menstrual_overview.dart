import '../domain/menstrual_period.dart';
import '../domain/menstrual_repository.dart';

/// Use case: fetch the whole menstrual overview (periods + stats + last period).
class GetMenstrualOverview {
  final MenstrualRepository _repository;

  GetMenstrualOverview(this._repository);

  Future<MenstrualOverview> call(String idToken) {
    return _repository.getOverview(idToken);
  }
}
