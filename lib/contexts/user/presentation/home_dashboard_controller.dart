import 'package:flutter/foundation.dart';

import '../../../shared/date/day_format.dart';
import '../../../shared/screen_batch/home_summary_batch.dart';
import '../../../shared/screen_batch/screen_batch_repository.dart';
import '../../../shared/screen_batch/section_outcome.dart';
import '../../body_profile/application/get_weight_goal.dart';
import '../../body_profile/domain/weight_goal.dart';
import '../../finance/application/list_finance_budgets.dart';
import '../../finance/application/networth_use_cases.dart';
import '../../finance/domain/finance_budget.dart';
import '../../finance/domain/finance_month.dart';
import '../../finance/domain/networth_snapshot.dart';
import '../../health/application/get_daily_target_with_remaining.dart';
import '../../health/domain/daily_target.dart';
import '../../menstrual/application/get_menstrual_overview.dart';
import '../../menstrual/domain/next_period_status.dart';
import '../../split/application/balance_use_cases.dart';
import '../../split/domain/balance.dart';
import '../../vitals/application/get_vitals_trends.dart';
import '../../vitals/domain/vitals_series.dart';

/// The state of the **page**, not of any one figure on it.
///
/// - [loading] — a full round (all seven arms) is in flight. A single-tile
///   [HomeDashboardController.retryArm] deliberately does NOT set it: the app
///   bar's spinner and the page-level `StaleNotice` speak for the whole
///   dashboard, and one tile reloading is not the whole dashboard reloading.
///   The tile shows its own indicator instead.
/// - [loaded] — the last full round finished with at least one arm producing
///   a value. Some tiles may still be marked failed; see [ArmSlot].
/// - [error] — the last full round finished with **all seven** arms failed.
enum HomeDashboardStatus { idle, loading, loaded, error }

/// One independently-fetched source behind the home dashboard.
///
/// Seven arms, eight tiles: [netWorth] feeds both 淨值 and 總負債, which come
/// out of the same request and therefore fail and retry together. Every other
/// arm is one tile.
enum DashboardArm {
  weightGoal,
  vitals,
  menstrual,
  budgets,
  netWorth,
  balances,
  dailyTarget,
}

enum ArmStatus { loading, loaded, failed }

/// One arm's value **and** how it got there, in one inseparable object.
///
/// The pair is the point. The previous model had a bare (sometimes nullable)
/// value per arm, and the incident that produced this class was exactly what
/// that model cannot express: the daily-target arm failed, the field went
/// `null`, and the tile printed 無資料 — indistinguishable from "you have no
/// target today". A failure is a *state*, not an absent value; do not
/// reintroduce a field where the two share a representation.
///
/// [value] is meaningful only when [hasValue], and [hasValue] is not the same
/// question as `value != null`: `ArmSlot<BloodPressureSnapshot?>` legitimately
/// holds a loaded `null` ("no blood pressure recorded"). Readers must switch
/// on [status] and consult [hasValue] — never infer either from [value].
///
/// A failed or reloading slot keeps whatever this session already fetched for
/// the same arm, so the tile can keep painting the figure beside a "not
/// refreshed" marker rather than blanking it. That memory is per-session and
/// in-memory only: nothing is persisted, and `reset()` (sign-out) drops it
/// with the rest of the per-user state.
@immutable
class ArmSlot<T> {
  final ArmStatus status;
  final T? value;

  /// Whether [value] holds a fetched result: always true for a loaded slot,
  /// and true for a failed/reloading slot that carried one over.
  final bool hasValue;

  const ArmSlot._(this.status, this.value, this.hasValue);

  const ArmSlot.loading() : this._(ArmStatus.loading, null, false);

  const ArmSlot.loaded(T value) : this._(ArmStatus.loaded, value, true);

  factory ArmSlot.loadingAfter(ArmSlot<T> previous) =>
      ArmSlot._(ArmStatus.loading, previous.value, previous.hasValue);

  factory ArmSlot.failedAfter(ArmSlot<T> previous) =>
      ArmSlot._(ArmStatus.failed, previous.value, previous.hasValue);
}

class BloodPressureSnapshot {
  final double systolic;
  final double diastolic;
  final DateTime day;
  final String time;

  const BloodPressureSnapshot({
    required this.systolic,
    required this.diastolic,
    required this.day,
    required this.time,
  });
}

/// The seven snapshots the home hub shows, each one an [ArmSlot] so that a
/// tile can say "this one failed" without the other six being taken down with
/// it — and without a failure being paintable as an empty.
///
/// Total failure is still handled as one thing: when every arm fails with
/// nothing to fall back on, [HomeDashboardController.data] goes back to
/// `null` and the screen shows its single "couldn't load" card with one
/// retry. That was always the right answer for total failure; it was only
/// ever wrong as an answer for *partial* failure.
class HomeDashboardData {
  final ArmSlot<WeightGoal> weightGoal;

  /// Loaded-and-`null` means "no blood pressure recorded", which is a
  /// different thing from a failed vitals fetch — hence the slot.
  final ArmSlot<BloodPressureSnapshot?> bloodPressure;
  final ArmSlot<NextPeriodStatus> menstrualStatus;
  final ArmSlot<FinanceBudget?> overallBudget;
  final ArmSlot<MonthlyNetWorth> netWorth;
  final ArmSlot<List<Balance>> splitBalances;

  /// Today's effective portion target and what is left of it.
  ///
  /// Not nullable, and no "no data" rendering exists for its tile: the backend
  /// always answers with a default target, so `getTarget` never resolves to an
  /// empty. Every blank this tile ever showed was a failed request wearing the
  /// placeholder's clothes.
  final ArmSlot<DailyTargetWithRemaining> dailyTarget;

  const HomeDashboardData({
    required this.weightGoal,
    required this.bloodPressure,
    required this.menstrualStatus,
    required this.overallBudget,
    required this.netWorth,
    required this.splitBalances,
    required this.dailyTarget,
  });

  /// Every arm loaded, from bare values — what a fixture almost always wants.
  HomeDashboardData.allLoaded({
    required WeightGoal weightGoal,
    required BloodPressureSnapshot? bloodPressure,
    required NextPeriodStatus menstrualStatus,
    required FinanceBudget? overallBudget,
    required MonthlyNetWorth netWorth,
    required List<Balance> splitBalances,
    required DailyTargetWithRemaining dailyTarget,
  }) : weightGoal = ArmSlot.loaded(weightGoal),
       bloodPressure = ArmSlot.loaded(bloodPressure),
       menstrualStatus = ArmSlot.loaded(menstrualStatus),
       overallBudget = ArmSlot.loaded(overallBudget),
       netWorth = ArmSlot.loaded(netWorth),
       splitBalances = ArmSlot.loaded(splitBalances),
       dailyTarget = ArmSlot.loaded(dailyTarget);

  const HomeDashboardData.allLoading()
    : weightGoal = const ArmSlot.loading(),
      bloodPressure = const ArmSlot.loading(),
      menstrualStatus = const ArmSlot.loading(),
      overallBudget = const ArmSlot.loading(),
      netWorth = const ArmSlot.loading(),
      splitBalances = const ArmSlot.loading(),
      dailyTarget = const ArmSlot.loading();

  HomeDashboardData copyWith({
    ArmSlot<WeightGoal>? weightGoal,
    ArmSlot<BloodPressureSnapshot?>? bloodPressure,
    ArmSlot<NextPeriodStatus>? menstrualStatus,
    ArmSlot<FinanceBudget?>? overallBudget,
    ArmSlot<MonthlyNetWorth>? netWorth,
    ArmSlot<List<Balance>>? splitBalances,
    ArmSlot<DailyTargetWithRemaining>? dailyTarget,
  }) => HomeDashboardData(
    weightGoal: weightGoal ?? this.weightGoal,
    bloodPressure: bloodPressure ?? this.bloodPressure,
    menstrualStatus: menstrualStatus ?? this.menstrualStatus,
    overallBudget: overallBudget ?? this.overallBudget,
    netWorth: netWorth ?? this.netWorth,
    splitBalances: splitBalances ?? this.splitBalances,
    dailyTarget: dailyTarget ?? this.dailyTarget,
  );

  /// The slot behind one arm, for callers that hold a [DashboardArm] rather
  /// than a field — a single-tile retry, which knows which arm it asked for
  /// and has to find out how that arm ended up.
  ArmSlot<Object?> slotOf(DashboardArm arm) => switch (arm) {
    DashboardArm.weightGoal => weightGoal,
    DashboardArm.vitals => bloodPressure,
    DashboardArm.menstrual => menstrualStatus,
    DashboardArm.budgets => overallBudget,
    DashboardArm.netWorth => netWorth,
    DashboardArm.balances => splitBalances,
    DashboardArm.dailyTarget => dailyTarget,
  };

  /// Whether any arm is marked failed — what the page announces after a
  /// round, since a partial failure is invisible to a screen reader that only
  /// hears the page-level status.
  bool get hasAnyFailure =>
      weightGoal.status == ArmStatus.failed ||
      bloodPressure.status == ArmStatus.failed ||
      menstrualStatus.status == ArmStatus.failed ||
      overallBudget.status == ArmStatus.failed ||
      netWorth.status == ArmStatus.failed ||
      splitBalances.status == ArmStatus.failed ||
      dailyTarget.status == ArmStatus.failed;

  /// Whether any tile has a figure to paint. `false` is the only state in
  /// which the whole-dashboard "couldn't load" card is the right answer.
  bool get hasAnyValue =>
      weightGoal.hasValue ||
      bloodPressure.hasValue ||
      menstrualStatus.hasValue ||
      overallBudget.hasValue ||
      netWorth.hasValue ||
      splitBalances.hasValue ||
      dailyTarget.hasValue;
}

/// The home tile shows the *most recent* blood-pressure sample, so its
/// lookback is a year rather than the health screen's month — a shorter one
/// would blank the tile for anyone who has not measured lately. Matches the
/// endpoint's own default, and is sent explicitly all the same: the two
/// endpoints' defaults differ (30 vs 366) and a default changed on either
/// side would move the window silently.
const int homeTrendDays = 366;

/// Loads the lightweight cross-context snapshots shown by the home hub.
class HomeDashboardController extends ChangeNotifier {
  final ScreenBatchRepository _screenBatch;
  final GetWeightGoal _getWeightGoal;
  final GetVitalsTrends _getVitalsTrends;
  final GetMenstrualOverview _getMenstrualOverview;
  final ListFinanceBudgets _listFinanceBudgets;
  final GetMonthlyNetWorth _getMonthlyNetWorth;
  final GetBalances _getBalances;
  final GetDailyTargetWithRemaining _getDailyTarget;

  HomeDashboardController(
    this._screenBatch,
    this._getWeightGoal,
    this._getVitalsTrends,
    this._getMenstrualOverview,
    this._listFinanceBudgets,
    this._getMonthlyNetWorth,
    this._getBalances,
    this._getDailyTarget,
  );

  HomeDashboardStatus status = HomeDashboardStatus.idle;
  HomeDashboardData? data;

  /// When a round last produced **any** data, or `null` before the first one —
  /// what the home screen's "updated HH:mm" line reads. It advances whenever a
  /// round lands at least one arm: with partial success some figures genuinely
  /// were refreshed, and the ones that weren't now say so on their own tile. A
  /// round in which every arm failed still leaves it alone.
  DateTime? lastLoadedAt;

  /// The round currently running, or `null` when nothing is in flight.
  Future<void>? _inFlight;

  /// Bumped by [reset] — see **Invariant W** below.
  int _generation = 0;

  /// Per-arm ticket counter — see **Invariant W** below.
  final Map<DashboardArm, int> _seq = {
    for (final arm in DashboardArm.values) arm: 0,
  };

  /// **Invariant W (the write rule).** Every fetch for an arm — started by a
  /// full round or by a single-tile [retryArm], it makes no difference —
  /// increments that arm's `_seq[arm]` at **start** and keeps the new value as
  /// its ticket. When it completes it may write that arm's slot **iff** (a)
  /// the generation it started under still equals `_generation`, **and** (b)
  /// its ticket still equals `_seq[arm]`. Nothing else ever writes an arm's
  /// slot.
  ///
  /// Consequence, and the property to test rather than the orderings: **for
  /// each arm the slot always reflects the most recently *started* fetch for
  /// that arm**, regardless of completion order, of who started it, or of how
  /// many are in flight. In particular a full round's result for arm X lands
  /// for the other six even when X's write is dropped in favour of a newer
  /// retry of X — which a whole-controller guard cannot express.
  ///
  /// Condition (a) is what stops an outgoing user's in-flight round from
  /// landing on the controller after `reset()` supposedly cleared it for the
  /// next user. Both conditions are load-bearing and are mutated separately.
  ///
  /// **Invariant P (the page rule).** [status] and [lastLoadedAt] are written
  /// only by a full round, and only under (a). [retryArm] never writes either.
  bool _mayWrite(DashboardArm arm, int generation, int ticket) =>
      generation == _generation && ticket == _seq[arm];

  /// Loads every arm, or — if a round is already running — returns that
  /// round's future rather than starting a second fan-out. The retry button
  /// and a pull-to-refresh can otherwise overlap into fourteen concurrent
  /// requests. (Correctness no longer *depends* on this dedupe: Invariant W
  /// decides which write wins whatever overlaps. It is a request-count
  /// optimisation, and the per-tile retries deliberately have none.)
  Future<void> load(String idToken, DateTime now) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final generation = _generation;
    late final Future<void> round;
    round = _load(idToken, now, generation).whenComplete(() {
      // Only clear the slot if it's still *this* round's — an older round
      // finishing after `reset()` started a newer one must not clobber the
      // newer round's registration.
      if (identical(_inFlight, round)) _inFlight = null;
    });
    _inFlight = round;
    return round;
  }

  /// Refetches **one** arm, leaving the other six and the page-level state
  /// alone (Invariant P) — the per-tile retry. No dedupe: a second press
  /// simply starts a second fetch, and Invariant W drops the older one's
  /// write whichever order they land in.
  Future<void> retryArm(DashboardArm arm, String idToken, DateTime now) async {
    // Nothing to retry into: with no `data` the screen is showing the
    // whole-dashboard "couldn't load" card, whose retry is `load`.
    if (data == null) return;
    final generation = _generation;
    // `_runArm` marks the slot loading synchronously, before its first await,
    // so this notification already carries the tile's spinner.
    final done = _runArm(arm, idToken, now, generation, markLoading: true);
    notifyListeners();
    await done;
    if (generation != _generation) return;
    notifyListeners();
  }

  Future<void> _load(String idToken, DateTime now, int generation) async {
    status = HomeDashboardStatus.loading;
    notifyListeners();
    // Arms are NOT marked loading here: a reload keeps the figures on screen
    // and the page-level spinner/notice says a round is running, so eight
    // tiles simultaneously blanking themselves would be the "quietly blank the
    // screen" outcome this whole model exists to avoid.
    //
    // Two consequences, both accepted: an arm that was already failed keeps
    // its failed marker (not the reloading one) for the length of the round,
    // and that marker stays tappable — so a press during a round starts a
    // *second* fetch of that arm. Invariant W makes the result correct
    // whichever lands first; what it costs is one redundant request, against
    // a tile that would otherwise look inert while the page refreshes.

    // One ticket per arm, taken at the START of the round — exactly as if
    // seven fetches had been started here, which is what this used to do.
    // Invariant W then decides every write as before: a per-tile retry
    // started after this point still wins its arm whichever order the two
    // land in, and `reset()` still stops the whole round from landing.
    final tickets = {
      for (final arm in DashboardArm.values) arm: _takeTicket(arm),
    };

    HomeSummaryBatch batch;
    try {
      // ONE request for the seven arms. `day` is the same `now` the round was
      // handed, formatted once — never a second clock read, which is how a
      // round that straddles midnight ends up requesting one day and labelling
      // another.
      batch = await _screenBatch.getHomeSummary(
        idToken,
        day: dayString(now),
        trendDays: homeTrendDays,
      );
    } catch (_) {
      // Every request-level fault is seven failed arms, including a 401: no
      // arm here has a re-authentication state, and the whole-dashboard card
      // below is what a total failure already showed.
      batch = HomeSummaryBatch.requestFailed(reauth: false);
    }

    final outcomes = [
      _applyArm<WeightGoal>(
        DashboardArm.weightGoal,
        generation,
        tickets[DashboardArm.weightGoal]!,
        batch.weightGoal,
        (data) => data.weightGoal,
        (data, slot) => data.copyWith(weightGoal: slot),
      ),
      _applyArm<BloodPressureSnapshot?>(
        DashboardArm.vitals,
        generation,
        tickets[DashboardArm.vitals]!,
        _reduce(
          batch.vitalsTrend,
          (range) => _latestBloodPressure(range.series),
        ),
        (data) => data.bloodPressure,
        (data, slot) => data.copyWith(bloodPressure: slot),
      ),
      _applyArm<NextPeriodStatus>(
        DashboardArm.menstrual,
        generation,
        tickets[DashboardArm.menstrual]!,
        _reduce(
          batch.menstrual,
          (overview) => computeNextPeriodStatus(overview, now),
        ),
        (data) => data.menstrualStatus,
        (data, slot) => data.copyWith(menstrualStatus: slot),
      ),
      _applyArm<FinanceBudget?>(
        DashboardArm.budgets,
        generation,
        tickets[DashboardArm.budgets]!,
        batch.overallBudget,
        (data) => data.overallBudget,
        (data, slot) => data.copyWith(overallBudget: slot),
      ),
      _applyArm<MonthlyNetWorth>(
        DashboardArm.netWorth,
        generation,
        tickets[DashboardArm.netWorth]!,
        batch.netWorth,
        (data) => data.netWorth,
        (data, slot) => data.copyWith(netWorth: slot),
      ),
      _applyArm<List<Balance>>(
        DashboardArm.balances,
        generation,
        tickets[DashboardArm.balances]!,
        batch.splitBalances,
        (data) => data.splitBalances,
        (data, slot) => data.copyWith(splitBalances: slot),
      ),
      _applyArm<DailyTargetWithRemaining>(
        DashboardArm.dailyTarget,
        generation,
        tickets[DashboardArm.dailyTarget]!,
        batch.dailyTarget,
        (data) => data.dailyTarget,
        (data, slot) => data.copyWith(dailyTarget: slot),
      ),
    ];
    if (generation != _generation) return;
    if (outcomes.contains(true)) {
      status = HomeDashboardStatus.loaded;
      lastLoadedAt = now;
    } else {
      status = HomeDashboardStatus.error;
      // Every arm failed AND none of them had an older figure to fall back
      // on: there is nothing to paint, so the screen goes back to the single
      // whole-dashboard error card rather than eight identical failed tiles.
      if (data?.hasAnyValue == false) data = null;
    }
    notifyListeners();
  }

  /// Reduces one section to the value its arm holds, keeping a failure a
  /// failure. The home tiles show derived figures (the latest blood pressure,
  /// the next predicted period), never the whole section.
  SectionOutcome<R> _reduce<T, R>(
    SectionOutcome<T> section,
    R Function(T) reduce,
  ) => section is SectionOk<T>
      ? SectionOk<R>(reduce(section.value))
      : SectionUnavailable<R>();

  /// Writes one arm from an already-resolved section, under Invariant W with
  /// the ticket the round took at its start. Returns whether the section
  /// carried a value — the round's question is "did this refresh anything",
  /// and a write dropped in favour of a newer retry of the same arm is not a
  /// failed round.
  bool _applyArm<T>(
    DashboardArm arm,
    int generation,
    int ticket,
    SectionOutcome<T> section,
    ArmSlot<T> Function(HomeDashboardData) read,
    HomeDashboardData Function(HomeDashboardData, ArmSlot<T>) write,
  ) {
    final ok = section is SectionOk<T>;
    if (!_mayWrite(arm, generation, ticket)) return ok;
    final current = data ?? const HomeDashboardData.allLoading();
    data = write(
      current,
      ok
          ? ArmSlot<T>.loaded(section.value)
          : ArmSlot<T>.failedAfter(read(current)),
    );
    return ok;
  }

  int _takeTicket(DashboardArm arm) {
    final ticket = (_seq[arm] ?? 0) + 1;
    _seq[arm] = ticket;
    return ticket;
  }

  /// Runs one arm's own granular fetch under Invariant W — the per-tile
  /// [retryArm] path, which stays granular; a whole round goes through the
  /// batch endpoint instead. Returns whether the fetch itself
  /// succeeded (not whether the write was allowed — the caller's question is
  /// "did this round refresh anything", and a write dropped in favour of a
  /// *newer* fetch of the same arm is not a failed round).
  Future<bool> _runArm(
    DashboardArm arm,
    String idToken,
    DateTime now,
    int generation, {
    bool markLoading = false,
  }) {
    final month = monthStringOf(now);
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(const Duration(days: 365));
    return switch (arm) {
      DashboardArm.weightGoal => _fetchArm<WeightGoal>(
        arm,
        generation,
        markLoading,
        () => _getWeightGoal(idToken),
        (data) => data.weightGoal,
        (data, slot) => data.copyWith(weightGoal: slot),
      ),
      DashboardArm.vitals => _fetchArm<BloodPressureSnapshot?>(
        arm,
        generation,
        markLoading,
        () async =>
            _latestBloodPressure((await _getVitalsTrends(idToken, from, to)).series),
        (data) => data.bloodPressure,
        (data, slot) => data.copyWith(bloodPressure: slot),
      ),
      DashboardArm.menstrual => _fetchArm<NextPeriodStatus>(
        arm,
        generation,
        markLoading,
        () async => computeNextPeriodStatus(await _getMenstrualOverview(idToken), now),
        (data) => data.menstrualStatus,
        (data, slot) => data.copyWith(menstrualStatus: slot),
      ),
      DashboardArm.budgets => _fetchArm<FinanceBudget?>(
        arm,
        generation,
        markLoading,
        () async => (await _listFinanceBudgets(idToken, month))
            .where((budget) => budget.categoryId == null)
            .firstOrNull,
        (data) => data.overallBudget,
        (data, slot) => data.copyWith(overallBudget: slot),
      ),
      DashboardArm.netWorth => _fetchArm<MonthlyNetWorth>(
        arm,
        generation,
        markLoading,
        () => _getMonthlyNetWorth(idToken, month),
        (data) => data.netWorth,
        (data, slot) => data.copyWith(netWorth: slot),
      ),
      DashboardArm.balances => _fetchArm<List<Balance>>(
        arm,
        generation,
        markLoading,
        () => _getBalances(idToken),
        (data) => data.splitBalances,
        (data, slot) => data.copyWith(splitBalances: slot),
      ),
      DashboardArm.dailyTarget => _fetchArm<DailyTargetWithRemaining>(
        arm,
        generation,
        markLoading,
        () => _getDailyTarget(idToken, dayString(now)),
        (data) => data.dailyTarget,
        (data, slot) => data.copyWith(dailyTarget: slot),
      ),
    };
  }

  Future<bool> _fetchArm<T>(
    DashboardArm arm,
    int generation,
    bool markLoading,
    Future<T> Function() fetch,
    ArmSlot<T> Function(HomeDashboardData) read,
    HomeDashboardData Function(HomeDashboardData, ArmSlot<T>) write,
  ) async {
    final ticket = _takeTicket(arm);
    if (markLoading) {
      final current = data ?? const HomeDashboardData.allLoading();
      data = write(current, ArmSlot.loadingAfter(read(current)));
    }
    T? value;
    var ok = false;
    try {
      value = await fetch();
      ok = true;
    } catch (_) {
      ok = false;
    }
    if (!_mayWrite(arm, generation, ticket)) return ok;
    final current = data ?? const HomeDashboardData.allLoading();
    data = write(
      current,
      ok ? ArmSlot<T>.loaded(value as T) : ArmSlot<T>.failedAfter(read(current)),
    );
    return ok;
  }

  void reset() {
    data = null;
    status = HomeDashboardStatus.idle;
    // Per-user state, so it goes when the user does (sign-out calls this):
    // otherwise the next account's home opens claiming a load time that
    // belongs to the previous one.
    lastLoadedAt = null;
    // Also per-user: if a round for the outgoing user is still in flight when
    // they sign out, `load` for the incoming user must start a fresh fan-out
    // rather than riding the old round's future to completion — otherwise the
    // new user's screen quietly fills in with the old user's data and no
    // request is ever made with the new token.
    _inFlight = null;
    // Bumping the generation stops every in-flight fetch of every arm, from
    // any round or retry, from writing onto this controller — condition (a)
    // of Invariant W.
    _generation++;
  }
}

BloodPressureSnapshot? _latestBloodPressure(VitalsSeries series) {
  final diastolicByReading = <String, SeriesPoint>{
    for (final point in series.diastolic) _readingKey(point): point,
  };
  for (final systolic in series.systolic.reversed) {
    final diastolic = diastolicByReading[_readingKey(systolic)];
    if (diastolic == null) continue;
    return BloodPressureSnapshot(
      systolic: systolic.value,
      diastolic: diastolic.value,
      day: systolic.day,
      time: systolic.time,
    );
  }
  return null;
}

String _readingKey(SeriesPoint point) =>
    '${point.day.year}-${point.day.month}-${point.day.day}|${point.time}';
