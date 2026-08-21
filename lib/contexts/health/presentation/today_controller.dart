import 'package:flutter/foundation.dart';

import '../../../shared/screen_batch/section_outcome.dart';
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

  /// The day each UNSETTLED [load] is fetching, keyed by a per-call request
  /// id it removes only in its own `finally`.
  ///
  /// A single `String?` field cannot express this and is why this is a map:
  /// two interleaved loads share the one slot, so whichever finishes FIRST
  /// clears it for the other as well and a reader is told "nobody is loading"
  /// while a load is still in flight. Keyed by request id, the invariant is
  /// "an entry exists iff that specific call has been announced and has not
  /// settled" — no other call can violate it.
  final Map<int, String> _pendingDays = {};
  int _nextRequestId = 0;

  /// The day of an unsettled [load], or `null` when none is in flight.
  /// Derived from [_pendingDays] so the one existing reader
  /// (`_UrlDictionaryScreen`, which asks only "is someone else's load in
  /// flight") keeps reading the same question — now answered correctly under
  /// interleaving, where the single field used to go `null` early.
  ///
  /// Not derivable from [status], whose INITIAL value is also `loading` — so
  /// `status` alone cannot tell "someone else's load is running" from "nobody
  /// has loaded at all". `_UrlDictionaryScreen` has to tell those apart: it is
  /// now reachable straight from the home grid, with no health shell below it
  /// to be waiting for, and reading `loading` as "wait" left it spinning
  /// forever.
  String? get loadingDay =>
      _pendingDays.isEmpty ? null : _pendingDays.values.first;

  /// Whether a [load] for exactly [day] is in flight. Day-keyed on purpose:
  /// "something is loading" is not the same question as "the day I am about
  /// to fetch is already being fetched", and answering the first for the
  /// second is how a screen ends up showing one day while the controller
  /// holds another.
  bool isLoadingDay(String day) => _pendingDays.containsValue(day);

  /// Whether the controller currently HOLDS [day]'s meals log.
  bool holdsDay(String day) => dayMealsLog?.day == day;

  /// The generation a whole-screen batch round has claimed, via
  /// [claimBatchRound]. Compared against [_nextRequestId] (already bumped
  /// synchronously by every [load], before its first `await`) in
  /// [applyBatchSection] instead of comparing days: a day comparison strands
  /// this controller on whatever day it already holds whenever a round's day
  /// differs from it — including ordinary cases where nothing has navigated
  /// at all, e.g. the day rolling over at midnight. The generation only
  /// moves on an explicit [load], so a round claimed after the last one is
  /// authoritative for whatever day it computed, whatever this controller
  /// currently holds — and a round claimed BEFORE a [load] that has since
  /// started or already landed is correctly refused. `null` (no round has
  /// claimed one yet) reads as "not claimed", so an unclaimed section is
  /// refused rather than accepted by accident.
  int? _claimedGeneration;

  /// Records the generation a whole-screen batch round is about to fetch
  /// for. Call synchronously, before the round's request goes out — mirrors
  /// [HealthCalendarController.claimBatchMonth].
  void claimBatchRound() => _claimedGeneration = _nextRequestId;

  DayMealsLog? dayMealsLog;
  DailyTargetWithRemaining? target;
  TodayError? error;

  Future<void> load(String idToken, String day) async {
    final requestId = _nextRequestId++;
    _pendingDays[requestId] = day;
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
    } finally {
      // Only this call's own claim — removing anyone else's is exactly the
      // early-clear the single field suffered from.
      _pendingDays.remove(requestId);
    }
    notifyListeners();
  }

  /// Applies the health screen's batched `meals` + `daily_target` sections
  /// for [day], leaving this controller in the state [load] would have left
  /// it in for the same payload.
  ///
  /// Both sections land here because [load] fetches both: the day's meals and
  /// then its target, and the order matters — a run whose meals read
  /// succeeded and whose target read failed assigns [dayMealsLog] and *then*
  /// ends on [TodayStatus.error]. Reproduced rather than tidied up, so the
  /// batch path cannot leave a state the granular one never produces.
  ///
  /// Dropped when a [load] has started — or already landed — since the round
  /// that produced this section was claimed via [claimBatchRound]: either
  /// way the diet day has explicitly navigated since, and writing this
  /// round's figures over that navigation is precisely the mismatch this
  /// module keeps producing. See [_claimedGeneration] for why this compares
  /// generations rather than days.
  void applyBatchSection({
    required SectionOutcome<DayMealsLog> meals,
    required SectionOutcome<DailyTargetWithRemaining> dailyTarget,
  }) {
    if (_claimedGeneration != _nextRequestId) return;
    error = null;
    if (meals is SectionReauth<DayMealsLog> ||
        dailyTarget is SectionReauth<DailyTargetWithRemaining>) {
      status = TodayStatus.needsReauth;
      notifyListeners();
      return;
    }
    if (meals is SectionOk<DayMealsLog>) dayMealsLog = meals.value;
    if (meals is SectionOk<DayMealsLog> &&
        dailyTarget is SectionOk<DailyTargetWithRemaining>) {
      target = dailyTarget.value;
      status = TodayStatus.loaded;
    } else {
      status = TodayStatus.error;
      error = TodayError.fetchFailed;
    }
    notifyListeners();
  }

  /// Runs a mutation [action], then refreshes [day] from the backend on
  /// success (the backend is authoritative for recomputed portions/totals —
  /// no optimistic local mutation). Maps reauth/not-found/failure to the
  /// controller's typed state, which the screen already renders.
  Future<void> _mutate(
    String idToken,
    String day,
    Future<void> Function() action,
  ) async {
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
      () => _editMealItem(
        idToken,
        itemId,
        quantity: quantity,
        measure: measure,
        portions: portions,
      ),
    );
  }

  Future<void> deleteItem(String idToken, String day, String itemId) {
    return _mutate(idToken, day, () => _deleteMealItem(idToken, itemId));
  }

  Future<void> changeMealTime(
    String idToken,
    String day,
    String mealId,
    DateTime time,
  ) {
    return _mutate(idToken, day, () => _changeMealTime(idToken, mealId, time));
  }

  Future<void> deleteMeal(String idToken, String day, String mealId) {
    return _mutate(idToken, day, () => _deleteMeal(idToken, mealId));
  }
}
