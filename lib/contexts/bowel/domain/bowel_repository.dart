import 'bowel_day.dart';

abstract class BowelRepository {
  Future<BowelDay> getDay(String idToken, String day);

  /// Upserts the whole day's record. Returns the saved record.
  Future<BowelDay> save(
    String idToken, {
    required String day,
    required int count,
    required bool? isNormal,
    required String note,
  });
}
