import '../domain/day_meals_log.dart';
import '../domain/meal_repository.dart';

/// Use case: fetch a day's meals log.
class GetDayMeals {
  final MealRepository _repository;

  GetDayMeals(this._repository);

  Future<DayMealsLog> call(String idToken, String day) {
    return _repository.getDayMeals(idToken, day);
  }
}
