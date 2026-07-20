import '../domain/meal_repository.dart';

/// Use case: fetch the days within a month (`"YYYY-MM"`) that have at least
/// one logged meal.
class GetLoggedDays {
  final MealRepository _repository;

  GetLoggedDays(this._repository);

  Future<List<String>> call(String idToken, String month) {
    return _repository.loggedDays(idToken, month);
  }
}
