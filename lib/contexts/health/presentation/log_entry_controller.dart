import 'package:flutter/foundation.dart';

import '../application/log_food_from_dictionary.dart';
import '../domain/diet_exceptions.dart';
import '../domain/food_item.dart';
import '../domain/portion_preview.dart';
import '../domain/portions.dart';

enum LogEntryStatus { idle, saving, saved, error }

/// Reasons saving a food entry can fail, as understood by the owning screen
/// (which has no [BuildContext]-free way to localize a message here).
enum LogEntryError { saveFailed, reauthRequired, unknown }

/// The three standard meals; any other value is treated as a custom snack
/// label (see [meal]/[snackLabel]).
const snackMealValue = 'snack';

/// Drives the quantity card: meal selection, unit/gram amount, live portion
/// preview (D2 in design.md), eaten-at time, and saving via
/// [LogFoodFromDictionary]. One instance is reused across log-entry actions
/// via [start].
class LogEntryController extends ChangeNotifier {
  final LogFoodFromDictionary _logFood;

  LogEntryController(this._logFood);

  FoodItem? item;
  String meal = 'breakfast';
  String snackLabel = '';
  bool useGrams = false;
  double quantity = 1;
  double grams = 0;
  DateTime eatenAt = DateTime.now();
  LogEntryStatus status = LogEntryStatus.idle;
  LogEntryError? error;

  /// Resets the card for logging [item]. Takes a [clock] (defaulting to
  /// [DateTime.now]) so callers/tests can pin the default eaten-at time.
  void start(FoodItem item, {DateTime Function() clock = DateTime.now}) {
    this.item = item;
    meal = 'breakfast';
    snackLabel = '';
    useGrams = false;
    quantity = 1;
    grams = 0;
    eatenAt = clock();
    status = LogEntryStatus.idle;
    error = null;
    notifyListeners();
  }

  void setMeal(String value) {
    meal = value;
    notifyListeners();
  }

  void setSnackLabel(String value) {
    snackLabel = value;
    notifyListeners();
  }

  void setUseGrams(bool value) {
    useGrams = value;
    notifyListeners();
  }

  void setQuantity(double value) {
    quantity = value;
    notifyListeners();
  }

  void setGrams(double value) {
    grams = value;
    notifyListeners();
  }

  void setEatenAt(DateTime value) {
    eatenAt = value;
    notifyListeners();
  }

  /// The live client-side portion preview (D2), or `null` when a gram
  /// amount can't yet be converted (no base grams, or non-positive input).
  Portions? get preview {
    final item = this.item;
    if (item == null) return null;
    if (useGrams) {
      final resolvedQuantity = quantityFromGrams(grams, item.baseGrams);
      if (resolvedQuantity == null) return null;
      return previewPortionsForQuantity(item, resolvedQuantity);
    }
    return previewPortionsForQuantity(item, quantity);
  }

  Future<bool> save(String idToken, String day) async {
    final item = this.item;
    if (item == null) return false;

    status = LogEntryStatus.saving;
    error = null;
    notifyListeners();

    try {
      await _logFood(
        idToken,
        day: day,
        meal: meal == snackMealValue && snackLabel.isNotEmpty
            ? snackLabel
            : meal,
        foodItemId: item.id,
        quantity: useGrams ? null : quantity,
        grams: useGrams ? grams : null,
        eatenAt: eatenAt,
      );
      status = LogEntryStatus.saved;
      notifyListeners();
      return true;
    } on DietReauthenticationRequired {
      status = LogEntryStatus.error;
      error = LogEntryError.reauthRequired;
    } on DietFetchFailure {
      status = LogEntryStatus.error;
      error = LogEntryError.saveFailed;
    } catch (_) {
      status = LogEntryStatus.error;
      error = LogEntryError.unknown;
    }
    notifyListeners();
    return false;
  }
}
