import '../domain/meal_repository.dart';

/// Use case: change a meal's eaten-at time via
/// [MealRepository.patchMealTime].
class ChangeMealTime {
  final MealRepository _repository;

  ChangeMealTime(this._repository);

  Future<void> call(String idToken, String id, DateTime time) {
    return _repository.patchMealTime(idToken, id, time);
  }
}
