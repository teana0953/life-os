import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/body_profile/presentation/goal_card.dart';
import 'package:life_os/contexts/body_profile/presentation/weight_goal_controller.dart';
import 'package:life_os/contexts/bowel/application/get_bowel_day.dart';
import 'package:life_os/contexts/bowel/application/save_bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_controller.dart';
import 'package:life_os/contexts/exercise/application/add_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/delete_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/get_exercise_day.dart';
import 'package:life_os/contexts/exercise/application/list_exercise_activities.dart';
import 'package:life_os/contexts/exercise/domain/exercise_day.dart';
import 'package:life_os/contexts/exercise/domain/exercise_repository.dart';
import 'package:life_os/contexts/exercise/presentation/exercise_controller.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal_item.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/health_scaffold.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/health_calendar/application/get_health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_repository.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'package:life_os/contexts/hydration/application/add_water.dart';
import 'package:life_os/contexts/hydration/application/get_water_day.dart';
import 'package:life_os/contexts/hydration/application/set_water_target.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/hydration/presentation/water_controller.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/contexts/vitals/presentation/trend_controller.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => 'token-123';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeBodyProfileRepository implements BodyProfileRepository {
  @override
  Future<WeightGoal> getWeightGoal(String idToken) async => const WeightGoal();

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async => const BodyProfile();

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async => const BodyProfile();
}

class _FakeVitalsRepository implements VitalsRepository {
  @override
  Future<VitalsDay> getDay(String idToken, String day) async => VitalsDay(
    day: day,
    weightKg: null,
    bodyFatPct: null,
    bpReadings: const [],
    glucoseReadings: const [],
    spo2Readings: const [],
  );

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) async => day;

  @override
  Future<VitalsRange> getRange(String idToken, DateTime from, DateTime to) async =>
      VitalsRange(
        from: from,
        to: to,
        series: const VitalsSeries(
          weight: [],
          bodyFat: [],
          systolic: [],
          diastolic: [],
          pulse: [],
          glucose: [],
          spo2: [],
        ),
      );
}

class _FakeHealthCalendarRepository implements HealthCalendarRepository {
  @override
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) async => HealthCalendar(
    year: year,
    month: month,
    loggedDays: const {},
    daysElapsed: 0,
    loggingRate: null,
    dietAdherenceRate: null,
  );
}

class _FakeMealRepository implements MealRepository {
  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async => DayMealsLog(
    day: day,
    meals: const [],
    totals: const Portions(staple: 0, meat: 0, fruit: 0, veg: 0),
  );

  @override
  Future<MealEntry> createMeal(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  }) => throw UnimplementedError();

  @override
  Future<List<String>> loggedDays(String idToken, String month) async => const [];

  @override
  Future<void> patchMealItem(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteMealItem(String idToken, String id) => throw UnimplementedError();

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMeal(String idToken, String id) => throw UnimplementedError();
}

class _FakeDailyTargetRepository implements DailyTargetRepository {
  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async =>
      DailyTargetWithRemaining(
        day: day,
        base: const Portions(staple: 0, meat: 0, fruit: 0, veg: 0),
        bonus: const Portions(staple: 0, meat: 0, fruit: 0, veg: 0),
        effective: const Portions(staple: 0, meat: 0, fruit: 0, veg: 0),
        logged: const Portions(staple: 0, meat: 0, fruit: 0, veg: 0),
        remaining: const Portions(staple: 0, meat: 0, fruit: 0, veg: 0),
      );

  @override
  Future<DailyTarget> setTarget(
    String idToken, {
    required String day,
    required double baseStaple,
    required double baseMeat,
    required double baseFruit,
    required double baseVeg,
    double? bonusStaple,
    double? bonusMeat,
    double? bonusFruit,
    double? bonusVeg,
  }) => throw UnimplementedError();
}

class _FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  @override
  Future<List<FoodItem>> search(String idToken, String query) async => const [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => const [];

  @override
  Future<void> favorite(String idToken, String foodItemId) => throw UnimplementedError();

  @override
  Future<void> unfavorite(String idToken, String foodItemId) =>
      throw UnimplementedError();
}

class _FakeWaterRepository implements WaterRepository {
  @override
  Future<WaterDay> getDay(String idToken, String day) async =>
      WaterDay(day: day, totalMl: 0, targetMl: 0, remainingMl: 0);

  @override
  Future<int> addWater(String idToken, {required String day, required int addMl}) =>
      throw UnimplementedError();

  @override
  Future<int> setTarget(String idToken, {required String day, required int targetMl}) =>
      throw UnimplementedError();
}

class _FakeBowelRepository implements BowelRepository {
  @override
  Future<BowelDay> getDay(String idToken, String day) async =>
      BowelDay(day: day, count: 0, isNormal: null, note: '');

  @override
  Future<BowelDay> save(
    String idToken, {
    required String day,
    required int count,
    required bool? isNormal,
    required String note,
  }) => throw UnimplementedError();
}

class _FakeExerciseRepository implements ExerciseRepository {
  @override
  Future<List<ExerciseActivity>> listActivities(String idToken) async => const [];

  @override
  Future<ExerciseDay> getDay(String idToken, String day) async =>
      ExerciseDay(day: day, entries: const [], totalMinutes: 0);

  @override
  Future<ExerciseEntry> addEntry(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  }) => throw UnimplementedError();

  @override
  Future<bool> deleteEntry(String idToken, String entryId) => throw UnimplementedError();
}

class _FakeMenstrualRepository implements MenstrualRepository {
  @override
  Future<MenstrualOverview> getOverview(String idToken) async =>
      const MenstrualOverview(periods: [], stats: MenstrualStats());

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) => throw UnimplementedError();

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) => throw UnimplementedError();

  @override
  Future<bool> deletePeriod(String idToken, String id) => throw UnimplementedError();
}

class _FakeCareTodayRepository implements CareTodayRepository {
  final CareToday today;

  _FakeCareTodayRepository({required this.today});

  @override
  Future<CareToday> getToday(String idToken) async => today;

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) => throw UnimplementedError();
}

/// Builds a fully-wired [HealthScaffold] with every controller backed by a
/// minimal fake repository that succeeds without throwing — a smoke rig for
/// asserting what the Overview tab renders first. [careTodaySlots] is the
/// only input that varies between tests.
Widget _buildScaffold({required List<CareTodaySlot> careTodaySlots}) {
  final bodyProfileRepository = _FakeBodyProfileRepository();
  final weightGoalController = WeightGoalController(
    GetWeightGoal(bodyProfileRepository),
    GetBodyProfile(bodyProfileRepository),
    SetBodyProfile(bodyProfileRepository),
  );
  final vitalsRepository = _FakeVitalsRepository();
  final trendController = TrendController(GetVitalsTrends(vitalsRepository));
  final vitalsController = VitalsController(
    GetVitalsDay(vitalsRepository),
    SaveVitalsDay(vitalsRepository),
  );
  final healthCalendarController = HealthCalendarController(
    GetHealthCalendar(_FakeHealthCalendarRepository()),
  );
  final mealRepository = _FakeMealRepository();
  final dailyTargetRepository = _FakeDailyTargetRepository();
  final todayController = TodayController(
    GetDayMeals(mealRepository),
    GetDailyTargetWithRemaining(dailyTargetRepository),
    EditMealItem(mealRepository),
    DeleteMealItem(mealRepository),
    ChangeMealTime(mealRepository),
    DeleteMeal(mealRepository),
  );
  final dictionaryRepository = _FakeFoodDictionaryRepository();
  final dictionaryController = DictionaryController(
    SearchDictionary(dictionaryRepository),
    ListFavorites(dictionaryRepository),
    FavoriteFood(dictionaryRepository),
    UnfavoriteFood(dictionaryRepository),
  );
  final dailyTargetController = DailyTargetController(
    GetDailyTargetWithRemaining(dailyTargetRepository),
    SetDailyTarget(dailyTargetRepository),
  );
  final createMealController = CreateMealController(CreateMeal(mealRepository));
  final getLoggedDays = GetLoggedDays(mealRepository);
  final waterController = WaterController(
    GetWaterDay(_FakeWaterRepository()),
    AddWater(_FakeWaterRepository()),
    SetWaterTarget(_FakeWaterRepository()),
  );
  final bowelController = BowelController(
    GetBowelDay(_FakeBowelRepository()),
    SaveBowelDay(_FakeBowelRepository()),
  );
  final exerciseRepository = _FakeExerciseRepository();
  final exerciseController = ExerciseController(
    ListExerciseActivities(exerciseRepository),
    GetExerciseDay(exerciseRepository),
    AddExerciseEntry(exerciseRepository),
    DeleteExerciseEntry(exerciseRepository),
  );
  final menstrualRepository = _FakeMenstrualRepository();
  final menstrualController = MenstrualController(
    GetMenstrualOverview(menstrualRepository),
    AddPeriod(menstrualRepository),
    UpdatePeriod(menstrualRepository),
    DeletePeriod(menstrualRepository),
  );
  final careTodayRepository = _FakeCareTodayRepository(
    today: CareToday(date: '2026-07-24', slots: careTodaySlots),
  );
  final careTodayController = CareTodayController(
    GetCareToday(careTodayRepository),
    MarkCareDone(careTodayRepository),
    MarkCareSkipped(careTodayRepository),
  );
  final authRepository = _FakeAuthRepository();

  return HealthScaffold(
    authRepository: authRepository,
    signOut: SignOut(authRepository),
    weightGoalController: weightGoalController,
    trendController: trendController,
    healthCalendarController: healthCalendarController,
    todayController: todayController,
    dictionaryController: dictionaryController,
    dailyTargetController: dailyTargetController,
    createMealController: createMealController,
    getLoggedDays: getLoggedDays,
    waterController: waterController,
    bowelController: bowelController,
    vitalsController: vitalsController,
    exerciseController: exerciseController,
    menstrualController: menstrualController,
    careTodayController: careTodayController,
    onOpenSettings: () {},
    onOpenImport: () {},
    onOpenReminders: () {},
    onOpenCareItems: () {},
    onOpenCareToday: () {},
    clock: () => DateTime(2026, 7, 24),
  );
}

CareTodaySlot _slot({
  String careScheduleId = 'sch-1',
  CareTodayStatus status = CareTodayStatus.overdue,
}) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: careScheduleId,
  category: CareCategory.medication,
  title: 'Metformin',
  note: null,
  dose: '500mg',
  timeOfDay: '08:00',
  localDate: '2026-07-24',
  status: status,
  doseQuantity: 1,
);

void main() {
  group('HealthScaffold overview ordering', () {
    testWidgets('has-schedule: the care-today summary card is the first '
        'overview card, above the goal card', (tester) async {
      await tester.pumpWidget(
        l10nRouterTestApp(home: _buildScaffold(careTodaySlots: [_slot()])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
      expect(find.byType(GoalCard), findsOneWidget);
      final summaryTop = tester.getTopLeft(
        find.byKey(const Key('care-today-summary-card')),
      );
      final goalTop = tester.getTopLeft(find.byType(GoalCard));
      expect(summaryTop.dy, lessThan(goalTop.dy));
    });

    testWidgets('no-schedule: the setup CTA is the first overview card '
        '(the goal card follows it) and no summary card is shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nRouterTestApp(home: _buildScaffold(careTodaySlots: const [])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-today-summary-card')), findsNothing);
      expect(find.byKey(const Key('care-today-summary-setup')), findsOneWidget);
      expect(find.byType(GoalCard), findsOneWidget);
      final setupTop = tester.getTopLeft(
        find.byKey(const Key('care-today-summary-setup')),
      );
      final goalTop = tester.getTopLeft(find.byType(GoalCard));
      expect(setupTop.dy, lessThan(goalTop.dy));
    });
  });
}
