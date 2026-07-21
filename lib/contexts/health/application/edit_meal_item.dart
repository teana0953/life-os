import '../domain/meal_repository.dart';
import '../domain/portions.dart';

/// Use case: update one meal item's amount via
/// [MealRepository.patchMealItem].
class EditMealItem {
  final MealRepository _repository;

  EditMealItem(this._repository);

  Future<void> call(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) {
    return _repository.patchMealItem(
      idToken,
      id,
      quantity: quantity,
      measure: measure,
      portions: portions,
    );
  }
}
