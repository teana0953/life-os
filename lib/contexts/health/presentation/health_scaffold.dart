import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/data_revision.dart';
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
    _loading = true;
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
      _loading = false;
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
    // Independent loads run concurrently so the landing (overview) cards and the
    // trackers all populate without waiting on a serial chain.
    await Future.wait([
      widget.weightGoalController.load(token),
      widget.trendController.load(token),
      widget.healthCalendarController.load(token),
      if (!skipMeals) widget.todayController.load(token, day),
      widget.dictionaryController.load(),
      if (!skipTarget) widget.dailyTargetController.load(token, day),
      widget.waterController.load(token, day),
      widget.bowelController.load(token, day),
      widget.vitalsController.load(token, day),
      widget.exerciseController.load(token, day),
      widget.menstrualController.load(token),
      widget.careTodayController.load(token),
      widget.careAdherenceController.load(token),
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
      appBar: AppBar(title: Text(_title(loc))),
      body: IndexedStack(
        index: _index,
        children: [
          _OverviewBody(
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

  /// Pull-to-refresh handler — the scaffold's batched reload; its future
  /// settles when the reload finishes so the spinner stays until then.
  final Future<void> Function() onRefresh;

  /// When the overview/trends batch last loaded successfully (shared with the
  /// trend tab), or `null` before the first success.
  final DateTime? lastLoadedAt;

  const _OverviewBody({
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
                  onManage: () => context.push('/care-items'),
                  onSetup: () => context.push('/care-items'),
                ),
                GoalCard(controller: weightGoalController, idToken: idToken),
                const SizedBox(height: 16),
                // Above the calendar card, not after it: the calendar is a whole
                // month grid plus three rings, so anything below it is off the
                // first screen on a phone — and being seen without opening the
                // tracker is this card's entire purpose.
                NextPeriodCard(
                  controller: menstrualController,
                  idToken: idToken,
                  onOpen: () => context.push('/health/menstrual'),
                ),
                const SizedBox(height: 16),
                HealthCalendarCard(
                  controller: healthCalendarController,
                  idToken: idToken,
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
