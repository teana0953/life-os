import '../domain/day_diet_log.dart';
import '../domain/diet_log_repository.dart';

/// Use case: fetch a day's diet log.
class GetDayDietLog {
  final DietLogRepository _repository;

  GetDayDietLog(this._repository);

  Future<DayDietLog> call(String idToken, String day) {
    return _repository.getDayLog(idToken, day);
  }
}
