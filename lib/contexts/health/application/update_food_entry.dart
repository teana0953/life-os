import '../domain/diet_log_repository.dart';
import '../domain/food_entry.dart';
import '../domain/portions.dart';

/// Use case: partially update one of the caller's own diet entries.
class UpdateFoodEntry {
  final DietLogRepository _repository;

  UpdateFoodEntry(this._repository);

  Future<FoodEntry> call(
    String idToken,
    String entryId, {
    String? name,
    String? meal,
    DateTime? eatenAt,
    Portions? portions,
  }) {
    return _repository.updateEntry(
      idToken,
      entryId,
      name: name,
      meal: meal,
      eatenAt: eatenAt,
      portions: portions,
    );
  }
}
