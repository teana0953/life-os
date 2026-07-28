import 'chaodays_import_summary.dart';

/// Port for importing a date range of chaodays data into lifeos, one data
/// type at a time. The chaodays credentials are passed through on every call
/// and never persisted by an implementation.
abstract class ImportRepository {
  Future<ChaodaysImportSummary> importWeight(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  });

  Future<ChaodaysImportSummary> importDiet(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  });

  Future<ChaodaysImportSummary> importWater(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  });

  Future<ChaodaysImportSummary> importBowel(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  });

  Future<ChaodaysImportSummary> importDietTarget(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  });

  Future<ChaodaysImportSummary> importMenstrual(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  });
}
