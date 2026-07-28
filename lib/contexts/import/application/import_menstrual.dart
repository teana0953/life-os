import '../domain/chaodays_import_summary.dart';
import '../domain/import_repository.dart';

/// Use case: import a date range of menstrual-period data from chaodays.
class ImportMenstrual {
  final ImportRepository _repository;

  ImportMenstrual(this._repository);

  Future<ChaodaysImportSummary> call(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) {
    return _repository.importMenstrual(
      idToken,
      chaodaysUid: chaodaysUid,
      chaodaysPassword: chaodaysPassword,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
