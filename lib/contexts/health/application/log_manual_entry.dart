import '../domain/diet_log_repository.dart';
import '../domain/food_entry.dart';
import '../domain/portions.dart';

/// Use case: log a food not in the dictionary, by name (optional) and
/// per-group portions.
class LogManualEntry {
  final DietLogRepository _repository;

  LogManualEntry(this._repository);

  Future<FoodEntry> call(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
  }) {
    if (portions.staple == 0 &&
        portions.meat == 0 &&
        portions.fruit == 0 &&
        portions.veg == 0) {
      throw ArgumentError('portions must not be all zero');
    }
    return _repository.logManualEntry(
      idToken,
      day: day,
      meal: meal,
      name: name,
      portions: portions,
      eatenAt: eatenAt,
    );
  }
}
