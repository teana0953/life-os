import '../domain/vitals_day.dart';
import '../domain/vitals_repository.dart';

/// Use case: upsert a day's whole vitals record. Returns the saved record.
class SaveVitalsDay {
  final VitalsRepository _repository;

  SaveVitalsDay(this._repository);

  Future<VitalsDay> call(String idToken, VitalsDay day) {
    return _repository.save(idToken, day);
  }
}
