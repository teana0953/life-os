import '../domain/meal_repository.dart';

class DeleteMealItem {
  final MealRepository _repository;

  DeleteMealItem(this._repository);

  Future<void> call(String idToken, String id) {
    return _repository.deleteMealItem(idToken, id);
  }
}
