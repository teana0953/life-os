import 'vitals_day.dart';

/// Port for reading and upserting a day's vitals record.
abstract class VitalsRepository {
  Future<VitalsDay> getDay(String idToken, String day);

  /// Upserts the whole day's record. Returns the saved record.
  Future<VitalsDay> save(String idToken, VitalsDay day);
}
