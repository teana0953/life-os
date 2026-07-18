import 'day_diet_log.dart';
import 'food_entry.dart';
import 'portions.dart';

/// Port for logging and reading a user's diet entries.
abstract class DietLogRepository {
  /// Logs a food entry from a dictionary item. `quantity` and `grams` are
  /// mutually exclusive; when both are omitted the backend defaults to a
  /// quantity of 1.
  Future<FoodEntry> logFromDictionary(
    String idToken, {
    required String day,
    required String meal,
    required String foodItemId,
    double? quantity,
    double? grams,
    DateTime? eatenAt,
  });

  /// Logs a food not in the dictionary: an optional [name] and per-group
  /// [portions], for [meal] eaten at [eatenAt]. No `food_item_id` is sent.
  Future<FoodEntry> logManualEntry(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
  });

  Future<DayDietLog> getDayLog(String idToken, String day);

  Future<void> deleteEntry(String idToken, String entryId);
}
