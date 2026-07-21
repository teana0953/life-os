import '../domain/bowel_day.dart';
import '../domain/bowel_repository.dart';

/// Use case: fetch a day's bowel record.
class GetBowelDay {
  final BowelRepository _repository;

  GetBowelDay(this._repository);

  Future<BowelDay> call(String idToken, String day) {
    return _repository.getDay(idToken, day);
  }
}
