import '../domain/diet_log_repository.dart';

/// Use case: fetch the days within a month (`"YYYY-MM"`) that have at least
/// one logged entry.
class GetLoggedDays {
  final DietLogRepository _repository;

  GetLoggedDays(this._repository);

  Future<List<String>> call(String idToken, String month) {
    return _repository.loggedDays(idToken, month);
  }
}
