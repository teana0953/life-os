import '../domain/chaodays_import_summary.dart';
import '../domain/import_repository.dart';

/// Use case: import a date range of weight/body-fat data from chaodays.
class ImportWeight {
  final ImportRepository _repository;

  ImportWeight(this._repository);

  Future<ChaodaysImportSummary> call(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) {
    return _repository.importWeight(
      idToken,
      chaodaysUid: chaodaysUid,
      chaodaysPassword: chaodaysPassword,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
