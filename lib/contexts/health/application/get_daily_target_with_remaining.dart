import '../domain/daily_target.dart';
import '../domain/daily_target_repository.dart';

/// Use case: fetch a day's effective target and remaining portions.
class GetDailyTargetWithRemaining {
  final DailyTargetRepository _repository;

  GetDailyTargetWithRemaining(this._repository);

  Future<DailyTargetWithRemaining> call(String idToken, String day) {
    return _repository.getTarget(idToken, day);
  }
}
