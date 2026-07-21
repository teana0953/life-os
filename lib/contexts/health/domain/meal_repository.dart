import 'day_meals_log.dart';
import 'meal_entry.dart';
import 'portions.dart';

/// Port for reading a day's meals, creating/appending a meal's items, and
/// mutating (edit/delete) an existing meal or item.
abstract class MealRepository {
  Future<DayMealsLog> getDayMeals(String idToken, String day);

  /// Creates a meal (or appends [items] to it, if `(day, meal)` already
  /// exists) via `POST /api/meals`. [time] is the meal's eaten-at time,
  /// defaulted to now by the backend when a new meal is created and omitted
  /// (`null`).
  Future<MealEntry> createMeal(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  });

  /// The days within [month] (`"YYYY-MM"`) that have at least one meal.
  Future<List<String>> loggedDays(String idToken, String month);

  /// Updates one meal item via `PATCH /api/meal-items/:id`: exactly one of
  /// [quantity] / [measure] / [portions] should be given (mutually
  /// exclusive on the wire, enforced by the backend). Throws [DietNotFound]
  /// when [id] doesn't exist or isn't owned by the caller.
  Future<void> patchMealItem(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  });

  /// Deletes one meal item via `DELETE /api/meal-items/:id`. Throws
  /// [DietNotFound] when [id] doesn't exist or isn't owned by the caller.
  Future<void> deleteMealItem(String idToken, String id);

  /// Updates a meal's eaten-at time via `PATCH /api/meals/:id` (the meal's
  /// day is unchanged). Throws [DietNotFound] when [id] doesn't exist or
  /// isn't owned by the caller.
  Future<void> patchMealTime(String idToken, String id, DateTime time);

  /// Deletes a meal (cascading to its items) via `DELETE /api/meals/:id`.
  /// Throws [DietNotFound] when [id] doesn't exist or isn't owned by the
  /// caller.
  Future<void> deleteMeal(String idToken, String id);
}

/// A request item for [MealRepository.createMeal]: either a dictionary item
/// identified by [foodItemId] (with [quantity] and [measure] mutually
/// exclusive), or a manually-entered item carrying a [name] and [portions]
/// (no dictionary reference).
class CreateMealItem {
  final String? foodItemId;
  final double? quantity;
  final double? measure;
  final String? name;
  final Portions? portions;

  const CreateMealItem._({
    this.foodItemId,
    this.quantity,
    this.measure,
    this.name,
    this.portions,
  });

  factory CreateMealItem.dictionary(
    String foodItemId, {
    double? quantity,
    double? measure,
  }) {
    assert(
      !(quantity != null && measure != null),
      'quantity and measure are mutually exclusive',
    );
    return CreateMealItem._(
      foodItemId: foodItemId,
      quantity: quantity,
      measure: measure,
    );
  }

  factory CreateMealItem.manual(String name, Portions portions) {
    return CreateMealItem._(name: name, portions: portions);
  }
}
