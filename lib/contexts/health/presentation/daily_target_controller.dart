import 'package:flutter/foundation.dart';

import '../application/get_daily_target_with_remaining.dart';
import '../application/set_daily_target.dart';
import '../domain/daily_target.dart';
import '../domain/diet_exceptions.dart';

enum DailyTargetStatus { loading, loaded, saving, error, needsReauth }

/// Reasons loading/saving the daily target can fail, as understood by
/// [DailyTargetScreen].
enum DailyTargetError { fetchFailed, unknown }

/// Drives the Target section: the day's effective target + remaining, and
/// editing/saving the base per-category goals. Saving preserves the
/// previously fetched bonus values (the backend defaults an omitted bonus
/// to 0) since this screen doesn't expose bonus editing.
class DailyTargetController extends ChangeNotifier {
  final GetDailyTargetWithRemaining _getTarget;
  final SetDailyTarget _setTarget;

  DailyTargetController(this._getTarget, this._setTarget);

  DailyTargetStatus status = DailyTargetStatus.loading;
  DailyTargetWithRemaining? target;
  DailyTargetError? error;

  double draftBaseStaple = 0;
  double draftBaseMeat = 0;
  double draftBaseFruit = 0;
  double draftBaseVeg = 0;

  Future<void> load(String idToken, String day) async {
    status = DailyTargetStatus.loading;
    error = null;
    notifyListeners();

    try {
      target = await _getTarget(idToken, day);
      draftBaseStaple = target!.base.staple;
      draftBaseMeat = target!.base.meat;
      draftBaseFruit = target!.base.fruit;
      draftBaseVeg = target!.base.veg;
      status = DailyTargetStatus.loaded;
    } on DietReauthenticationRequired {
      status = DailyTargetStatus.needsReauth;
    } on DietFetchFailure {
      status = DailyTargetStatus.error;
      error = DailyTargetError.fetchFailed;
    } catch (_) {
      status = DailyTargetStatus.error;
      error = DailyTargetError.unknown;
    }
    notifyListeners();
  }

  void setDraftBaseStaple(double value) {
    draftBaseStaple = value;
    notifyListeners();
  }

  void setDraftBaseMeat(double value) {
    draftBaseMeat = value;
    notifyListeners();
  }

  void setDraftBaseFruit(double value) {
    draftBaseFruit = value;
    notifyListeners();
  }

  void setDraftBaseVeg(double value) {
    draftBaseVeg = value;
    notifyListeners();
  }

  Future<bool> save(String idToken, String day) async {
    status = DailyTargetStatus.saving;
    notifyListeners();

    try {
      await _setTarget(
        idToken,
        day: day,
        baseStaple: draftBaseStaple,
        baseMeat: draftBaseMeat,
        baseFruit: draftBaseFruit,
        baseVeg: draftBaseVeg,
        bonusStaple: target?.bonus.staple,
        bonusMeat: target?.bonus.meat,
        bonusFruit: target?.bonus.fruit,
        bonusVeg: target?.bonus.veg,
      );
      await load(idToken, day);
      return true;
    } on DietReauthenticationRequired {
      status = DailyTargetStatus.needsReauth;
    } on DietFetchFailure {
      status = DailyTargetStatus.error;
      error = DailyTargetError.fetchFailed;
    } catch (_) {
      status = DailyTargetStatus.error;
      error = DailyTargetError.unknown;
    }
    notifyListeners();
    return false;
  }
}
