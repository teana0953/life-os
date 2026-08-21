import 'package:flutter/foundation.dart';

import '../../../shared/screen_batch/section_outcome.dart';
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

  /// The day each UNSETTLED [load] is fetching, keyed by a per-call request
  /// id it removes only in its own `finally` — the same claim registry
  /// [TodayController] carries, and for the same reason: a single field is
  /// cleared by whichever interleaved load finishes first, which reports "no
  /// load in flight" while one still is.
  final Map<int, String> _pendingDays = {};
  int _nextRequestId = 0;

  /// Whether a [load] for exactly [day] is in flight (day-keyed on purpose —
  /// see [TodayController.isLoadingDay]).
  bool isLoadingDay(String day) => _pendingDays.containsValue(day);

  /// Whether the controller currently HOLDS [day]'s target.
  bool holdsDay(String day) => target?.day == day;

  /// The generation a whole-screen batch round has claimed, via
  /// [claimBatchRound]. Compared against [_nextRequestId] (already bumped
  /// synchronously by every [load], before its first `await`) in
  /// [applyBatchSection] instead of comparing days — see
  /// [TodayController._claimedGeneration] for why.
  int? _claimedGeneration;

  /// Records the generation a whole-screen batch round is about to fetch
  /// for. Call synchronously, before the round's request goes out — mirrors
  /// [HealthCalendarController.claimBatchMonth].
  void claimBatchRound() => _claimedGeneration = _nextRequestId;

  double draftBaseStaple = 0;
  double draftBaseMeat = 0;
  double draftBaseFruit = 0;
  double draftBaseVeg = 0;

  Future<void> load(String idToken, String day) async {
    final requestId = _nextRequestId++;
    _pendingDays[requestId] = day;
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
    } finally {
      // Only this call's own claim — removing anyone else's is exactly the
      // early-clear a single field suffers from.
      _pendingDays.remove(requestId);
    }
    notifyListeners();
  }

  /// Applies the batched `daily_target` section for [day] — the same section
  /// instance [TodayController] gets, which is what removes the second
  /// per-load request for the day's target.
  ///
  /// Dropped when a [load] has started — or already landed — since the round
  /// that produced this section was claimed via [claimBatchRound] (see
  /// [TodayController.applyBatchSection]).
  void applyBatchSection(SectionOutcome<DailyTargetWithRemaining> section) {
    if (_claimedGeneration != _nextRequestId) return;
    error = null;
    switch (section) {
      case SectionOk<DailyTargetWithRemaining>(:final value):
        target = value;
        draftBaseStaple = value.base.staple;
        draftBaseMeat = value.base.meat;
        draftBaseFruit = value.base.fruit;
        draftBaseVeg = value.base.veg;
        status = DailyTargetStatus.loaded;
      case SectionUnavailable<DailyTargetWithRemaining>():
        status = DailyTargetStatus.error;
        error = DailyTargetError.fetchFailed;
      case SectionReauth<DailyTargetWithRemaining>():
        status = DailyTargetStatus.needsReauth;
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
