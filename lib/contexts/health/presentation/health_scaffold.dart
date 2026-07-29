import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/data_revision.dart';
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
  String? _idToken;

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

  @override
  void initState() {
    super.initState();
    for (final c in _overviewControllers) {
      c.addListener(_onChanged);
    }
    widget.dataRevision.addListener(_onRevisionChanged);
    _scheduleLoad();
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

  void _onRevisionChanged() => _scheduleLoad();

  /// Runs [_load] immediately if nothing is in flight, otherwise marks a
  /// reload as pending so exactly one more load runs once the current one
  /// finishes.
  void _scheduleLoad() {
    if (_loading) {
      _reloadPending = true;
      return;
    }
    _loading = true;
    // Clear the flag on failure too: a load that throws (the token fetch is the
    // one call here that can) would otherwise leave `_loading` set forever and
    // silently drop every later refresh for the rest of the session. The
    // controllers surface their own load errors, so nothing is swallowed here.
    _load().then((_) {}, onError: (_) {}).whenComplete(() {
      _loading = false;
      final pending = _reloadPending;
      _reloadPending = false;
      if (pending && mounted) _scheduleLoad();
    });
  }

  Future<void> _load() async {
    final token = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    setState(() => _idToken = token);
    final day = _todayString(widget.clock());
    // Independent loads run concurrently so the landing (overview) cards and the
    // trackers all populate without waiting on a serial chain.
    await Future.wait([
      widget.weightGoalController.load(token),
      widget.trendController.load(token),
      widget.healthCalendarController.load(token),
      widget.todayController.load(token, day),
      widget.dictionaryController.load(token),
      widget.dailyTargetController.load(token, day),
      widget.waterController.load(token, day),
      widget.bowelController.load(token, day),
      widget.vitalsController.load(token, day),
      widget.exerciseController.load(token, day),
      widget.menstrualController.load(token),
      widget.careTodayController.load(token),
      widget.careAdherenceController.load(token),
    ]);
  }

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
    final idToken = _idToken;

    if (idToken == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(key: Key('health-loading'))),
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
            idToken: idToken,
          ),
          const _RecordHub(),
          _TrendBody(
            controller: widget.trendController,
            careAdherenceController: widget.careAdherenceController,
            idToken: idToken,
            heightCm: widget.weightGoalController.goal?.heightCm,
            onOpenCareHistory: widget.onOpenCareHistory,
            onOpenCareItems: widget.onOpenCareItems,
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
  final String idToken;

  const _OverviewBody({
    required this.pushHealthController,
    required this.weightGoalController,
    required this.healthCalendarController,
    required this.careTodayController,
    required this.menstrualController,
    required this.idToken,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
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
                weightAchievementRate: weightGoalController.goal?.achievementRate,
              ),
            ],
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
  final String idToken;
  final double? heightCm;
  final VoidCallback onOpenCareHistory;
  final VoidCallback onOpenCareItems;

  const _TrendBody({
    required this.controller,
    required this.careAdherenceController,
    required this.idToken,
    required this.heightCm,
    required this.onOpenCareHistory,
    required this.onOpenCareItems,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TrendCard(controller: controller, idToken: idToken, heightCm: heightCm),
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
  void _push(BuildContext context, String name) => context.push('/health/$name');

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
