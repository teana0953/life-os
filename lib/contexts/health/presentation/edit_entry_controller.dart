import 'package:flutter/foundation.dart';

import '../application/delete_entry.dart';
import '../application/update_food_entry.dart';
import '../domain/diet_exceptions.dart';
import '../domain/food_entry.dart';
import '../domain/portions.dart';
import 'log_entry_controller.dart' show snackMealValue;

enum EditEntryStatus { idle, saving, saved, deleting, deleted, error }

/// Reasons saving/deleting an entry can fail, as understood by the owning
/// screen (which has no [BuildContext]-free way to localize a message
/// here).
enum EditEntryError { saveFailed, reauthRequired, unknown }

/// Drives the edit-entry bottom sheet: name, four portion values, meal
/// selection, and eaten-at time for an existing [FoodEntry], plus saving
/// (via [UpdateFoodEntry]) and deleting (via [DeleteEntry]). Mirrors
/// [ManualEntryController]'s shape (D5 in design.md).
///
/// `eatenAt` is dirty-tracked via [_eatenAtChanged], set only by
/// [setEatenAt]: the backend re-derives an entry's `day` from the UTC
/// calendar date of any supplied `eaten_at`, so [save] must omit it unless
/// the user actually changed the time — otherwise a portions-only edit
/// could silently move the entry to a different day.
class EditEntryController extends ChangeNotifier {
  final UpdateFoodEntry _updateFoodEntry;
  final DeleteEntry _deleteEntry;

  EditEntryController(this._updateFoodEntry, this._deleteEntry);

  String _entryId = '';
  String name = '';
  double staple = 0;
  double meat = 0;
  double fruit = 0;
  double veg = 0;
  String meal = 'breakfast';
  String snackLabel = '';
  DateTime eatenAt = DateTime.now();
  bool _eatenAtChanged = false;
  EditEntryStatus status = EditEntryStatus.idle;
  EditEntryError? error;

  /// Seeds the draft from [entry]. A standard meal (`breakfast`/`lunch`/
  /// `dinner`) is kept as-is; any other value is treated as a custom snack
  /// label (`meal` becomes [snackMealValue], `snackLabel` becomes the raw
  /// value), mirroring [ManualEntryController].
  void start(FoodEntry entry) {
    _entryId = entry.id;
    name = entry.name ?? '';
    staple = entry.staple;
    meat = entry.meat;
    fruit = entry.fruit;
    veg = entry.veg;
    if (entry.meal == 'breakfast' ||
        entry.meal == 'lunch' ||
        entry.meal == 'dinner') {
      meal = entry.meal;
      snackLabel = '';
    } else {
      meal = snackMealValue;
      snackLabel = entry.meal;
    }
    eatenAt = entry.eatenAt;
    _eatenAtChanged = false;
    status = EditEntryStatus.idle;
    error = null;
    notifyListeners();
  }

  void setName(String value) {
    name = value;
    notifyListeners();
  }

  /// Sets the portion value for one of `staple`/`meat`/`fruit`/`veg`.
  void setPortion(String category, double value) {
    switch (category) {
      case 'staple':
        staple = value;
      case 'meat':
        meat = value;
      case 'fruit':
        fruit = value;
      case 'veg':
        veg = value;
    }
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

  /// The only setter that marks `eatenAt` dirty (see class doc) — this is
  /// what lets [save] tell "user changed the time" apart from "still the
  /// entry's original time".
  void setEatenAt(DateTime value) {
    eatenAt = value;
    _eatenAtChanged = true;
    notifyListeners();
  }

  Future<bool> save(String idToken) async {
    status = EditEntryStatus.saving;
    error = null;
    notifyListeners();

    try {
      await _updateFoodEntry(
        idToken,
        _entryId,
        name: name.isEmpty ? null : name,
        meal: meal == snackMealValue && snackLabel.isNotEmpty
            ? snackLabel
            : meal,
        portions: Portions(staple: staple, meat: meat, fruit: fruit, veg: veg),
        eatenAt: _eatenAtChanged ? eatenAt : null,
      );
      status = EditEntryStatus.saved;
      notifyListeners();
      return true;
    } on DietReauthenticationRequired {
      status = EditEntryStatus.error;
      error = EditEntryError.reauthRequired;
    } on DietFetchFailure {
      status = EditEntryStatus.error;
      error = EditEntryError.saveFailed;
    } catch (_) {
      status = EditEntryStatus.error;
      error = EditEntryError.unknown;
    }
    notifyListeners();
    return false;
  }

  Future<bool> delete(String idToken) async {
    status = EditEntryStatus.deleting;
    error = null;
    notifyListeners();

    try {
      await _deleteEntry(idToken, _entryId);
      status = EditEntryStatus.deleted;
      notifyListeners();
      return true;
    } on DietReauthenticationRequired {
      status = EditEntryStatus.error;
      error = EditEntryError.reauthRequired;
    } on DietFetchFailure {
      status = EditEntryStatus.error;
      error = EditEntryError.saveFailed;
    } catch (_) {
      status = EditEntryStatus.error;
      error = EditEntryError.unknown;
    }
    notifyListeners();
    return false;
  }
}
