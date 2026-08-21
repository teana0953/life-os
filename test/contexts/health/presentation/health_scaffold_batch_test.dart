import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/infrastructure/http_body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/presentation/goal_card.dart';
import 'package:life_os/contexts/body_profile/presentation/weight_goal_controller.dart';
import 'package:life_os/contexts/bowel/application/get_bowel_day.dart';
import 'package:life_os/contexts/bowel/application/save_bowel_day.dart';
import 'package:life_os/contexts/bowel/infrastructure/http_bowel_repository.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_controller.dart';
import 'package:life_os/contexts/exercise/application/add_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/delete_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/get_exercise_day.dart';
import 'package:life_os/contexts/exercise/application/list_exercise_activities.dart';
import 'package:life_os/contexts/exercise/infrastructure/http_exercise_repository.dart';
import 'package:life_os/contexts/exercise/presentation/exercise_controller.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal_item.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/infrastructure/http_daily_target_repository.dart';
import 'package:life_os/contexts/health/infrastructure/http_food_dictionary_repository.dart';
import 'package:life_os/contexts/health/infrastructure/http_meal_repository.dart';
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/health_scaffold.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/health_calendar/application/get_health_calendar.dart';
import 'package:life_os/contexts/health_calendar/infrastructure/http_health_calendar_repository.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_card.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'package:life_os/contexts/hydration/application/add_water.dart';
import 'package:life_os/contexts/hydration/application/get_water_day.dart';
import 'package:life_os/contexts/hydration/application/set_water_target.dart';
import 'package:life_os/contexts/hydration/infrastructure/http_water_repository.dart';
import 'package:life_os/contexts/hydration/presentation/water_controller.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/infrastructure/http_menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';
import 'package:life_os/contexts/menstrual/presentation/next_period_card.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/application/get_care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history_period.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_care_history_repository.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_care_today_repository.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_summary_card.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/infrastructure/http_vitals_repository.dart';
import 'package:life_os/contexts/vitals/presentation/trend_controller.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';
import 'package:life_os/shared/data_revision.dart';
import 'package:life_os/shared/screen_batch/screen_batch_repository.dart';

import '../../../shared/screen_batch/batch_fixtures.dart';
import '../../../support/l10n_test_app.dart';
import '../../../support/push_health.dart';

const _baseUrl = 'https://api.test';

/// Every request the whole rig made, in order — path plus query.
///
/// A recorded request list, not "the batch repository was called": a stub
/// repository plus one forgotten `controller.load()` passes the second and
/// fails the first, and that forgotten load is precisely the way this change
/// gets shipped half-done (design D11).
class _RequestLog {
  final List<Uri> requests = [];

  List<String> get paths => requests.map((u) => u.path).toList();
}

/// The rig: every controller backed by its REAL http repository over one
/// recording client, so a granular call from anywhere shows up in the log.
class _Rig {
  final _RequestLog log;
  final Widget widget;
  final WeightGoalController weightGoal;
  final TrendController trend;
  final HealthCalendarController calendar;
  final TodayController today;
  final DailyTargetController dailyTarget;
  final DictionaryController dictionary;
  final WaterController water;
  final BowelController bowel;
  final VitalsController vitals;
  final ExerciseController exercise;
  final MenstrualController menstrual;
  final CareTodayController careToday;
  final CareHistoryController careAdherence;
  final DataRevision dataRevision;

  _Rig({
    required this.log,
    required this.widget,
    required this.weightGoal,
    required this.trend,
    required this.calendar,
    required this.today,
    required this.dailyTarget,
    required this.dictionary,
    required this.water,
    required this.bowel,
    required this.vitals,
    required this.exercise,
    required this.menstrual,
    required this.careToday,
    required this.careAdherence,
    required this.dataRevision,
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<String?> idToken() async => 'token';

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

_Rig _buildRig({
  DateTime Function()? clock,
  int trendSpanDays = 30,
  int careSpanDays = 30,
  Map<String, dynamic>? overviewBody,
  int overviewStatus = 200,
  Object? overviewThrows,
  Completer<void>? overviewGate,

  /// Which `/api/health-overview` request [overviewGate] holds, 1-based —
  /// so a test can settle earlier rounds and then keep a later one in flight.
  int gateFromRound = 1,
  Completer<void>? vitalsRangeGate,
  Completer<void>? waterGate,
}) {
  final log = _RequestLog();
  final day = (clock ?? () => DateTime(2026, 8, 20))();
  final dayString =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  var overviewRounds = 0;
  final client = MockClient((request) async {
    log.requests.add(request.url);
    if (request.url.path == '/api/health-overview') {
      overviewRounds++;
      if (overviewGate != null && overviewRounds >= gateFromRound) {
        await overviewGate.future;
      }
      if (overviewThrows != null) throw overviewThrows;
      if (overviewStatus != 200) {
        return http.Response('{"error":"boom"}', overviewStatus);
      }
      return http.Response(
        jsonEncode(
          overviewBody ??
              healthOverviewBody(
                day: dayString,
                calendarYear: day.year,
                calendarMonth: day.month,
              ),
        ),
        200,
      );
    }
    if (request.url.path == '/api/vitals/range' && vitalsRangeGate != null) {
      await vitalsRangeGate.future;
    }
    if (request.url.path == '/api/water' && waterGate != null) {
      await waterGate.future;
    }
    return _granularResponse(request.url, dayString);
  });

  final bodyProfile = HttpBodyProfileRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final vitalsRepository = HttpVitalsRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final calendarRepository = HttpHealthCalendarRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final mealRepository = HttpMealRepository(baseUrl: _baseUrl, client: client);
  final targetRepository = HttpDailyTargetRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final dictionaryRepository = HttpFoodDictionaryRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final waterRepository = HttpWaterRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final bowelRepository = HttpBowelRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final exerciseRepository = HttpExerciseRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final menstrualRepository = HttpMenstrualRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final careTodayRepository = HttpCareTodayRepository(
    baseUrl: _baseUrl,
    client: client,
  );
  final careHistoryRepository = HttpCareHistoryRepository(
    baseUrl: _baseUrl,
    client: client,
  );

  final resolvedClock = clock ?? () => DateTime(2026, 8, 20);
  final auth = _FakeAuthRepository();
  final dataRevision = DataRevision();

  final weightGoal = WeightGoalController(
    GetWeightGoal(bodyProfile),
    GetBodyProfile(bodyProfile),
    SetBodyProfile(bodyProfile),
  );
  final trend = TrendController(
    GetVitalsTrends(vitalsRepository),
    clock: resolvedClock,
  )..spanDays = trendSpanDays;
  final calendar = HealthCalendarController(
    GetHealthCalendar(calendarRepository),
    clock: resolvedClock,
  );
  final today = TodayController(
    GetDayMeals(mealRepository),
    GetDailyTargetWithRemaining(targetRepository),
    EditMealItem(mealRepository),
    DeleteMealItem(mealRepository),
    ChangeMealTime(mealRepository),
    DeleteMeal(mealRepository),
  );
  final dailyTarget = DailyTargetController(
    GetDailyTargetWithRemaining(targetRepository),
    SetDailyTarget(targetRepository),
  );
  final dictionary = DictionaryController(
    SearchDictionary(dictionaryRepository),
    ListFavorites(dictionaryRepository),
    FavoriteFood(dictionaryRepository),
    UnfavoriteFood(dictionaryRepository),
    idToken: () async => 'token',
  );
  final water = WaterController(
    GetWaterDay(waterRepository),
    AddWater(waterRepository),
    SetWaterTarget(waterRepository),
  );
  final bowel = BowelController(
    GetBowelDay(bowelRepository),
    SaveBowelDay(bowelRepository),
  );
  final vitals = VitalsController(
    GetVitalsDay(vitalsRepository),
    SaveVitalsDay(vitalsRepository),
  );
  final exercise = ExerciseController(
    ListExerciseActivities(exerciseRepository),
    GetExerciseDay(exerciseRepository),
    AddExerciseEntry(exerciseRepository),
    DeleteExerciseEntry(exerciseRepository),
  );
  final menstrual = MenstrualController(
    GetMenstrualOverview(menstrualRepository),
    AddPeriod(menstrualRepository),
    UpdatePeriod(menstrualRepository),
    DeletePeriod(menstrualRepository),
  );
  final careToday = CareTodayController(
    GetCareToday(careTodayRepository),
    MarkCareDone(careTodayRepository),
    MarkCareSkipped(careTodayRepository),
    EditCareSlot(careHistoryRepository),
  );
  final careAdherence = CareHistoryController(
    GetCareHistory(careHistoryRepository),
    EditCareSlot(careHistoryRepository),
    dataRevision,
    period: CareHistoryPeriod.span(careSpanDays),
    clock: resolvedClock,
  );

  return _Rig(
    log: log,
    weightGoal: weightGoal,
    trend: trend,
    calendar: calendar,
    today: today,
    dailyTarget: dailyTarget,
    dictionary: dictionary,
    water: water,
    bowel: bowel,
    vitals: vitals,
    exercise: exercise,
    menstrual: menstrual,
    careToday: careToday,
    careAdherence: careAdherence,
    dataRevision: dataRevision,
    widget: HealthScaffold(
      screenBatchRepository: HttpScreenBatchRepository(
        baseUrl: _baseUrl,
        client: client,
      ),
      pushHealthController: testPushHealthController(),
      authRepository: auth,
      signOut: SignOut(auth),
      weightGoalController: weightGoal,
      trendController: trend,
      healthCalendarController: calendar,
      todayController: today,
      dictionaryController: dictionary,
      dailyTargetController: dailyTarget,
      createMealController: CreateMealController(CreateMeal(mealRepository)),
      getLoggedDays: GetLoggedDays(mealRepository),
      waterController: water,
      bowelController: bowel,
      vitalsController: vitals,
      exerciseController: exercise,
      menstrualController: menstrual,
      careTodayController: careToday,
      careAdherenceController: careAdherence,
      onOpenSettings: () {},
      onOpenImport: () {},
      onOpenReminders: () {},
      onOpenCareItems: () {},
      onOpenCareToday: () {},
      onOpenCareHistory: () {},
      dataRevision: dataRevision,
      clock: resolvedClock,
    ),
  );
}

/// Answers the granular endpoints too, so a stray granular call is a
/// *recorded request* rather than a failed card — the assertion is about the
/// request list, and a fixture that made the stray call fail would let a
/// weaker "everything loaded" test pass with the call still being made.
http.Response _granularResponse(Uri url, String day) => switch (url.path) {
  '/api/weight-goal' => http.Response(jsonEncode(weightGoalPayload), 200),
  '/api/body-profile' => http.Response(
    jsonEncode({'height_cm': 170, 'target_weight_kg': 62}),
    200,
  ),
  '/api/vitals/range' => http.Response(
    jsonEncode(
      vitalsRangePayload(
        from: url.queryParameters['from']!,
        to: url.queryParameters['to']!,
      ),
    ),
    200,
  ),
  '/api/health-calendar' => http.Response(
    jsonEncode(
      healthCalendarPayload(
        year: int.parse(url.queryParameters['month']!.split('-')[0]),
        month: int.parse(url.queryParameters['month']!.split('-')[1]),
      ),
    ),
    200,
  ),
  '/api/meals' => http.Response(jsonEncode(mealsPayload(day)), 200),
  '/api/daily-target' => http.Response(
    jsonEncode(dailyTargetPayload(day)),
    200,
  ),
  '/api/food-items/favorites' => http.Response(
    jsonEncode(favoriteFoodItemsPayload),
    200,
  ),
  '/api/water' => http.Response(
    jsonEncode(waterPayload(url.queryParameters['day'] ?? day)),
    200,
  ),
  '/api/bowel' => http.Response(jsonEncode(bowelPayload(day)), 200),
  '/api/vitals' => http.Response(jsonEncode(vitalsDayPayload(day)), 200),
  '/api/exercise/activities' => http.Response(
    jsonEncode(exerciseActivitiesPayload),
    200,
  ),
  '/api/exercise' => http.Response(jsonEncode(exercisePayload(day)), 200),
  '/api/menstrual' => http.Response(jsonEncode(menstrualPayload), 200),
  '/api/care/today' => http.Response(jsonEncode(careTodayPayload(day)), 200),
  '/api/care/range' => http.Response(
    jsonEncode(
      careRangePayload(
        from: url.queryParameters['from']!,
        to: url.queryParameters['to']!,
      ),
    ),
    200,
  ),
  _ => http.Response('{"error":"unexpected ${url.path}"}', 404),
};

/// The fourteen granular paths a whole-screen load used to hit.
const _granularPaths = [
  '/api/weight-goal',
  '/api/body-profile',
  '/api/vitals/range',
  '/api/health-calendar',
  '/api/meals',
  '/api/daily-target',
  '/api/food-items/favorites',
  '/api/water',
  '/api/bowel',
  '/api/vitals',
  '/api/exercise/activities',
  '/api/exercise',
  '/api/menstrual',
  '/api/care/today',
  '/api/care/range',
];

void main() {
  group('one request replaces fifteen', () {
    testWidgets('a whole-screen load records exactly one request, to '
        '/api/health-overview', (tester) async {
      final rig = _buildRig();
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.log.paths, ['/api/health-overview']);
      for (final path in _granularPaths) {
        expect(
          rig.log.paths,
          isNot(contains(path)),
          reason: '$path must not be requested by a whole-screen load',
        );
      }
    });

    testWidgets('every card ends loaded from its own section', (tester) async {
      final rig = _buildRig();
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.weightGoal.status, WeightGoalStatus.loaded);
      expect(rig.weightGoal.goal!.currentWeightKg, 68.4);
      expect(rig.trend.status, TrendStatus.loaded);
      expect(rig.calendar.status, HealthCalendarStatus.loaded);
      expect(rig.today.status, TodayStatus.loaded);
      expect(rig.dailyTarget.status, DailyTargetStatus.loaded);
      expect(rig.dictionary.status, DictionaryStatus.loaded);
      expect(rig.water.status, WaterStatus.loaded);
      expect(rig.water.day!.totalMl, 900);
      expect(rig.bowel.status, BowelStatus.loaded);
      expect(rig.vitals.status, VitalsStatus.loaded);
      expect(rig.exercise.status, ExerciseStatus.loaded);
      expect(rig.exercise.activities, isNotEmpty);
      expect(rig.menstrual.status, MenstrualStatus.loaded);
      expect(rig.careToday.status, CareTodayLoadStatus.loaded);
      expect(rig.careAdherence.status, CareHistoryLoadStatus.loaded);
    });

    // The duplicate `/api/daily-target` per load is gone as a consequence of
    // both controllers reading ONE section, not as separate work.
    testWidgets('the daily_target section lands on both controllers and no '
        'second target request is made', (tester) async {
      final rig = _buildRig();
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.today.target!.effective.staple, 4);
      expect(rig.dailyTarget.target!.effective.staple, 4);
      expect(rig.log.paths.where((p) => p == '/api/daily-target'), isEmpty);
    });
  });

  group('a failed section fails one card, never the screen', () {
    testWidgets('one ok:false section fails that card and leaves the rest '
        'loaded, with no re-auth exit', (tester) async {
      final body = healthOverviewBody()..['bowel'] = failedSection();
      final rig = _buildRig(overviewBody: body);
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.bowel.status, BowelStatus.error);
      expect(rig.bowel.error, BowelError.fetchFailed);
      expect(rig.water.status, WaterStatus.loaded);
      expect(rig.weightGoal.status, WeightGoalStatus.loaded);
      expect(
        find.byKey(const Key('health-sign-in-again-button')),
        findsNothing,
      );
    });

    // The spec scenario is about what the user SEES: for these four cards
    // "no data" is a legitimate, quiet state (no cycles logged, no goal set,
    // a month with nothing recorded, no care scheduled), so a failed section
    // rendering as one of those is indistinguishable from a working screen.
    // A controller enum cannot tell those apart — only the rendered card can
    // (design D11).
    testWidgets('a failed section renders its card as failed, never as an '
        'empty card', (tester) async {
      final body = healthOverviewBody()
        ..['menstrual'] = failedSection()
        ..['weight_goal'] = failedSection()
        ..['health_calendar'] = failedSection()
        ..['care_today'] = failedSection();
      // Tall enough that the whole overview list is built: these assertions
      // are about what the four cards render, and a lazily-built ListView
      // leaves the ones below the fold out of the tree entirely.
      await tester.binding.setSurfaceSize(const Size(600, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final rig = _buildRig(overviewBody: body);
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.menstrual.status, MenstrualStatus.error);
      expect(find.byKey(const Key('next-period-error')), findsOneWidget);
      expect(find.byKey(const Key('next-period-retry')), findsOneWidget);
      expect(find.byKey(const Key('goal-card-error')), findsOneWidget);
      expect(find.byKey(const Key('goal-card-retry')), findsOneWidget);
      expect(find.byKey(const Key('health-calendar-error')), findsOneWidget);
      expect(find.byKey(const Key('health-calendar-retry')), findsOneWidget);
      expect(find.byKey(const Key('care-today-summary-error')), findsOneWidget);
      expect(find.byKey(const Key('care-today-summary-retry')), findsOneWidget);
      expect(
        find.byKey(const Key('health-sign-in-again-button')),
        findsNothing,
      );
    });

    testWidgets('an undecodable section fails alone', (tester) async {
      final body = healthOverviewBody()
        ..['water'] = okSection({'day': '2026-08-20', 'total_ml': 'nope'});
      final rig = _buildRig(overviewBody: body);
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.water.status, WaterStatus.error);
      expect(rig.bowel.status, BowelStatus.loaded);
    });

    testWidgets('a 200 whose every section failed is still not a whole-screen '
        'error, and leaves the stamp alone', (tester) async {
      final rig = _buildRig(overviewBody: healthOverviewAllFailedBody());
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.weightGoal.status, WeightGoalStatus.error);
      expect(rig.trend.status, TrendStatus.error);
      expect(rig.calendar.status, HealthCalendarStatus.error);
      expect(rig.today.status, TodayStatus.error);
      expect(rig.water.status, WaterStatus.error);
      expect(rig.menstrual.status, MenstrualStatus.error);
      expect(rig.careToday.status, CareTodayLoadStatus.error);
      expect(rig.careAdherence.status, CareHistoryLoadStatus.error);
      expect(
        find.byKey(const Key('health-sign-in-again-button')),
        findsNothing,
      );
      // A 200 that fetched nothing is not a load: the "updated HH:mm" line
      // must not claim one.
      expect(find.textContaining('Updated'), findsNothing);
    });
  });

  group('request-level failures', () {
    testWidgets('a transport throw fails every card and leaves none loading', (
      tester,
    ) async {
      final rig = _buildRig(overviewThrows: const SocketFailure());
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.weightGoal.status, WeightGoalStatus.error);
      expect(rig.water.status, WaterStatus.error);
      expect(rig.bowel.status, BowelStatus.error);
      expect(rig.vitals.status, VitalsStatus.error);
      expect(rig.exercise.status, ExerciseStatus.error);
      expect(rig.today.status, TodayStatus.error);
      expect(rig.dailyTarget.status, DailyTargetStatus.error);
      expect(rig.dictionary.status, DictionaryStatus.error);
      expect(rig.trend.status, TrendStatus.error);
      expect(rig.calendar.status, HealthCalendarStatus.error);
      expect(rig.menstrual.status, MenstrualStatus.error);
      expect(rig.careToday.status, CareTodayLoadStatus.error);
      expect(rig.careAdherence.status, CareHistoryLoadStatus.error);
      expect(
        find.byKey(const Key('health-sign-in-again-button')),
        findsNothing,
      );
    });

    testWidgets('a 500 is not a re-authentication prompt', (tester) async {
      final rig = _buildRig(overviewStatus: 500);
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.weightGoal.status, WeightGoalStatus.error);
      expect(
        find.byKey(const Key('health-sign-in-again-button')),
        findsNothing,
      );
    });

    testWidgets('a 401 surfaces the re-authentication exit', (tester) async {
      final rig = _buildRig(overviewStatus: 401);
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.weightGoal.status, WeightGoalStatus.needsReauth);
      expect(rig.careToday.status, CareTodayLoadStatus.reauth);
      expect(
        find.byKey(const Key('health-sign-in-again-button')),
        findsOneWidget,
      );
    });
  });

  group('day and window parameters', () {
    // 07:00 at UTC+8 is the PREVIOUS day in UTC. A fixture where local and
    // UTC agree passes with the bug present, so this suite is run under both
    // `flutter test` and `TZ=UTC flutter test`.
    testWidgets('day is the local calendar day, not the UTC one', (
      tester,
    ) async {
      final rig = _buildRig(clock: () => DateTime(2026, 8, 20, 7));
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.log.requests.single.queryParameters['day'], '2026-08-20');
    });

    testWidgets('trend_days and care_days carry the two cards spans', (
      tester,
    ) async {
      final rig = _buildRig(trendSpanDays: 90, careSpanDays: 7);
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      final query = rig.log.requests.single.queryParameters;
      expect(query['trend_days'], '90');
      expect(query['care_days'], '7');
    });

    testWidgets('a custom care period ignores care_range and loads that one '
        'card granularly, applying the rest', (tester) async {
      final rig = _buildRig();
      rig.careAdherence.period = const CareHistoryPeriod.custom(
        '2026-08-01',
        '2026-08-10',
      );
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.log.paths, ['/api/health-overview', '/api/care/range']);
      expect(rig.log.requests.last.queryParameters['from'], '2026-08-01');
      expect(rig.water.status, WaterStatus.loaded);
      expect(rig.careAdherence.status, CareHistoryLoadStatus.loaded);
    });

    testWidgets('a calendar paged to another month is not overwritten by the '
        'section', (tester) async {
      final rig = _buildRig();
      await rig.calendar.loadMonth('token', 2026, 7);
      rig.log.requests.clear();

      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();

      expect(rig.calendar.selectedMonth, DateTime(2026, 7));
      expect(rig.calendar.calendar!.month, 7);
      // The batch still went out — thirteen other sections depend on it — and
      // this one card loaded its own month.
      expect(rig.log.paths.first, '/api/health-overview');
      expect(rig.log.paths, contains('/api/health-calendar'));
      expect(rig.water.status, WaterStatus.loaded);
    });

    testWidgets('a span switched while the request is in flight is not '
        'overwritten', (tester) async {
      final gate = Completer<void>();
      // The card's own 90-day request is parked too, so the moment the batch
      // response lands is observable on its own — with a zero-delay granular
      // fake the 90-day answer repairs the card before any assertion runs,
      // and the guard passes with the window check deleted (measured).
      final rangeGate = Completer<void>();
      final rig = _buildRig(
        trendSpanDays: 30,
        overviewGate: gate,
        vitalsRangeGate: rangeGate,
      );
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pump();

      expect(rig.log.requests.single.queryParameters['trend_days'], '30');
      // Switched mid-flight, through the card's own control — a granular
      // request for the 90-day window.
      final switched = rig.trend.setSpan('token', 90);
      gate.complete();
      await tester.pump();
      expect(
        rig.trend.range,
        isNull,
        reason: 'the 30-day section describes a window the card has left',
      );

      rangeGate.complete();
      await switched;
      await tester.pumpAndSettle();

      expect(rig.trend.spanDays, 90);
      final rangeCalls = rig.log.requests
          .where((u) => u.path == '/api/vitals/range')
          .toList();
      expect(rangeCalls, isNotEmpty);
      expect(
        rangeCalls.every((u) => u.queryParameters['from'] == '2026-05-23'),
        isTrue,
        reason: 'only the 90-day window the card switched to is requested',
      );
      // The rendered state, not just the requests: the 30-day series the
      // round asked for is `2026-07-22`, so a card holding that would be
      // showing a month of data under a 90-day label.
      expect(
        rig.trend.range!.from,
        DateTime(2026, 5, 23),
        reason: 'the 30-day series must not have been written',
      );
    });
  });

  group('narrower loads stay granular', () {
    testWidgets('a water write reloads through /api/water, not the batch', (
      tester,
    ) async {
      final rig = _buildRig();
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();
      rig.log.requests.clear();

      await rig.water.addWater('token', '2026-08-20', 250);

      expect(rig.log.paths, contains('/api/water'));
      expect(rig.log.paths, isNot(contains('/api/health-overview')));
    });

    testWidgets('a trend span switch requests /api/vitals/range only', (
      tester,
    ) async {
      final rig = _buildRig();
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();
      rig.log.requests.clear();

      await rig.trend.setSpan('token', 7);

      expect(rig.log.paths, ['/api/vitals/range']);
    });
  });

  group('repeat rounds', () {
    testWidgets('a DataRevision bump issues a second batch request with a '
        'freshly computed day', (tester) async {
      var now = DateTime(2026, 8, 20, 23, 30);
      final rig = _buildRig(clock: () => now);
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();
      expect(rig.log.requests.single.queryParameters['day'], '2026-08-20');

      now = DateTime(2026, 8, 21, 0, 30);
      rig.dataRevision.bump();
      await tester.pumpAndSettle();

      final overviewCalls = rig.log.requests
          .where((u) => u.path == '/api/health-overview')
          .toList();
      expect(overviewCalls.length, 2);
      expect(overviewCalls.last.queryParameters['day'], '2026-08-21');
    });

    // The outgoing request parameter alone (asserted above) does not prove a
    // controller actually ADOPTED the new day — a comparison against the day
    // already held would refuse this round outright (nothing navigated the
    // water tracker; it simply sat on yesterday's day since nobody reopened
    // it), leaving the controller stuck on yesterday's total under a header
    // that has already rolled over to today.
    testWidgets('the rollover round is actually applied, not just requested', (
      tester,
    ) async {
      var now = DateTime(2026, 8, 20, 23, 30);
      final body = healthOverviewBody(day: '2026-08-20');
      final rig = _buildRig(clock: () => now, overviewBody: body);
      await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
      await tester.pumpAndSettle();
      expect(rig.water.day!.day, '2026-08-20');
      expect(rig.water.day!.totalMl, 900);

      now = DateTime(2026, 8, 21, 0, 30);
      body['water'] = okSection(
        waterPayload('2026-08-21')..['total_ml'] = 1500,
      );
      rig.dataRevision.bump();
      await tester.pumpAndSettle();

      expect(rig.water.day!.day, '2026-08-21');
      expect(rig.water.day!.totalMl, 1500);
    });

    // The generation guard's whole reason to exist is that the claim is
    // taken BEFORE the batch request goes out — that ordering, not merely
    // "a claim happens somewhere before the apply", is what lets a
    // navigation that lands mid-round win over a round already in flight.
    // Moving the six `claimBatchRound()` calls to just after the response
    // (still before every apply) leaves every existing test green, because
    // they only ever exercise `claimBatchRound()` through the controllers
    // themselves. Driving it through the shell here is what pins the order.
    testWidgets(
      'a day navigation that lands while a round is already in flight is '
      'not overwritten when that round resolves',
      (tester) async {
        final gate = Completer<void>();
        final waterGate = Completer<void>();
        final rig = _buildRig(
          overviewGate: gate,
          gateFromRound: 2,
          waterGate: waterGate,
        );
        await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
        await tester.pumpAndSettle();
        expect(rig.water.day!.day, '2026-08-20');

        // Round two starts and is held at the gate before the claim can be
        // observed any other way.
        rig.dataRevision.bump();
        await tester.pump();

        // A granular navigation to a different day lands while the round is
        // still out. Its own request is held too, so the moment it resolves
        // is observable on its own.
        final navigated = rig.water.load('token', '2026-08-10');
        await tester.pump();
        waterGate.complete();
        await navigated;

        expect(
          rig.water.day!.day,
          '2026-08-10',
          reason:
              'the navigation landed after round two was already '
              'claimed, so its answer must win',
        );

        gate.complete();
        await tester.pumpAndSettle();

        expect(
          rig.water.day!.day,
          '2026-08-10',
          reason:
              'round two was claimed before the navigation happened, '
              'so its stale section for 2026-08-20 must be refused',
        );
      },
    );

    // No card runs its own `load()` during a round, so no controller status
    // reports the reload: without the scaffold handing the round down, a card
    // that failed the previous round keeps a pressable retry for the whole
    // (up to 15s) round and fires a redundant granular request for data
    // already on its way.
    //
    // One case per card on purpose. The overview has four cards, each wiring
    // `refreshing` into its own `StaleNotice` through its own local — a single
    // case failing one section leaves the other three cards' wiring free to be
    // deleted with the suite still green (measured: dropping
    // `|| widget.refreshing` from `goal_card`, `health_calendar_card` and
    // `care_today_summary_card` together left the full suite passing).
    //
    // `GoalCard` and `CareTodaySummaryCard` each render a `StaleNotice` twice
    // — once in their populated body, once in their unset/setup-prompt body —
    // but both sites read the *same* `reloading` local computed once per
    // build, so the populated body covered here is what makes that local
    // load-bearing. The unset bodies are not reachable from these fixtures
    // (the batch answers a set goal and a non-empty care day).
    for (final (name, section, card) in <(String, String, Type)>[
      ('weight goal', 'weight_goal', GoalCard),
      ('health calendar', 'health_calendar', HealthCalendarCard),
      ('care today', 'care_today', CareTodaySummaryCard),
      ('menstrual', 'menstrual', NextPeriodCard),
    ]) {
      testWidgets('a round in flight reaches the $name card\'s stale notice, '
          'which stops offering a retry while it is', (tester) async {
        final body = healthOverviewBody(
          day: '2026-08-20',
          calendarYear: 2026,
          calendarMonth: 8,
        );
        // Tall enough that the whole overview list is built: these assertions
        // are about what the four cards render, and a lazily-built ListView
        // leaves the ones below the fold out of the tree entirely.
        await tester.binding.setSurfaceSize(const Size(600, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gate = Completer<void>();
        final rig = _buildRig(
          overviewBody: body,
          overviewGate: gate,
          gateFromRound: 3,
        );
        await tester.pumpWidget(l10nRouterTestApp(home: rig.widget));
        await tester.pumpAndSettle();

        // Scoped to this card: the other three are healthy, and a healthy
        // card's notice renders nothing, so an unscoped finder would pass on
        // whichever card happens to still be wired.
        Finder within(Key key) =>
            find.descendant(of: find.byType(card), matching: find.byKey(key));
        final row = within(const Key('stale-notice-row'));
        final retry = within(const Key('stale-notice-retry'));

        // Round two fails this card's section, but the card keeps the content
        // it already drew — the state that appends the stale notice.
        body[section] = failedSection();
        rig.dataRevision.bump();
        await tester.pumpAndSettle();

        expect(row, findsOneWidget);
        expect(
          tester.widget<TextButton>(retry).onPressed,
          isNotNull,
          reason: 'with no round in flight the retry is the way back',
        );

        // Round three: in flight, held at the gate.
        rig.dataRevision.bump();
        await tester.pump();
        final requestsInFlight = rig.log.requests.length;

        expect(row, findsOneWidget);
        expect(
          tester.widget<TextButton>(retry).onPressed,
          isNull,
          reason: '$name: the round is fetching this card already',
        );
        // The whole row takes the tap, so it has to go dead too — not just
        // the button at its end.
        expect(tester.widget<InkWell>(row).onTap, isNull);
        // ...and it says why, rather than looking like an idle failed card.
        expect(
          find.descendant(
            of: retry,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(rig.log.requests.length, requestsInFlight);

        gate.complete();
        await tester.pumpAndSettle();
      });
    }
  });
}

class SocketFailure implements Exception {
  const SocketFailure();
}
