import '../domain/bowel_day.dart';
import '../domain/bowel_repository.dart';

/// Use case: upsert a day's whole bowel record. Returns the saved record.
class SaveBowelDay {
  final BowelRepository _repository;

  SaveBowelDay(this._repository);

  Future<BowelDay> call(
    String idToken, {
    required String day,
    required int count,
    required bool? isNormal,
    required String note,
  }) {
    return _repository.save(
      idToken,
      day: day,
      count: count,
      isNormal: isNormal,
      note: note,
    );
  }
}
