import 'vitals_day.dart';
import 'vitals_series.dart';

/// Port for reading and upserting a day's vitals record.
abstract class VitalsRepository {
  Future<VitalsDay> getDay(String idToken, String day);

  /// Upserts the whole day's record. Returns the saved record.
  Future<VitalsDay> save(String idToken, VitalsDay day);

  /// Reads the per-metric daily series over the [from]..[to] date range
  /// (inclusive), each date formatted "YYYY-MM-DD".
  Future<VitalsRange> getRange(String idToken, DateTime from, DateTime to);
}
