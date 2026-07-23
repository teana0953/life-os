import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../../body_profile/presentation/goal_card.dart';
import '../../body_profile/presentation/weight_goal_controller.dart';
import '../../bowel/presentation/bowel_controller.dart';
import '../../bowel/presentation/bowel_screen.dart';
import '../../exercise/presentation/exercise_controller.dart';
import '../../exercise/presentation/exercise_screen.dart';
import '../../health_calendar/presentation/health_calendar_card.dart';
import '../../health_calendar/presentation/health_calendar_controller.dart';
import '../../hydration/presentation/water_controller.dart';
import '../../hydration/presentation/water_screen.dart';
import '../../menstrual/presentation/menstrual_controller.dart';
import '../../menstrual/presentation/menstrual_screen.dart';
import '../../vitals/presentation/trend_card.dart';
import '../../vitals/presentation/trend_controller.dart';
import '../../vitals/presentation/vitals_controller.dart';
import '../../vitals/presentation/vitals_screen.dart';
import '../application/get_logged_days.dart';
import 'create_meal_controller.dart';
import 'daily_target_controller.dart';
import 'dictionary_controller.dart';
import 'diet_day_screen.dart';
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

  /// Opens the app settings (theme / language / sign-out), wired by the caller.
  final VoidCallback onOpenSettings;

  final DateTime Function() clock;

  const HealthScaffold({
    super.key,
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
    required this.onOpenSettings,
    this.clock = DateTime.now,
  });

  @override
  State<HealthScaffold> createState() => _HealthScaffoldState();
}

class _HealthScaffoldState extends State<HealthScaffold> {
  int _index = 0;
  String? _idToken;

  @override
  void initState() {
    super.initState();
    for (final c in _overviewControllers) {
      c.addListener(_onChanged);
    }
    _load();
  }

  List<Listenable> get _overviewControllers => [
    widget.weightGoalController,
    widget.trendController,
    widget.healthCalendarController,
  ];

  @override
  void dispose() {
    for (final c in _overviewControllers) {
      c.removeListener(_onChanged);
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

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
    ]);
  }

  bool get _overviewNeedsReauth =>
      widget.weightGoalController.status == WeightGoalStatus.needsReauth ||
      widget.trendController.status == TrendStatus.needsReauth ||
      widget.healthCalendarController.status ==
          HealthCalendarStatus.needsReauth;

  Future<void> _signOutAndClose() async {
    await widget.signOut();
    if (!mounted) return;
    if (Navigator.canPop(context)) Navigator.of(context).pop();
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
            weightGoalController: widget.weightGoalController,
            healthCalendarController: widget.healthCalendarController,
            idToken: idToken,
          ),
          _RecordHub(
            idToken: idToken,
            clock: widget.clock,
            authRepository: widget.authRepository,
            signOut: widget.signOut,
            todayController: widget.todayController,
            dictionaryController: widget.dictionaryController,
            dailyTargetController: widget.dailyTargetController,
            createMealController: widget.createMealController,
            getLoggedDays: widget.getLoggedDays,
            waterController: widget.waterController,
            bowelController: widget.bowelController,
            vitalsController: widget.vitalsController,
            exerciseController: widget.exerciseController,
            menstrualController: widget.menstrualController,
          ),
          _TrendBody(
            controller: widget.trendController,
            idToken: idToken,
            heightCm: widget.weightGoalController.goal?.heightCm,
          ),
          _MoreBody(onOpenSettings: widget.onOpenSettings),
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

/// 總覽: the at-a-glance cards (goal + this-month record calendar).
class _OverviewBody extends StatelessWidget {
  final WeightGoalController weightGoalController;
  final HealthCalendarController healthCalendarController;
  final String idToken;

  const _OverviewBody({
    required this.weightGoalController,
    required this.healthCalendarController,
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
              GoalCard(controller: weightGoalController, idToken: idToken),
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

/// 趨勢: the full trend chart.
class _TrendBody extends StatelessWidget {
  final TrendController controller;
  final String idToken;
  final double? heightCm;

  const _TrendBody({
    required this.controller,
    required this.idToken,
    required this.heightCm,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 更多: app settings entry (theme / language / sign-out live in SettingsScreen).
class _MoreBody extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _MoreBody({required this.onOpenSettings});

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
  final String idToken;
  final DateTime Function() clock;
  final AuthRepository authRepository;
  final SignOut signOut;
  final TodayController todayController;
  final DictionaryController dictionaryController;
  final DailyTargetController dailyTargetController;
  final CreateMealController createMealController;
  final GetLoggedDays getLoggedDays;
  final WaterController waterController;
  final BowelController bowelController;
  final VitalsController vitalsController;
  final ExerciseController exerciseController;
  final MenstrualController menstrualController;

  const _RecordHub({
    required this.idToken,
    required this.clock,
    required this.authRepository,
    required this.signOut,
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
  });

  String get _today =>
      '${clock().year.toString().padLeft(4, '0')}-'
      '${clock().month.toString().padLeft(2, '0')}-'
      '${clock().day.toString().padLeft(2, '0')}';

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

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
                onTap: () => _push(
                  context,
                  DietDayScreen(
                    authRepository: authRepository,
                    idToken: idToken,
                    todayController: todayController,
                    dictionaryController: dictionaryController,
                    dailyTargetController: dailyTargetController,
                    createMealController: createMealController,
                    getLoggedDays: getLoggedDays,
                    signOut: signOut,
                    clock: clock,
                  ),
                ),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-water'),
                icon: Icons.water_drop,
                label: loc.dietTabWater,
                onTap: () => _push(
                  context,
                  WaterScreen(controller: waterController, idToken: idToken, day: _today, clock: clock),
                ),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-vitals'),
                icon: Icons.monitor_heart,
                label: loc.dietTabVitals,
                onTap: () => _push(
                  context,
                  VitalsScreen(controller: vitalsController, idToken: idToken, day: _today, clock: clock),
                ),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-exercise'),
                icon: Icons.fitness_center,
                label: loc.dietTabExercise,
                onTap: () => _push(
                  context,
                  ExerciseScreen(controller: exerciseController, idToken: idToken, day: _today, clock: clock),
                ),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-bowel'),
                icon: Icons.wc,
                label: loc.dietTabBowel,
                onTap: () => _push(
                  context,
                  BowelScreen(controller: bowelController, idToken: idToken, day: _today, clock: clock),
                ),
              ),
              _HubTile(
                tileKey: const Key('hub-tile-menstrual'),
                icon: Icons.calendar_month,
                label: loc.menstrualTitle,
                onTap: () => _push(
                  context,
                  MenstrualScreen(controller: menstrualController, idToken: idToken, clock: clock),
                ),
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
