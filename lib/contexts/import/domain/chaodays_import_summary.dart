/// The result of importing one data type from chaodays: how many records
/// were imported vs. skipped (already present). Diet imports also carry
/// [glucoseImported] (glucose readings are imported alongside meals); the
/// other three types leave it `null`.
class ChaodaysImportSummary {
  final int imported;
  final int skipped;
  final int? glucoseImported;

  const ChaodaysImportSummary({
    required this.imported,
    required this.skipped,
    this.glucoseImported,
  });
}
