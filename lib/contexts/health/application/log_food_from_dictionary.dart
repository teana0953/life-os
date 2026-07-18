import '../domain/diet_log_repository.dart';
import '../domain/food_entry.dart';

/// Use case: log a food entry from a dictionary item, by quantity or by
/// grams (mutually exclusive).
class LogFoodFromDictionary {
  final DietLogRepository _repository;

  LogFoodFromDictionary(this._repository);

  Future<FoodEntry> call(
    String idToken, {
    required String day,
    required String meal,
    required String foodItemId,
    double? quantity,
    double? grams,
    DateTime? eatenAt,
  }) {
    if (quantity != null && grams != null) {
      throw ArgumentError('quantity and grams are mutually exclusive');
    }
    return _repository.logFromDictionary(
      idToken,
      day: day,
      meal: meal,
      foodItemId: foodItemId,
      quantity: quantity,
      grams: grams,
      eatenAt: eatenAt,
    );
  }
}
