import '../domain/vitals_repository.dart';
import '../domain/vitals_series.dart';

/// Use case: fetch the per-metric daily series over a date range.
class GetVitalsTrends {
  final VitalsRepository _repository;

  GetVitalsTrends(this._repository);

  Future<VitalsRange> call(String idToken, DateTime from, DateTime to) {
    return _repository.getRange(idToken, from, to);
  }
}
