import '../domain/menstrual_repository.dart';

class DeletePeriod {
  final MenstrualRepository _repository;

  DeletePeriod(this._repository);

  Future<bool> call(String idToken, String id) {
    return _repository.deletePeriod(idToken, id);
  }
}
