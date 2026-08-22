import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/data_revision.dart';
import '../../../shared/screen_batch/health_overview_batch.dart';
import '../../../shared/screen_batch/screen_batch_exceptions.dart';
import '../../../shared/screen_batch/screen_batch_repository.dart';
import '../../../shared/widgets/last_loaded_label.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../../body_profile/presentation/goal_card.dart';
import '../../body_profile/presentation/weight_goal_controller.dart';
import '../../bowel/presentation/bowel_controller.dart';
import '../../exercise/presentation/exercise_controller.dart';
import '../../health_calendar/presentation/health_calendar_card.dart';
import '../../health_calendar/presentation/health_calendar_controller.dart';
import '../../hydration/presentation/water_controller.dart';
import '../../menstrual/presentation/menstrual_controller.dart';
import '../../menstrual/presentation/next_period_card.dart';
import '../../notifications/presentation/care_adherence_card.dart';
import '../../notifications/presentation/care_history_controller.dart';
import '../../notifications/presentation/care_today_controller.dart';
import '../../notifications/presentation/care_today_summary_card.dart';
import '../../notifications/presentation/push_health_controller.dart';
import '../../notifications/presentation/push_off_banner.dart';
import '../../vitals/presentation/trend_card.dart';
import '../../vitals/presentation/trend_controller.dart';
import '../../vitals/presentation/vitals_controller.dart';
import '../application/get_logged_days.dart';
import 'create_meal_controller.dart';
import 'daily_target_controller.dart';
import 'dictionary_controller.dart';
import 'today_controller.dart';
import '../../../shared/auth/id_token_provider.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/routing/health_tab.dart';

/// The `care_days` a round sends when the care card's period has no day
/// count to send — the endpoint's own default, chosen so the request stays
/// valid; the section it comes back with is not applied.
const int _defaultCareDays = 30;

String _todayString(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-'
    '${time.month.toString().padLeft(2, '0')}-'
    '${time.day.toString().padLeft(2, '0')}';

/// The health module's home: a persistent bottom-nav scaffold with four
/// destinations — 總覽 (overview cards), 記錄 (a flat tracker hub), 趨勢 (the trend
/// chart), and 更多 (settings). Recording is always one tap away, and the overview
/// is always reachable — replacing the old "dashboard landing → push the diet
/// shell → dig through 更多" depth. Owns the auth-token load and pre-loads the
/// day-keyed trackers for today (mirroring the former shell); the tab bodies and
/// the pushed tracker screens display those controllers.
class HealthScaffold extends StatefulWidget {
  final AuthRepository authRepository;
  final SignOut signOut;

  /// Reads the whole screen in one request. Every card below is fanned out
  /// from that one response; the granular repositories the controllers hold
  /// stay in use for writes, per-card retries and per-card window changes.
  final ScreenBatchRepository screenBatchRepository;

  // Overview / trends.
  final WeightGoalController weightGoalController;
  final TrendController trendController;
  final HealthCalendarController healthCalendarController;

  // Diet.
  final TodayController todayController;
  final DictionaryController dictionaryController;
  final DailyTargetController dailyTargetController;
  final CreateMealController createMealController;
  final GetLoggedDays getLoggedDays;

  // Trackers.
  final WaterController waterController;
  final BowelController bowelController;
  final VitalsController vitalsController;
  final ExerciseController exerciseController;
  final MenstrualController menstrualController;

  /// Drives the today-care summary card at the top of 總覽 (Overview).
  final CareTodayController careTodayController;

  /// Drives the care adherence heatmap card on 趨勢 (Trends), below
  /// [trendController]'s vitals chart — its own [CareHistoryController]
  /// instance (`spanDays: 30`), separate from the one driving the
  /// `/care-history` screen, so the two periods don't fight over shared
  /// state (design §B).
  final CareHistoryController careAdherenceController;

  /// Opens the app settings (theme / language / sign-out), wired by the caller.
  final VoidCallback onOpenSettings;

  /// Opens the chaodays import screen, wired by the caller.
  final VoidCallback onOpenImport;

  /// Opens the reminder/notification settings screen, wired by the caller.
  final VoidCallback onOpenReminders;

  /// Opens the care reminders (medication/rehab/radiotherapy care/custom)
  /// screen, wired by the caller.
  final VoidCallback onOpenCareItems;

  /// Opens the Today care checklist screen, wired by the caller (distinct
  /// from [onOpenCareItems] — today vs. manage).
  final VoidCallback onOpenCareToday;

  /// Opens the care history record list (`/care-history`), wired by the
  /// caller — reached from the trends tab's adherence card, which is where a
  /// user sees the missed/partial days they want to go correct.
  final VoidCallback onOpenCareHistory;

  final DateTime Function() clock;

  /// Bumped by write flows elsewhere in the app (e.g. a chaodays import)
  /// when lifeos data has changed; the scaffold reloads in response so the
  /// overview doesn't need an app restart to catch up (see the
  /// refresh-health-after-import design).
  final DataRevision dataRevision;

  /// Read-only: drives the overview's push-off banner (and is one of the
  /// [_overviewControllers], so a health change rebuilds the overview).
  final PushHealthController pushHealthController;

  const HealthScaffold({
    super.key,
    required this.pushHealthController,
    required this.authRepository,
    required this.signOut,
    required this.screenBatchRepository,
    required this.weightGoalController,
    required this.trendController,
    required this.healthCalendarController,
    required this.todayController,
    required this.dictionaryController,
    required this.dailyTargetController,
    required this.createMealController,
    required this.getLoggedDays,
    required this.waterController,
    required this.bowelController,
    required this.vitalsController,
    required this.exerciseController,
    required this.menstrualController,
    required this.careTodayController,
    required this.careAdherenceController,
    required this.onOpenSettings,
    required this.onOpenImport,
    required this.onOpenReminders,
    required this.onOpenCareItems,
    required this.onOpenCareToday,
    required this.onOpenCareHistory,
    required this.dataRevision,
    this.clock = DateTime.now,
  });

  @override
  State<HealthScaffold> createState() => _HealthScaffoldState();
}

class _HealthScaffoldState extends State<HealthScaffold> {
  int _index = 0;

  /// Whether the entry load has run — the gate for the first-frame spinner in
  /// [build]. A *flag*, deliberately not the token: this scaffold is one of
  /// the long-mounted shells issue #106 is about, so the token is re-resolved
  /// per request by [_idToken] instead of being cached here.
  bool _bootstrapped = false;

  // Coalescing state for reloads triggered by [DataRevision] bumps: a bump
  // arriving while a load is already in flight must not be dropped (the
  // in-flight load may have issued its requests before the write happened)
  // but must also not run concurrently with it (the thirteen controllers
  // below aren't re-entrancy-safe) — so it's queued and runs exactly once
  // more after the current load finishes. This invariant only covers loads
  // driven from here: careAdherenceController can also be reloaded directly
  // by the card's own period selector (setSpan), which isn't coalesced by
  // this mechanism.
  bool _loading = false;
  bool _reloadPending = false;

  /// Resolves when the current in-flight reload (including a round coalesced
  /// onto it) finishes — reused across the whole in-flight window so every
  /// caller that arrived during it (a pull-to-refresh gesture and the bump
  /// that coalesced onto it) awaits the same future and it completes exactly
  /// once. `null` when nothing is in flight.
  Completer<void>? _refreshCompleter;

  /// When the overview/trends batch last loaded successfully, or `null` before
  /// the first success. Updated only when a `_load` leaves at least one
  /// overview/trend controller in its `loaded` status — NOT merely because
  /// `Future.wait` resolved (the cards catch their own errors, so a
  /// network-down load resolves with every card failed). Left unchanged
  /// otherwise, so it always reflects data actually fetched.
  DateTime? _lastOverviewLoadAt;

  /// Whether [_load] is about to run its FIRST round. Only that round may
  /// stand down from the two diet loads below: every later round is a
  /// deliberate forced refresh (a [DataRevision] bump, a pull-to-refresh) and
  /// must re-issue every request, "we already have this day" or not.
  bool _firstLoadRound = true;

  @override
  void initState() {
    super.initState();
    for (final c in _overviewControllers) {
      c.addListener(_onChanged);
    }
    widget.dataRevision.addListener(_onRevisionChanged);
    unawaited(_scheduleLoad());
  }

  List<Listenable> get _overviewControllers => [
    widget.weightGoalController,
    widget.trendController,
    widget.healthCalendarController,
    widget.menstrualController,
    widget.careTodayController,
    widget.careAdherenceController,
    widget.pushHealthController,
  ];

  @override
  void dispose() {
    for (final c in _overviewControllers) {
      c.removeListener(_onChanged);
    }
    widget.dataRevision.removeListener(_onRevisionChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _onRevisionChanged() => unawaited(_scheduleLoad());

  /// Runs [_load] immediately if nothing is in flight, otherwise marks a
  /// reload as pending so exactly one more load runs once the current one
  /// finishes. Returns a [Future] that resolves when the round this call
  /// belongs to (including a coalesced pending round) has finished — so a
  /// pull-to-refresh gesture can await it and settle its spinner only then.
  Future<void> _scheduleLoad() {
    // Reuse the same completer for the whole in-flight window: a gesture that
    // arrives while a load is already running must await the round that
    // actually finishes, and the completer must be completed exactly once.
    _refreshCompleter ??= Completer<void>();
    final completer = _refreshCompleter!;
    if (_loading) {
      _reloadPending = true;
      return completer.future;
    }
    _setLoading(true);
    // Clear the flag on failure too: a load that throws would otherwise leave
    // `_loading` set forever and silently drop every later refresh for the
    // rest of the session. The controllers surface their own load errors, so
    // nothing is swallowed here.
    //
    // The token fetch used to be the one call here that could throw; it no
    // longer can (`guardedIdToken` resolves a failed renewal to `''` so the
    // request goes out and the backend's 401 drives the re-auth exit). This
    // is therefore belt-and-braces now rather than a live path — kept because
    // it costs nothing and the next await added here might throw.
    _load().then((_) {}, onError: (_) {}).whenComplete(() {
      _setLoading(false);
      final pending = _reloadPending;
      _reloadPending = false;
      if (pending && mounted) {
        // Continue the same in-flight window: keep the completer so both the
        // original gesture and the coalesced bump resolve on the round that
        // truly finishes. Do NOT touch `_refreshCompleter` here.
        unawaited(_scheduleLoad());
      } else {
        // The window is over: complete once, then clear so the next gesture
        // gets a fresh completer.
        _refreshCompleter = null;
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  /// Assigns [_loading] and rebuilds, so the cards can show that the round is
  /// reloading them: during a round no controller runs its own `load()`, so
  /// none of their statuses reports the reload and every card's
  /// [StaleNotice] would otherwise sit idle through it.
  ///
  /// The `_bootstrapped` conjunct only ever excludes the FIRST round, which
  /// starts from the synchronous `_scheduleLoad()` in [initState]. It is not
  /// load-bearing, and the comment that used to be here claiming `setState`
  /// there would throw was wrong: measured both ways — a `setState` inside
  /// `initState` raises nothing, and dropping the conjunct leaves the whole
  /// suite green. Kept because it says at the call site that the first round's
  /// flip needs no rebuild of its own (the build that immediately follows
  /// [initState] reads `_loading` anyway), not because removing it breaks
  /// anything. Do not re-derive a stronger claim from it.
  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    if (mounted && _bootstrapped) setState(() {});
  }

  /// A fresh id token per request (see [IdTokenProvider]); the shape
  /// `FriendsScreen._token` uses.
  Future<String> _idToken() => guardedIdToken(widget.authRepository);

  /// Covers one stand-down: the shell skipped its own load of [load]'s day
  /// because another screen in this stack had claimed it, so wait for that
  /// claim to settle and issue the load after all if it did not land.
  ///
  /// The `isLoadingDay` half of the decision has to commit BEFORE the claimed
  /// request has an answer, so — unlike the `holdsDay` half, which can read
  /// the outcome inline — it cannot tell "landed" from "landed SUCCESSFULLY"
  /// at decision time. Measured: a diet-day fetch that was still in flight at
  /// the decision and then failed left the screen on `TodayStatus.error` with
  /// the shell's own fetch, the only other one that day was going to get,
  /// already skipped — while before the stand-down existed the shell's fetch
  /// landed after it and put the day on screen.
  ///
  /// Fire-and-forget on purpose: the shell's own batch must not wait on a
  /// foreign request. A claim that never settles leaves this listener parked,
  /// not the UI.
  Future<void> _coverStandDown({
    required ChangeNotifier controller,
    required bool Function() claimInFlight,
    required bool Function() landed,
    required Future<void> Function() load,
  }) async {
    if (claimInFlight()) {
      final settled = Completer<void>();
      void onChange() {
        if (!claimInFlight() && !settled.isCompleted) settled.complete();
      }

      // No re-check after subscribing, and none is needed: nothing between
      // the test above and this line awaits, so on a single-threaded isolate
      // the claim cannot settle in the gap. (Written with one, then deleted
      // — no mutation could make it matter, and a check that cannot fire is
      // worse than none.)
      controller.addListener(onChange);
      try {
        await settled.future;
      } finally {
        controller.removeListener(onChange);
      }
    }
    // One cover, never a loop: if this load fails too, the day is on the same
    // error state a retry-less screen already has, and re-firing here would
    // hammer a down backend from a screen nobody is looking at.
    if (!mounted || landed()) return;
    await load();
  }

  /// Whether `DietDayScreen` is in the page stack this shell was built into —
  /// i.e. whether somebody else in this very navigation is already loading the
  /// diet day. The mirror image of `app.dart`'s `_healthShellInStack`, and read
  /// the same way: from the route match list, which is exact and available at
  /// the moment the decision is taken.
  ///
  /// It has to be part of the decision, and a controller signal alone cannot
  /// replace it. Measured on a URL-driven `/health/diet`: the diet day mounts,
  /// resolves its token and *completes* its load before this shell's widget is
  /// constructed — so by the time [_load] runs there is no in-flight load left
  /// to see, and "the controller holds today" on its own is indistinguishable
  /// from a controller that has held today since an earlier visit (which must
  /// still be refetched, or entering the shell would show data of unbounded
  /// age). The stack is what tells those two apart: below a mounted diet day,
  /// today's meals/target were fetched by this same navigation.
  ///
  /// It is NOT the whole decision, though — the caller ANDs it with a
  /// day-keyed check on the controller. On its own it is not day-keyed, so a
  /// cold start straddling midnight (the diet day built on `D`, this shell
  /// resolving `D+1`) would make the shell stand down from a day nobody
  /// fetches, which is exactly the "screen shows one day, controller holds
  /// another" failure this module keeps producing.
  ///
  /// [GoRouter.maybeOf], not `of`: this scaffold is also pumped straight into
  /// a `MaterialApp` by widget tests, and `of` throws where there is no router
  /// ancestor. No router means no page stack means no diet day below — nothing
  /// to stand down for.
  bool get _dietDayInStack {
    final router = GoRouter.maybeOf(context);
    if (router == null) return false;
    return router.routerDelegate.currentConfiguration.matches.any(
      (match) => match.matchedLocation == '/health/diet',
    );
  }

  Future<void> _load() async {
    final token = await _idToken();
    if (!mounted) return;
    setState(() => _bootstrapped = true);
    final day = _todayString(widget.clock());
    final firstRound = _firstLoadRound;
    _firstLoadRound = false;
    // On a URL-driven entry under `/health/diet` (a PWA shortcut, a deep link,
    // a browser refresh) go_router builds the whole stack, so `DietDayScreen`
    // is mounted below this shell and fires its own `_reloadCurrentDay()` for
    // today — and without standing down here, the same day went out twice
    // (issue #171). The check lives here and `diet_day_screen.dart` is
    // untouched: its reload is what pulls a re-entered diet day back to today
    // from whatever past day the day-nav left the shared controllers on.
    final standDownRound = firstRound && _dietDayInStack;
    if (standDownRound) {
      // Let the diet day announce its own load before deciding. Measured, the
      // mount order is NOT stable across entry points: on `/health/diet` the
      // diet day mounts, loads and settles before this shell's widget is even
      // constructed, while on `/health/diet/dictionary` this shell's `_load`
      // body reaches here first and the diet day has only mounted — its
      // `await idToken()` has not resolved, so it has claimed nothing yet and
      // an immediate read of the controllers would say "nobody is loading
      // today" on a stack where somebody is about to.
      //
      // One event-loop turn (a zero-duration timer, NOT `endOfFrame` — that
      // needs a frame to be scheduled and would hang a test where none is)
      // drains the microtasks that resolve those tokens. Paid only when a diet
      // day really is below, and it cannot make anything worse: if the claim
      // still has not appeared, the conditions below are simply false and this
      // shell loads the day itself, exactly as it did before this change.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
    }
    // Day-keyed, per controller: "somebody in this stack is fetching MY day",
    // never merely "somebody is fetching". `isLoadingDay` covers the ordering
    // where the diet day's request is still out (production, where the network
    // outlasts the frame); `holdsDay` covers the one where it has already
    // landed (measured on `/health/diet`, and always the case in tests).
    //
    // "Landed" is not the same as "landed SUCCESSFULLY", hence the status
    // clause on the `holdsDay` half — do not delete it as redundant:
    //
    //  * `TodayController.load` assigns `dayMealsLog` BEFORE fetching the
    //    target, so a run where the meals read succeeded and the target read
    //    failed ends on `TodayStatus.error` while `holdsDay(day)` is already
    //    true. Standing down there throws away this batch's fetch, which is
    //    the only load that state gets on its own: `TodayStatus.error` renders
    //    a message and a sign-out button, so the sole way back is to walk the
    //    day-nav header off the day and back (undiscoverable, and a
    //    pre-existing gap tracked separately).
    //  * `DailyTargetController.load` has no such assign-then-fail shape
    //    WITHIN one call (it assigns `target` only after the fetch returns),
    //    but the controller is app-scoped: a day it loaded successfully
    //    earlier stays in `target` when a later load for the same day fails,
    //    which reaches this decision as holds-the-day + `error` just the same.
    //
    // `== loaded` rather than `!= error`: `needsReauth` (and, for the target,
    // `saving`) must not stand down either. Not standing down when the data is
    // in fact fine costs one extra request; standing down when it is not costs
    // the user the day's data with no way back.
    final skipMeals =
        standDownRound &&
        (widget.todayController.isLoadingDay(day) ||
            (widget.todayController.holdsDay(day) &&
                widget.todayController.status == TodayStatus.loaded));
    final skipTarget =
        standDownRound &&
        (widget.dailyTargetController.isLoadingDay(day) ||
            (widget.dailyTargetController.holdsDay(day) &&
                widget.dailyTargetController.status ==
                    DailyTargetStatus.loaded));
    // Every stand-down is a BET that the claim it defers to lands
    // successfully. The `holdsDay` half checks that inline (the status clause
    // above); the `isLoadingDay` half cannot, because it decides while the
    // answer is still out — so it is covered afterwards instead, once that
    // claim settles. Both halves go through the same cover, so the one that
    // stood down on a `loaded` claim simply finds `landed()` true and does
    // nothing.
    if (skipMeals) {
      unawaited(
        _coverStandDown(
          controller: widget.todayController,
          claimInFlight: () => widget.todayController.isLoadingDay(day),
          landed: () =>
              widget.todayController.holdsDay(day) &&
              widget.todayController.status == TodayStatus.loaded,
          load: () => widget.todayController.load(token, day),
        ),
      );
    }
    if (skipTarget) {
      unawaited(
        _coverStandDown(
          controller: widget.dailyTargetController,
          claimInFlight: () => widget.dailyTargetController.isLoadingDay(day),
          landed: () =>
              widget.dailyTargetController.holdsDay(day) &&
              widget.dailyTargetController.status == DailyTargetStatus.loaded,
          load: () => widget.dailyTargetController.load(token, day),
        ),
      );
    }
    // ONE request for the whole screen (issue #114): fourteen sections in
    // place of the fifteen independent GETs this used to fan out, each of
    // which was its own draw from the deployed Worker's ~478ms-plus-tail
    // per-request cost.
    //
    // The window parameters come from the cards that own them, never from a
    // server default — the two endpoints' defaults differ on purpose (30 vs
    // 366), which is exactly the asymmetry a silent default gets wrong.
    // Clamped here, not only inside the repository: the same value has to be
    // the one the apply-gates below compare against, so a span the endpoint
    // could not have been asked for (outside `1..366`) is a section the card
    // refuses rather than one it accepts under the wrong window (D6).
    final trendDays = clampWindowDays(widget.trendController.spanDays);
    final careSpan = widget.careAdherenceController.spanDays;
    final careSpanDays = careSpan == null ? null : clampWindowDays(careSpan);
    final requestedMonth = parseDayString(day);
    // Claimed synchronously, BEFORE the request goes out, exactly as
    // `loadMonth` sets its own month: it is what lets the apply below tell a
    // response for the month this card is on from one for a month it has
    // since left — including the `reset()` (sign-out) case, whose whole point
    // is that every response in flight across it is stale.
    widget.healthCalendarController.claimBatchMonth(
      requestedMonth.year,
      requestedMonth.month,
    );
    // Same claim-before-the-request pattern for the six day-keyed trackers:
    // each records that IT, not a comparison against whatever day it already
    // holds, decided this round is authoritative — so the apply below is
    // dropped only when an explicit navigation has happened since (see
    // `WaterController._claimedGeneration`), not whenever the round's day
    // simply differs from the day already held.
    widget.todayController.claimBatchRound();
    widget.dailyTargetController.claimBatchRound();
    widget.waterController.claimBatchRound();
    widget.bowelController.claimBatchRound();
    widget.vitalsController.claimBatchRound();
    widget.exerciseController.claimBatchRound();

    HealthOverviewBatch batch;
    try {
      batch = await widget.screenBatchRepository.getHealthOverview(
        token,
        day: day,
        trendDays: trendDays,
        // `null` for a custom date range, which no `care_days` count can
        // describe. The request still goes out — thirteen other sections
        // depend on it — carrying the endpoint's own default, and the care
        // card simply refuses the section below and loads its own range.
        careDays: careSpanDays ?? _defaultCareDays,
      );
    } on ScreenBatchReauthRequired {
      batch = HealthOverviewBatch.requestFailed(reauth: true);
    } catch (_) {
      // Every other request-level fault — transport, timeout, 4xx, 5xx, an
      // undecodable body — is one fetch failure per card, never a re-auth
      // exit and never a whole-screen error (design D5). Deliberately not
      // `on ScreenBatchFetchFailure`: a fault this screen failed to
      // anticipate must still leave every card in a settled state rather
      // than on `loading` forever.
      batch = HealthOverviewBatch.requestFailed(reauth: false);
    }
    if (!mounted) return;

    // One apply path, whether the response was a 200 or a thrown failure.
    widget.weightGoalController.applyBatchSection(batch.weightGoal);
    final trendApplied = widget.trendController.applyBatchSection(
      batch.vitalsTrend,
      requestedSpanDays: trendDays,
    );
    final calendarApplied = widget.healthCalendarController.applyBatchSection(
      batch.healthCalendar,
      requestedYear: requestedMonth.year,
      requestedMonth: requestedMonth.month,
    );
    // The stand-down is now a decision about APPLYING these two sections, not
    // about issuing their requests (design D8): the batch goes out either
    // way, so all that is left of it is refusing to overwrite the diet day's
    // own fetch of the same day.
    if (!skipMeals) {
      widget.todayController.applyBatchSection(
        meals: batch.meals,
        dailyTarget: batch.dailyTarget,
      );
    }
    widget.dictionaryController.applyBatchSection(batch.favoriteFoodItems);
    if (!skipTarget) {
      widget.dailyTargetController.applyBatchSection(batch.dailyTarget);
    }
    widget.waterController.applyBatchSection(batch.water);
    widget.bowelController.applyBatchSection(batch.bowel);
    widget.vitalsController.applyBatchSection(batch.vitals);
    widget.exerciseController.applyBatchSection(
      activities: batch.exerciseActivities,
      exercise: batch.exercise,
    );
    widget.menstrualController.applyBatchSection(batch.menstrual);
    widget.careTodayController.applyBatchSection(batch.careToday);
    final careApplied = widget.careAdherenceController.applyBatchSection(
      batch.careRange,
      requestedSpanDays: careSpanDays ?? _defaultCareDays,
    );

    // The one or two cards whose window the batch could not describe — a
    // custom care period, a calendar paged to another month, a span switched
    // while the request was in flight — load themselves. The other twelve are
    // already applied, so this costs 1+1 requests instead of 15.
    await Future.wait([
      if (!trendApplied) widget.trendController.load(token),
      if (!calendarApplied) widget.healthCalendarController.load(token),
      if (!careApplied) widget.careAdherenceController.load(token),
    ]);
    if (!mounted) return;
    // Stamp the batch's last-loaded time only when at least one overview/trend
    // card actually loaded. The cards catch their own errors and don't rethrow,
    // so `Future.wait` above resolves even when every card failed (network
    // down) — keying off it would falsely claim a just-now load. Reading each
    // controller's status keeps this honest and aligned with the trackers.
    if (_overviewLoadedAny) {
      setState(() => _lastOverviewLoadAt = widget.clock());
    }
  }

  /// Whether at least one overview/trend controller ended its load in a
  /// successful (`loaded`) status — the signal that the batch fetched real
  /// data, used to decide whether [_lastOverviewLoadAt] advances.
  bool get _overviewLoadedAny =>
      widget.weightGoalController.status == WeightGoalStatus.loaded ||
      widget.trendController.status == TrendStatus.loaded ||
      widget.healthCalendarController.status == HealthCalendarStatus.loaded ||
      widget.menstrualController.status == MenstrualStatus.loaded ||
      widget.careTodayController.status == CareTodayLoadStatus.loaded ||
      widget.careAdherenceController.status == CareHistoryLoadStatus.loaded;

  bool get _overviewNeedsReauth =>
      widget.weightGoalController.status == WeightGoalStatus.needsReauth ||
      widget.trendController.status == TrendStatus.needsReauth ||
      widget.healthCalendarController.status ==
          HealthCalendarStatus.needsReauth ||
      // The next-period card has nothing to act on, so a 401 on the menstrual
      // load has no other way out: without it here, that 401 would wait for
      // some other controller to move before an exit appeared.
      widget.menstrualController.status == MenstrualStatus.needsReauth ||
      // The care card keeps its content on a non-loaded status (so a reload
      // can't blank the overview), which would otherwise make a 401 from
      // marking a dose a silent dead end: the row stays 待辦 with no error and
      // no way back. Surface it as the same re-authenticate exit as the others.
      widget.careTodayController.status == CareTodayLoadStatus.reauth ||
      // Same reasoning for the trend tab's care adherence card — a 401 from
      // a card-driven period switch must not be a dead end either.
      widget.careAdherenceController.status == CareHistoryLoadStatus.reauth;

  Future<void> _signOutAndClose() async {
    await widget.signOut();
    if (!mounted) return;
    if (context.canPop()) context.pop();
  }

  /// Opens the assistant carrying what this shell is showing right now — the
  /// active tab and, for the one day-keyed tab, the day — as `/assistant`
  /// query parameters, so the context survives a web refresh
  /// (`AssistantChatContext.fromQuery` rebuilds it from the URL).
  ///
  /// The day is the shell's own today (from the injected [HealthScaffold.clock],
  /// which is what makes it assertable in a test): 總覽 pre-loads the
  /// day-keyed trackers for today, and the diet screen's day selector belongs
  /// to a *pushed* screen that is not what this app bar is showing. 記錄, 趨勢
  /// and 更多 send no day at all — 記錄's body is a hub of buttons with no
  /// date on it and neither of the other two is day-keyed, so a day on any of
  /// them would put a view on the URL that no screen ever rendered.
  ///
  /// Awaited, then reloaded (the finance shell's shape): the assistant can
  /// record food and health entries, so the screen behind it is stale the
  /// moment the user returns.
  Future<void> _openAssistant() async {
    final tab = HealthTab.values[_index];
    final showsDay = tab == HealthTab.overview;
    final uri = Uri(
      path: '/assistant',
      queryParameters: {
        'ctx': 'health',
        'tab': tab.slug,
        if (showsDay) 'day': _todayString(widget.clock()),
      },
    );
    await context.push(uri.toString());
    if (!mounted) return;
    await _scheduleLoad();
  }

  String _title(AppLocalizations loc) => switch (_index) {
    0 => loc.dashboardTitle,
    1 => loc.healthTabRecord,
    2 => loc.trendCardTitle,
    _ => loc.dietTabMore,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (!_bootstrapped) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: Key('health-loading')),
        ),
      );
    }

    // An overview/trend controller 401 → a re-auth exit (mirrors the tracker
    // screens); recording and settings tabs are unaffected but the exit takes
    // precedence since a stale token affects everything.
    if (_overviewNeedsReauth) {
      return Scaffold(
        appBar: AppBar(title: Text(_title(loc))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('health-sign-in-again-button'),
                onPressed: _signOutAndClose,
                child: Text(loc.signInAgain),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(loc)),
        actions: [
          // Labelled, not an icon-only `IconButton`: only a tooltip would
          // name it, and a tooltip needs a hover or a long-press — on the
          // phone/PWA this app is used on, that leaves a bare robot glyph in
          // the app bar's utility corner meaning nothing.
          TextButton.icon(
            key: const Key('health-assistant-button'),
            icon: const Icon(Icons.smart_toy_outlined),
            // The app bar's title ellipsizes to make room for actions, so a
            // long translation at a large text scale would eat the tab name
            // whole before it ever overflowed. Capped and ellipsized here so
            // the pressure stops at this label instead.
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                loc.assistantOpenButton,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onPressed: () => unawaited(_openAssistant()),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _OverviewBody(
            refreshing: _loading,
            pushHealthController: widget.pushHealthController,
            weightGoalController: widget.weightGoalController,
            healthCalendarController: widget.healthCalendarController,
            careTodayController: widget.careTodayController,
            menstrualController: widget.menstrualController,
            idToken: _idToken,
            onRefresh: _scheduleLoad,
            lastLoadedAt: _lastOverviewLoadAt,
          ),
          const _RecordHub(),
          _TrendBody(
            controller: widget.trendController,
            careAdherenceController: widget.careAdherenceController,
            idToken: _idToken,
            heightCm: widget.weightGoalController.goal?.heightCm,
            onOpenCareHistory: widget.onOpenCareHistory,
            onOpenCareItems: widget.onOpenCareItems,
            onRefresh: _scheduleLoad,
            lastLoadedAt: _lastOverviewLoadAt,
          ),
          _MoreBody(
            onOpenSettings: widget.onOpenSettings,
            onOpenImport: widget.onOpenImport,
            onOpenReminders: widget.onOpenReminders,
            onOpenCareItems: widget.onOpenCareItems,
            onOpenCareToday: widget.onOpenCareToday,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: loc.dashboardTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.edit_note),
            label: loc.healthTabRecord,
          ),
          NavigationDestination(
            icon: const Icon(Icons.show_chart),
            label: loc.trendCardTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            label: loc.dietTabMore,
          ),
        ],
      ),
    );
  }
}

/// 總覽: the at-a-glance cards (today's care + goal + next period + this-month
/// record calendar).
class _OverviewBody extends StatelessWidget {
  final PushHealthController pushHealthController;
  final WeightGoalController weightGoalController;
  final HealthCalendarController healthCalendarController;
  final CareTodayController careTodayController;
  final MenstrualController menstrualController;
  final IdTokenProvider idToken;

  /// Whether a whole-screen round is in flight. Handed to every card that
  /// carries a [StaleNotice], which is the only in-flight feedback a
  /// [DataRevision] bump has (a pull-to-refresh also has its own spinner).
  final bool refreshing;

  /// Pull-to-refresh handler — the scaffold's batched reload; its future
  /// settles when the reload finishes so the spinner stays until then.
  final Future<void> Function() onRefresh;

  /// When the overview/trends batch last loaded successfully (shared with the
  /// trend tab), or `null` before the first success.
  final DateTime? lastLoadedAt;

  const _OverviewBody({
    required this.refreshing,
    required this.pushHealthController,
    required this.weightGoalController,
    required this.healthCalendarController,
    required this.careTodayController,
    required this.menstrualController,
    required this.idToken,
    required this.onRefresh,
    required this.lastLoadedAt,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              // Always scrollable so a short overview (few cards) still accepts
              // the overscroll pull that triggers a refresh.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                LastLoadedLabel(lastLoadedAt: lastLoadedAt),
                // Only with slots today: the summary card renders for
                // zero-schedule users too (its setup prompt), and warning
                // someone with no reminders that notifications are off is pure
                // noise to them.
                if (careTodayController.slots.isNotEmpty)
                  PushOffBanner(health: pushHealthController.health),
                CareTodaySummaryCard(
                  controller: careTodayController,
                  idToken: idToken,
                  refreshing: refreshing,
                  onManage: () => context.push('/care-items'),
                  onSetup: () => context.push('/care-items'),
                ),
                GoalCard(
                  controller: weightGoalController,
                  idToken: idToken,
                  refreshing: refreshing,
                ),
                const SizedBox(height: 16),
                // Above the calendar card, not after it: the calendar is a whole
                // month grid plus three rings, so anything below it is off the
                // first screen on a phone — and being seen without opening the
                // tracker is this card's entire purpose.
                NextPeriodCard(
                  controller: menstrualController,
                  idToken: idToken,
                  refreshing: refreshing,
                  onOpen: () => context.push('/health/menstrual'),
                ),
                const SizedBox(height: 16),
                HealthCalendarCard(
                  controller: healthCalendarController,
                  idToken: idToken,
                  refreshing: refreshing,
                  weightAchievementRate:
                      weightGoalController.goal?.achievementRate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 趨勢: the vitals trend chart followed by the care adherence card (design
/// §B — vitals are the primary axis, care is the secondary one, so the care
/// card is ordered after the trend chart, not before it).
class _TrendBody extends StatelessWidget {
  final TrendController controller;
  final CareHistoryController careAdherenceController;
  final IdTokenProvider idToken;
  final double? heightCm;
  final VoidCallback onOpenCareHistory;
  final VoidCallback onOpenCareItems;

  /// Pull-to-refresh handler — the same batched reload the overview uses (they
  /// load together); its future settles when the reload finishes.
  final Future<void> Function() onRefresh;

  /// When the overview/trends batch last loaded successfully (shared with the
  /// overview tab), or `null` before the first success.
  final DateTime? lastLoadedAt;

  const _TrendBody({
    required this.controller,
    required this.careAdherenceController,
    required this.idToken,
    required this.heightCm,
    required this.onOpenCareHistory,
    required this.onOpenCareItems,
    required this.onRefresh,
    required this.lastLoadedAt,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              // Always scrollable so the short trends tab (two cards) still
              // accepts the overscroll pull that triggers a refresh.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                LastLoadedLabel(lastLoadedAt: lastLoadedAt),
                TrendCard(
                  controller: controller,
                  idToken: idToken,
                  heightCm: heightCm,
                ),
                const SizedBox(height: 16),
                CareAdherenceCard(
                  controller: careAdherenceController,
                  idToken: idToken,
                  onOpenHistory: onOpenCareHistory,
                  onOpenCareItems: onOpenCareItems,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 更多: app settings + chaodays import + reminders + care reminders entries
/// (theme / language / sign-out live in SettingsScreen; the chaodays import
/// form lives in ChaodaysImportScreen; push reminders live in
/// ReminderSettingsScreen; care reminders — medication/rehab/radiotherapy
/// care/custom — live in CareItemsScreen; today's care checklist — distinct
/// from the manage entry — lives in CareTodayScreen).
class _MoreBody extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenImport;
  final VoidCallback onOpenReminders;
  final VoidCallback onOpenCareItems;
  final VoidCallback onOpenCareToday;

  const _MoreBody({
    required this.onOpenSettings,
    required this.onOpenImport,
    required this.onOpenReminders,
    required this.onOpenCareItems,
    required this.onOpenCareToday,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LedgeCard(
                child: ListTile(
                  key: const Key('health-more-care-today'),
                  leading: const Icon(Icons.checklist_outlined),
                  title: Text(loc.careTodayTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenCareToday,
                ),
              ),
              const SizedBox(height: 12),
              LedgeCard(
                child: ListTile(
                  key: const Key('health-more-reminders'),
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(loc.reminderTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenReminders,
                ),
              ),
              const SizedBox(height: 12),
              LedgeCard(
                child: ListTile(
                  key: const Key('health-more-care-items'),
                  leading: const Icon(Icons.health_and_safety_outlined),
                  title: Text(loc.careRemindersTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenCareItems,
                ),
              ),
              const SizedBox(height: 12),
              LedgeCard(
                child: ListTile(
                  key: const Key('health-more-import'),
                  leading: const Icon(Icons.cloud_download),
                  title: Text(loc.importTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenImport,
                ),
              ),
              const SizedBox(height: 12),
              LedgeCard(
                child: ListTile(
                  key: const Key('health-more-settings'),
                  leading: const Icon(Icons.settings),
                  title: Text(loc.settingsTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 記錄: a flat hub of every day-keyed tracker; each tile pushes its screen for
/// today. Replaces the old bottom-nav tabs + nested 更多 menu — every tracker is
/// one tap from here.
class _RecordHub extends StatelessWidget {
  const _RecordHub();

  /// Navigates to a tracker's route (`/health/<name>`). The screen is built by
  /// the app router (from injected controllers), nested under `/health`, so a
  /// web back / refresh reconstructs the full stack from the URL.
  void _push(BuildContext context, String name) =>
      context.push('/health/$name');

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HubTile(
                tileKey: const Key('hub-tile-diet'),
                icon: Icons.restaurant,
                label: loc.healthRecordDiet,
                onTap: () => _push(context, 'diet'),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-water'),
                icon: Icons.water_drop,
                label: loc.dietTabWater,
                onTap: () => _push(context, 'water'),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-vitals'),
                icon: Icons.monitor_heart,
                label: loc.dietTabVitals,
                onTap: () => _push(context, 'vitals'),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-exercise'),
                icon: Icons.fitness_center,
                label: loc.dietTabExercise,
                onTap: () => _push(context, 'exercise'),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-bowel'),
                icon: Icons.wc,
                label: loc.dietTabBowel,
                onTap: () => _push(context, 'bowel'),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-menstrual'),
                icon: Icons.calendar_month,
                label: loc.menstrualTitle,
                onTap: () => _push(context, 'menstrual'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final Key tileKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HubTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LedgeCard(
        child: ListTile(
          key: tileKey,
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
