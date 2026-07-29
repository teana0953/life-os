import 'package:flutter/foundation.dart';

import '../application/add_water.dart';
import '../application/get_water_day.dart';
import '../application/set_water_target.dart';
import '../domain/water_day.dart';
import '../domain/water_exceptions.dart';

enum WaterStatus { loading, loaded, saving, error, needsReauth }

/// Reasons loading/saving the day's water can fail, as understood by
/// [WaterScreen].
enum WaterError { fetchFailed, unknown }

/// Drives the water screen: loads a day's total/target/remaining, adds or
/// corrects the total, and sets the target. Every mutation re-reads the day
/// from the backend rather than computing locally, so the displayed total
/// (already clamped ≥0 by the backend) and remaining stay consistent.
class WaterController extends ChangeNotifier {
  final GetWaterDay _getDay;
  final AddWater _addWater;
  final SetWaterTarget _setTarget;

  /// Injectable clock used to stamp [lastLoadedAt] on a successful load.
  /// Defaults to [DateTime.now]; tests pin it so the stamp is deterministic
  /// (mirrors the home greeting / reminders-throttle clocks).
  final DateTime Function() _clock;

  WaterController(
    this._getDay,
    this._addWater,
    this._setTarget, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  WaterStatus status = WaterStatus.loading;
  WaterDay? day;
  WaterError? error;

  /// When the day was last loaded successfully, or `null` before the first
  /// success — updated only on a successful [load], left unchanged on failure
  /// so it always reflects the data currently shown.
  DateTime? lastLoadedAt;

  Future<void> load(String idToken, String day) async {
    status = WaterStatus.loading;
    error = null;
    notifyListeners();

    try {
      this.day = await _getDay(idToken, day);
      status = WaterStatus.loaded;
      lastLoadedAt = _clock();
    } on WaterReauthenticationRequired {
      status = WaterStatus.needsReauth;
    } on WaterFetchFailure {
      status = WaterStatus.error;
      error = WaterError.fetchFailed;
    } catch (_) {
      status = WaterStatus.error;
      error = WaterError.unknown;
    }
    notifyListeners();
  }

  /// Adds [ml] to the day's total, then reloads the day.
  Future<void> addWater(String idToken, String day, int ml) =>
      _apply(idToken, day, () => _addWater(idToken, day: day, addMl: ml));

  /// Corrects the day's total by [ml] (typically negative), then reloads the
  /// day. The backend clamps the stored total at zero.
  Future<void> correct(String idToken, String day, int ml) =>
      _apply(idToken, day, () => _addWater(idToken, day: day, addMl: ml));

  /// Sets the day's target to [targetMl], then reloads the day.
  Future<void> setTarget(String idToken, String day, int targetMl) =>
      _apply(idToken, day, () => _setTarget(idToken, day: day, targetMl: targetMl));

  Future<void> _apply(
    String idToken,
    String day,
    Future<void> Function() mutation,
  ) async {
    status = WaterStatus.saving;
    notifyListeners();

    try {
      await mutation();
      await load(idToken, day);
      return;
    } on WaterReauthenticationRequired {
      status = WaterStatus.needsReauth;
    } on WaterFetchFailure {
      status = WaterStatus.error;
      error = WaterError.fetchFailed;
    } catch (_) {
      status = WaterStatus.error;
      error = WaterError.unknown;
    }
    notifyListeners();
  }
}
