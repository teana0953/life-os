import 'day_meals_log.dart';
import 'meal_entry.dart';

/// Port for reading a day's meals and creating/appending a meal's items.
/// This PR's surface only — per-meal time changes and item edit/delete
/// (`PATCH`/`DELETE`) are PR③.
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
}

/// A request item for [MealRepository.createMeal]: a dictionary item
/// identified by [foodItemId], with [quantity] and [grams] mutually
/// exclusive. No manual-item variant this PR (the tray adds dictionary items
/// only — CLAUDE.md §2, no speculative code).
class CreateMealItem {
  final String foodItemId;
  final double? quantity;
  final double? grams;

  const CreateMealItem._({
    required this.foodItemId,
    this.quantity,
    this.grams,
  });

  factory CreateMealItem.dictionary(
    String foodItemId, {
    double? quantity,
    double? grams,
  }) {
    assert(
      !(quantity != null && grams != null),
      'quantity and grams are mutually exclusive',
    );
    return CreateMealItem._(
      foodItemId: foodItemId,
      quantity: quantity,
      grams: grams,
    );
  }
}
