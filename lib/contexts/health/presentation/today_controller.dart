import 'package:flutter/foundation.dart';

import '../application/change_meal_time.dart';
import '../application/delete_meal.dart';
import '../application/delete_meal_item.dart';
import '../application/edit_meal_item.dart';
import '../application/get_day_meals.dart';
import '../application/get_daily_target_with_remaining.dart';
import '../domain/day_meals_log.dart';
import '../domain/daily_target.dart';
import '../domain/diet_exceptions.dart';
import '../domain/portions.dart';

enum TodayStatus { loading, loaded, error, needsReauth }

/// Reasons loading today's diet data (or a mutation) can fail, as
/// understood by [TodayScreen]. [TodayController] has no [BuildContext] and
/// so cannot hold a localized message directly — the screen maps this to
/// text at build time.
enum TodayError { fetchFailed, unknown, notFound }

/// Drives the Today section: the day's meals log (read via the meals API),
/// per-category portion progress against the day's target, and in-place
/// mutations (edit/delete an item, change a meal's time, delete a meal).
class TodayController extends ChangeNotifier {
  final GetDayMeals _getDayMeals;
  final GetDailyTargetWithRemaining _getDailyTargetWithRemaining;
  final EditMealItem _editMealItem;
  final DeleteMealItem _deleteMealItem;
  final ChangeMealTime _changeMealTime;
  final DeleteMeal _deleteMeal;

  TodayController(
    this._getDayMeals,
    this._getDailyTargetWithRemaining,
    this._editMealItem,
    this._deleteMealItem,
    this._changeMealTime,
    this._deleteMeal,
  );

  TodayStatus status = TodayStatus.loading;
  DayMealsLog? dayMealsLog;
  DailyTargetWithRemaining? target;
  TodayError? error;

  Future<void> load(String idToken, String day) async {
    status = TodayStatus.loading;
    error = null;
    notifyListeners();

    try {
      dayMealsLog = await _getDayMeals(idToken, day);
      target = await _getDailyTargetWithRemaining(idToken, day);
      status = TodayStatus.loaded;
    } on DietReauthenticationRequired {
      status = TodayStatus.needsReauth;
    } on DietFetchFailure {
      status = TodayStatus.error;
      error = TodayError.fetchFailed;
    } catch (_) {
      status = TodayStatus.error;
      error = TodayError.unknown;
    }
    notifyListeners();
  }

  /// Runs a mutation [action], then refreshes [day] from the backend on
  /// success (the backend is authoritative for recomputed portions/totals —
  /// no optimistic local mutation). Maps reauth/not-found/failure to the
  /// controller's typed state, which the screen already renders.
  Future<void> _mutate(String idToken, String day, Future<void> Function() action) async {
    try {
      await action();
      await load(idToken, day);
    } on DietReauthenticationRequired {
      status = TodayStatus.needsReauth;
      notifyListeners();
    } on DietNotFound {
      status = TodayStatus.error;
      error = TodayError.notFound;
      notifyListeners();
    } on DietFetchFailure {
      status = TodayStatus.error;
      error = TodayError.fetchFailed;
      notifyListeners();
    } catch (_) {
      status = TodayStatus.error;
      error = TodayError.unknown;
      notifyListeners();
    }
  }

  /// Edits a meal item's amount: exactly one of [quantity] / [measure] /
  /// [portions] should be given.
  Future<void> editItem(
    String idToken,
    String day,
    String itemId, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) {
    return _mutate(
      idToken,
      day,
      () => _editMealItem(idToken, itemId, quantity: quantity, measure: measure, portions: portions),
    );
  }

  Future<void> deleteItem(String idToken, String day, String itemId) {
    return _mutate(idToken, day, () => _deleteMealItem(idToken, itemId));
  }

  Future<void> changeMealTime(String idToken, String day, String mealId, DateTime time) {
    return _mutate(idToken, day, () => _changeMealTime(idToken, mealId, time));
  }

  Future<void> deleteMeal(String idToken, String day, String mealId) {
    return _mutate(idToken, day, () => _deleteMeal(idToken, mealId));
  }
}
