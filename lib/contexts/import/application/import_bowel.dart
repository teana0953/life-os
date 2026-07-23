import '../domain/chaodays_import_summary.dart';
import '../domain/import_repository.dart';

/// Use case: import a date range of bowel data from chaodays.
class ImportBowel {
  final ImportRepository _repository;

  ImportBowel(this._repository);

  Future<ChaodaysImportSummary> call(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) {
    return _repository.importBowel(
      idToken,
      chaodaysUid: chaodaysUid,
      chaodaysPassword: chaodaysPassword,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
