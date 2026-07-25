import '../domain/chaodays_import_summary.dart';
import '../domain/import_repository.dart';

/// Use case: import a date range of daily portion + water target data from
/// chaodays.
class ImportDietTarget {
  final ImportRepository _repository;

  ImportDietTarget(this._repository);

  Future<ChaodaysImportSummary> call(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) {
    return _repository.importDietTarget(
      idToken,
      chaodaysUid: chaodaysUid,
      chaodaysPassword: chaodaysPassword,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
