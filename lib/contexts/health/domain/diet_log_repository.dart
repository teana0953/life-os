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

  /// Partially updates an existing entry: only the non-null named
  /// parameters are sent. Sending [eatenAt] re-derives the entry's `day`
  /// from its UTC calendar date on the backend, so callers MUST omit it
  /// (pass `null`) unless the user actually changed the time — otherwise a
  /// portions-only edit can silently move the entry to a different day.
  Future<FoodEntry> updateEntry(
    String idToken,
    String entryId, {
    String? name,
    String? meal,
    DateTime? eatenAt,
    Portions? portions,
  });

  /// The days within [month] (`"YYYY-MM"`) that have at least one entry.
  Future<List<String>> loggedDays(String idToken, String month);
}
