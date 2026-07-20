import '../domain/meal_entry.dart';
import '../domain/meal_repository.dart';

/// Use case: create a meal (or append items to an existing one) via
/// [MealRepository.createMeal].
class CreateMeal {
  final MealRepository _repository;

  CreateMeal(this._repository);

  Future<MealEntry> call(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  }) {
    return _repository.createMeal(
      idToken,
      day: day,
      meal: meal,
      time: time,
      items: items,
    );
  }
}
