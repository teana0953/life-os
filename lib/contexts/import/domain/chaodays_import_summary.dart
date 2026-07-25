/// The result of importing one data type from chaodays: how many records
/// were imported vs. skipped (already present). Diet imports also carry
/// [glucoseImported] (glucose readings are imported alongside meals); diet-
/// target imports carry [waterTargetsImported] (the water target is imported
/// alongside the daily portion targets); the other types leave both `null`.
class ChaodaysImportSummary {
  final int imported;
  final int skipped;
  final int? glucoseImported;
  final int? waterTargetsImported;

  const ChaodaysImportSummary({
    required this.imported,
    required this.skipped,
    this.glucoseImported,
    this.waterTargetsImported,
  });
}
