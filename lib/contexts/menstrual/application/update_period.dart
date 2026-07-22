import '../domain/menstrual_period.dart';
import '../domain/menstrual_repository.dart';

/// Use case: partially update a period — change its dates, or clear its end
/// date to reopen a completed period.
class UpdatePeriod {
  final MenstrualRepository _repository;

  UpdatePeriod(this._repository);

  Future<MenstrualPeriod> call(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return _repository.updatePeriod(
      idToken,
      id,
      startDate: startDate,
      endDate: endDate,
      clearEndDate: clearEndDate,
    );
  }
}
