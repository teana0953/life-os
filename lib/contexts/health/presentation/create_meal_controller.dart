import 'package:flutter/foundation.dart';

import '../application/create_meal.dart';
import '../domain/diet_exceptions.dart';
import '../domain/food_item.dart';
import '../domain/meal_repository.dart';
import '../domain/portions.dart';

enum CreateMealControllerStatus { editing, submitting, error, needsReauth }

/// Reasons submitting the tray can fail, as understood by the owning screen
/// (which has no [BuildContext]-free way to localize a message here).
enum CreateMealError { saveFailed, unknown }

/// A row in the current-meal tray: either a dictionary [TrayItem] (an
/// adjustable amount with a live per-unit-scaled preview) or a
/// [ManualTrayItem] (fixed, user-entered portions, no dictionary
/// reference).
sealed class TrayEntry {
  const TrayEntry();
}

/// One dictionary food added to the current-meal tray: the [item], the
/// entered [amount] (a unit quantity, or a measure amount when
/// [measureMode] is true), and the current portion/measure mode.
class TrayItem extends TrayEntry {
  final FoodItem item;
  final double amount;
  final bool measureMode;

  const TrayItem({required this.item, required this.amount, this.measureMode = false});

  TrayItem copyWith({double? amount, bool? measureMode}) => TrayItem(
    item: item,
    amount: amount ?? this.amount,
    measureMode: measureMode ?? this.measureMode,
  );
}

/// One manually-entered food added to the current-meal tray: a [name] and
/// the entered [portions] directly — no dictionary reference, no per-unit ×
/// quantity scaling.
class ManualTrayItem extends TrayEntry {
  final String name;
  final Portions portions;

  const ManualTrayItem({required this.name, required this.portions});

  ManualTrayItem copyWith({String? name, Portions? portions}) => ManualTrayItem(
    name: name ?? this.name,
    portions: portions ?? this.portions,
  );
}

/// Drives the food-search screen's current-meal tray: adding/removing/
/// adjusting items (dictionary and manual), and submitting the whole tray
/// as one meal via [CreateMeal]. [start] seeds (and resets) the session for
/// a target [meal] — called by the shell each time it pushes the search
/// screen, so a discarded (backed-out) tray never leaks into the next
/// session.
class CreateMealController extends ChangeNotifier {
  final CreateMeal _createMeal;

  CreateMealController(this._createMeal);

  String? meal;
  List<TrayEntry> tray = [];
  CreateMealControllerStatus status = CreateMealControllerStatus.editing;
  CreateMealError? error;

  /// Presentation-only "an item was just added" signal for the tray view to
  /// distinguish a genuine add (auto-scroll + highlight) from a remove or
  /// amount change. [addTick] increments on every [add]/[addManual];
  /// [lastAdded] points at the entry that add produced. Neither changes on
  /// [remove]/[setAmount]/[toggleMeasure].
  int addTick = 0;
  TrayEntry? lastAdded;

  /// Resets the tray for a new search session targeting [meal] (a standard
  /// meal code, an existing snack's name, or the next snack name) — or `null`
  /// for a dictionary session, where the meal isn't known yet and is bound
  /// later via [bindMeal].
  void start(String? meal) {
    this.meal = meal;
    tray = [];
    status = CreateMealControllerStatus.editing;
    error = null;
    addTick = 0;
    lastAdded = null;
    notifyListeners();
  }

  /// Binds the target [meal] for a session started without one (the
  /// dictionary), just before submitting.
  void bindMeal(String meal) {
    this.meal = meal;
    notifyListeners();
  }

  /// Adds [item] to the tray at a default quantity of 1 (unit mode).
  void add(FoodItem item) {
    final entry = TrayItem(item: item, amount: 1);
    tray = [...tray, entry];
    lastAdded = entry;
    addTick++;
    notifyListeners();
  }

  /// Adds a manually-entered food (no dictionary reference) with the given
  /// [name] and [portions] to the tray.
  void addManual(String name, Portions portions) {
    final entry = ManualTrayItem(name: name, portions: portions);
    tray = [...tray, entry];
    lastAdded = entry;
    addTick++;
    notifyListeners();
  }

  void remove(TrayEntry entry) {
    tray = tray.where((t) => t != entry).toList();
    notifyListeners();
  }

  void setAmount(TrayItem trayItem, double amount) {
    final index = tray.indexOf(trayItem);
    if (index == -1) return;
    tray = [...tray]..[index] = trayItem.copyWith(amount: amount);
    notifyListeners();
  }

  /// Switches [trayItem] between quantity and measure mode, resetting the
  /// amount so it isn't misread in the new unit (D5): measure mode seeds
  /// the item's `baseAmount` (so the preview starts at ~1 unit's worth
  /// rather than a near-zero measure amount), quantity mode resets to 1.
  void toggleMeasure(TrayItem trayItem, bool measureMode) {
    final index = tray.indexOf(trayItem);
    if (index == -1) return;
    final amount = measureMode ? (trayItem.item.baseAmount ?? trayItem.amount) : 1.0;
    tray = [...tray]..[index] = trayItem.copyWith(amount: amount, measureMode: measureMode);
    notifyListeners();
  }

  /// Saves the whole tray as one meal: each dictionary row sends its
  /// amount as `measure` (measure mode) or `quantity` (unit mode) — never
  /// both — and each manual row sends its name and portions. A dictionary
  /// row cleared to zero (the numeric empty-zero convention) is treated as
  /// unset and dropped rather than sent as `quantity: 0`/`measure: 0`,
  /// which the backend rejects. If the tray ends up empty, there is nothing
  /// to save, so this returns without calling the backend — likewise when no
  /// target [meal] is bound yet (a dictionary session whose meal prompt was
  /// dismissed), which is not a failure, so the session stays editable. The
  /// meal's `time` is omitted, so the backend defaults it to now for a newly
  /// created meal.
  Future<bool> submit(String idToken, String day) async {
    final meal = this.meal;
    if (meal == null) return false;

    final items = <CreateMealItem>[];
    for (final entry in tray) {
      switch (entry) {
        case TrayItem():
          if (entry.amount <= 0) continue;
          items.add(
            CreateMealItem.dictionary(
              entry.item.id,
              quantity: entry.measureMode ? null : entry.amount,
              measure: entry.measureMode ? entry.amount : null,
            ),
          );
        case ManualTrayItem():
          items.add(CreateMealItem.manual(entry.name, entry.portions));
      }
    }
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
