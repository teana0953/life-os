import '../domain/menstrual_period.dart';
import '../domain/menstrual_repository.dart';

/// Use case: record a new menstrual period.
class AddPeriod {
  final MenstrualRepository _repository;

  AddPeriod(this._repository);

  Future<MenstrualPeriod> call(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    return _repository.addPeriod(
      idToken,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
