import 'package:flutter/foundation.dart';

import '../application/create_meal.dart';
import '../domain/diet_exceptions.dart';
import '../domain/food_item.dart';
import '../domain/meal_repository.dart';

enum CreateMealControllerStatus { editing, submitting, error, needsReauth }

/// Reasons submitting the tray can fail, as understood by the owning screen
/// (which has no [BuildContext]-free way to localize a message here).
enum CreateMealError { saveFailed, unknown }

/// One food added to the current-meal tray: the dictionary [item], the
/// entered [amount] (a unit quantity, or grams when [grams] is true), and
/// the current portion/gram mode.
class TrayItem {
  final FoodItem item;
  final double amount;
  final bool grams;

  const TrayItem({required this.item, required this.amount, this.grams = false});

  TrayItem copyWith({double? amount, bool? grams}) => TrayItem(
    item: item,
    amount: amount ?? this.amount,
    grams: grams ?? this.grams,
  );
}

/// Drives the food-search screen's current-meal tray: adding/removing/
/// adjusting items, and submitting the whole tray as one meal via
/// [CreateMeal]. [start] seeds (and resets) the session for a target [meal]
/// — called by the shell each time it pushes the search screen, so a
/// discarded (backed-out) tray never leaks into the next session.
class CreateMealController extends ChangeNotifier {
  final CreateMeal _createMeal;

  CreateMealController(this._createMeal);

  String meal = '';
  List<TrayItem> tray = [];
  CreateMealControllerStatus status = CreateMealControllerStatus.editing;
  CreateMealError? error;

  /// Resets the tray for a new search session targeting [meal] (a standard
  /// meal code, an existing snack's name, or the next snack name).
  void start(String meal) {
    this.meal = meal;
    tray = [];
    status = CreateMealControllerStatus.editing;
    error = null;
    notifyListeners();
  }

  /// Adds [item] to the tray at a default quantity of 1 (unit mode).
  void add(FoodItem item) {
    tray = [...tray, TrayItem(item: item, amount: 1)];
    notifyListeners();
  }

  void remove(TrayItem trayItem) {
    tray = tray.where((t) => t != trayItem).toList();
    notifyListeners();
  }

  void setAmount(TrayItem trayItem, double amount) {
    final index = tray.indexOf(trayItem);
    if (index == -1) return;
    tray = [...tray]..[index] = trayItem.copyWith(amount: amount);
    notifyListeners();
  }

  /// Switches [trayItem] between quantity and gram mode, resetting the
  /// amount so it isn't misread in the new unit (D5): grams mode seeds the
  /// item's `baseGrams` (so the preview starts at ~1 unit's worth rather
  /// than a near-zero gram amount), quantity mode resets to 1.
  void toggleGrams(TrayItem trayItem, bool grams) {
    final index = tray.indexOf(trayItem);
    if (index == -1) return;
    final amount = grams ? (trayItem.item.baseGrams ?? trayItem.amount) : 1.0;
    tray = [...tray]..[index] = trayItem.copyWith(amount: amount, grams: grams);
    notifyListeners();
  }

  /// Saves the whole tray as one meal (dictionary items only), sending each
  /// row's amount as `grams` (gram mode) or `quantity` (unit mode) — never
  /// both. Rows cleared to zero (the numeric empty-zero convention) are
  /// treated as unset and dropped rather than sent as `quantity: 0`/
  /// `grams: 0`, which the backend rejects. If every row is zero, there is
  /// nothing to save, so this returns without calling the backend. The
  /// meal's `time` is omitted, so the backend defaults it to now for a newly
  /// created meal.
  Future<bool> submit(String idToken, String day) async {
    final items = tray
        .where((t) => t.amount > 0)
        .map(
          (t) => CreateMealItem.dictionary(
            t.item.id,
            quantity: t.grams ? null : t.amount,
            grams: t.grams ? t.amount : null,
          ),
        )
        .toList();
    if (items.isEmpty) return false;

    status = CreateMealControllerStatus.submitting;
    error = null;
    notifyListeners();

    try {
      await _createMeal(idToken, day: day, meal: meal, items: items);
      status = CreateMealControllerStatus.editing;
      notifyListeners();
      return true;
    } on DietReauthenticationRequired {
      status = CreateMealControllerStatus.needsReauth;
    } on DietFetchFailure {
      status = CreateMealControllerStatus.error;
      error = CreateMealError.saveFailed;
    } catch (_) {
      status = CreateMealControllerStatus.error;
      error = CreateMealError.unknown;
    }
    notifyListeners();
    return false;
  }
}
