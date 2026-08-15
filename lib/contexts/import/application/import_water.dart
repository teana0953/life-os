import '../domain/chaodays_import_summary.dart';
import '../domain/import_repository.dart';

class ImportWater {
  final ImportRepository _repository;

  ImportWater(this._repository);

  Future<ChaodaysImportSummary> call(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) {
    return _repository.importWater(
      idToken,
      chaodaysUid: chaodaysUid,
      chaodaysPassword: chaodaysPassword,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
