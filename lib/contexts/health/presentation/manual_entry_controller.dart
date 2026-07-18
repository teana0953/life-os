import 'package:flutter/foundation.dart';

import '../application/log_manual_entry.dart';
import '../domain/diet_exceptions.dart';
import '../domain/portions.dart';
import 'log_entry_controller.dart' show snackMealValue;

enum ManualEntryStatus { idle, saving, saved, error }

/// Reasons saving a manual entry can fail, as understood by the owning
/// screen (which has no [BuildContext]-free way to localize a message
/// here).
enum ManualEntryError { allZeroPortions, saveFailed, reauthRequired, unknown }

/// Drives the manual-entry form: name, four portion values, meal selection,
/// eaten-at time, and saving via [LogManualEntry]. Mirrors
/// [LogEntryController]'s shape for the dictionary-logging seam (D1 in
/// design.md).
class ManualEntryController extends ChangeNotifier {
  final LogManualEntry _logManualEntry;

  ManualEntryController(this._logManualEntry);

  String name = '';
  double staple = 0;
  double meat = 0;
  double fruit = 0;
  double veg = 0;
  String meal = 'breakfast';
  String snackLabel = '';
  DateTime eatenAt = DateTime.now();
  ManualEntryStatus status = ManualEntryStatus.idle;
  ManualEntryError? error;

  /// Resets the draft. Takes a [clock] (defaulting to [DateTime.now]) so
  /// callers/tests can pin the default eaten-at time.
  void start({DateTime Function() clock = DateTime.now}) {
    name = '';
    staple = 0;
    meat = 0;
    fruit = 0;
    veg = 0;
    meal = 'breakfast';
    snackLabel = '';
    eatenAt = clock();
    status = ManualEntryStatus.idle;
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

  void setEatenAt(DateTime value) {
    eatenAt = value;
    notifyListeners();
  }

  Future<bool> save(String idToken, String day) async {
    if (staple == 0 && meat == 0 && fruit == 0 && veg == 0) {
      status = ManualEntryStatus.error;
      error = ManualEntryError.allZeroPortions;
      notifyListeners();
      return false;
    }

    status = ManualEntryStatus.saving;
    error = null;
    notifyListeners();

    try {
      await _logManualEntry(
        idToken,
        day: day,
        meal: meal == snackMealValue && snackLabel.isNotEmpty
            ? snackLabel
            : meal,
        name: name.isEmpty ? null : name,
        portions: Portions(staple: staple, meat: meat, fruit: fruit, veg: veg),
        eatenAt: eatenAt,
      );
      status = ManualEntryStatus.saved;
      notifyListeners();
      return true;
    } on DietReauthenticationRequired {
      status = ManualEntryStatus.error;
      error = ManualEntryError.reauthRequired;
    } on DietFetchFailure {
      status = ManualEntryStatus.error;
      error = ManualEntryError.saveFailed;
    } catch (_) {
      status = ManualEntryStatus.error;
      error = ManualEntryError.unknown;
    }
    notifyListeners();
    return false;
  }
}
