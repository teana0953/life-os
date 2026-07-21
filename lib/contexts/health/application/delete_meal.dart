import '../domain/meal_repository.dart';

/// Use case: delete a meal (cascading to its items) via
/// [MealRepository.deleteMeal].
class DeleteMeal {
  final MealRepository _repository;

  DeleteMeal(this._repository);

  Future<void> call(String idToken, String id) {
    return _repository.deleteMeal(idToken, id);
  }
}
