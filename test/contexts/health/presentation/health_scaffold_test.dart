import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_exceptions.dart';
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
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';
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
import 'package:life_os/contexts/health_calendar/domain/health_calendar_exceptions.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_card.dart';
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
import 'package:life_os/contexts/menstrual/domain/menstrual_exceptions.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';
import 'package:life_os/contexts/menstrual/presentation/next_period_card.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/application/get_care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_adherence_card.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_summary_card.dart';
import 'package:life_os/contexts/notifications/presentation/push_health_controller.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_exceptions.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/contexts/vitals/presentation/trend_card.dart';
import 'package:life_os/contexts/vitals/presentation/trend_controller.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/data_revision.dart';
import 'package:life_os/shared/widgets/last_loaded_label.dart';
import 'package:life_os/shared/widgets/stale_notice.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/push_health.dart';

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

/// An [AuthRepository] whose token can be changed mid-test, standing in for
/// Firebase renewing it while the scaffold stays mounted.
class _RotatingAuthRepository implements AuthRepository {
  String token;

  _RotatingAuthRepository({this.token = 'token-1'});

  @override
  Future<String?> idToken() async => token;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

/// An [AuthRepository] whose [idToken] throws the next time it's called once
/// [arm]ed, then goes back to succeeding — lets a test make `_load`'s token
/// fetch (the one call inside it that can throw) fail on a specific reload
/// without depending on how many token fetches happen before it (e.g. if
/// `_load` ever grows another one).
class _ThrowingAuthRepository implements AuthRepository {
  bool _armed = false;

  /// Arms the next [idToken] call to throw.
  void arm() => _armed = true;

  @override
  Future<String?> idToken() async {
    if (_armed) {
      _armed = false;
      throw Exception('token fetch failed');
    }
    return 'token-123';
  }

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

/// [calls] counts every goal fetch; once [errorAfterFirstLoad] is set, every
/// call *after* the first throws it — lets a test drive the goal card's own
/// reload to a failure without failing the scaffold's initial load.
class _FakeBodyProfileRepository implements BodyProfileRepository {
  int calls = 0;
  Object? errorAfterFirstLoad;
  WeightGoal goal = const WeightGoal();

  /// When set, the call waits on this before completing — lets a test hold a
  /// retry in flight and look at the card while it runs.
  Completer<void>? gate;

  /// Every id token [getWeightGoal] was called with, in order — the *value
  /// that was sent*, which is what the token-freshness test asserts on.
  final List<String> goalTokens = [];

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    goalTokens.add(idToken);
    calls++;
    if (calls > 1 && errorAfterFirstLoad != null) throw errorAfterFirstLoad!;
    if (gate != null) await gate!.future;
    return goal;
  }

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
  int rangeCalls = 0;

  /// Once set, every `getRange` call *after* the first (the scaffold's initial
  /// load) throws it — lets a test drive the trend controller (an overview/
  /// trend controller) to error on a reload without failing the initial load.
  Object? errorAfterFirstLoad;

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
  Future<VitalsRange> getRange(String idToken, DateTime from, DateTime to) async {
    rangeCalls++;
    if (rangeCalls > 1 && errorAfterFirstLoad != null) throw errorAfterFirstLoad!;
    return VitalsRange(
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
}

/// A fake whose [calls] count every invocation, and which optionally awaits
/// [gate] before returning — lets a test hold a reload in flight to exercise
/// [HealthScaffold]'s bump-coalescing.
class _FakeHealthCalendarRepository implements HealthCalendarRepository {
  int calls = 0;
  Completer<void>? gate;

  /// Once set, every call *after* the first throws it — lets a test drive the
  /// calendar card's reload to a failure without failing the initial load.
  Object? errorAfterFirstLoad;

  @override
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) async {
    calls++;
    if (calls > 1 && errorAfterFirstLoad != null) throw errorAfterFirstLoad!;
    if (gate != null) await gate!.future;
    return HealthCalendar(
      year: year,
      month: month,
      loggedDays: const {},
      daysElapsed: 0,
      loggingRate: null,
      dietAdherenceRate: null,
    );
  }
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

  @override
  Future<FoodItem> createSharedItem(String idToken, SharedFoodItemInput input) =>
      throw UnimplementedError();

  @override
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  ) => throw UnimplementedError();
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
  /// Thrown instead of returning an overview, for the 401 test.
  final Object? getOverviewError;

  int calls = 0;

  /// Once set, every call *after* the first throws it — lets a test drive the
  /// next-period card's reload to a failure without failing the initial load.
  Object? errorAfterFirstLoad;

  /// When set, the call waits on this before completing — lets a test hold a
  /// retry in flight and look at the card while it runs.
  Completer<void>? gate;

  _FakeMenstrualRepository({this.getOverviewError});

  @override
  Future<MenstrualOverview> getOverview(String idToken) async {
    calls++;
    if (getOverviewError != null) throw getOverviewError!;
    if (calls > 1 && errorAfterFirstLoad != null) throw errorAfterFirstLoad!;
    if (gate != null) await gate!.future;
    return const MenstrualOverview(periods: [], stats: MenstrualStats());
  }

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

  /// When set, `getToday` throws this instead of returning [today] — lets a
  /// test drive [CareTodayController.status] to `error`/`reauth` via the
  /// initial load.
  Object? getError;

  /// When set, `logSlot` (marking a dose done/skipped) throws this instead
  /// of succeeding — lets a test drive [CareTodayController.status] to
  /// `error`/`reauth` via the mark path instead of the initial load.
  Object? logError;

  int calls = 0;

  /// Once set, every call *after* the first throws it — lets a test drive the
  /// care card's reload to a failure without failing the initial load.
  Object? errorAfterFirstLoad;

  /// When set, the call waits on this before completing — lets a test hold a
  /// retry in flight and look at the card while it runs.
  Completer<void>? gate;

  _FakeCareTodayRepository({required this.today});

  @override
  Future<CareToday> getToday(String idToken) async {
    calls++;
    if (getError != null) throw getError!;
    if (calls > 1 && errorAfterFirstLoad != null) throw errorAfterFirstLoad!;
    if (gate != null) await gate!.future;
    return today;
  }

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {
    if (logError != null) throw logError!;
  }
}

/// Backs the trend tab's [CareAdherenceCard] controller. [days] is returned
/// on every `getRange` while [errorAfterFirstLoad] is unset; once set, every
/// call *after* the first (the scaffold's own initial load) throws it
/// instead — lets a test make a card-driven reload (a period switch) 401
/// without the initial `HealthScaffold._load()` itself failing.
class _FakeCareHistoryRepository implements CareHistoryRepository {
  final List<CareHistoryDay> days;
  Object? errorAfterFirstLoad;
  int calls = 0;

  _FakeCareHistoryRepository({this.days = const []});

  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async {
    calls++;
    if (calls > 1 && errorAfterFirstLoad != null) throw errorAfterFirstLoad!;
    return days;
  }

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
    DateTime? doneTime,
  }) async {}
}

/// Builds a fully-wired [HealthScaffold] with every controller backed by a
/// minimal fake repository that succeeds without throwing — a smoke rig for
/// asserting what the Overview tab renders first. [careTodaySlots] is the
/// only input that varies between most tests; it's ignored when
/// [careTodayRepository] is supplied directly. [healthCalendarRepository],
/// [careTodayRepository], [careHistoryRepository], [menstrualRepository],
/// [bodyProfileRepository], [authRepository], and
/// [dataRevision] are overridable for the reload-on-bump/reauth/load-failure
/// tests, which need to observe/control the respective load calls and drive
/// the shared revision.
Widget _buildScaffold({
  List<CareTodaySlot> careTodaySlots = const [],
  _FakeHealthCalendarRepository? healthCalendarRepository,
  _FakeCareTodayRepository? careTodayRepository,
  _FakeCareHistoryRepository? careHistoryRepository,
  _FakeMenstrualRepository? menstrualRepository,
  _FakeBodyProfileRepository? bodyProfileRepository,
  _FakeVitalsRepository? vitalsRepository,
  AuthRepository? authRepository,
  DataRevision? dataRevision,
  VoidCallback? onOpenCareHistory,
  VoidCallback? onOpenCareItems,
  PushHealthController? pushHealthController,
  DateTime Function()? clock,
}) {
  final resolvedBodyProfileRepository =
      bodyProfileRepository ?? _FakeBodyProfileRepository();
  final weightGoalController = WeightGoalController(
    GetWeightGoal(resolvedBodyProfileRepository),
    GetBodyProfile(resolvedBodyProfileRepository),
    SetBodyProfile(resolvedBodyProfileRepository),
  );
  final resolvedVitalsRepository = vitalsRepository ?? _FakeVitalsRepository();
  final trendController = TrendController(
    GetVitalsTrends(resolvedVitalsRepository),
  );
  final vitalsController = VitalsController(
    GetVitalsDay(resolvedVitalsRepository),
    SaveVitalsDay(resolvedVitalsRepository),
  );
  final healthCalendarController = HealthCalendarController(
    GetHealthCalendar(healthCalendarRepository ?? _FakeHealthCalendarRepository()),
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
    idToken: () async => 'token',
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
  final resolvedMenstrualRepository =
      menstrualRepository ?? _FakeMenstrualRepository();
  final menstrualController = MenstrualController(
    GetMenstrualOverview(resolvedMenstrualRepository),
    AddPeriod(resolvedMenstrualRepository),
    UpdatePeriod(resolvedMenstrualRepository),
    DeletePeriod(resolvedMenstrualRepository),
  );
  final resolvedCareTodayRepository =
      careTodayRepository ??
      _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-24', slots: careTodaySlots),
      );
  final careTodayController = CareTodayController(
    GetCareToday(resolvedCareTodayRepository),
    MarkCareDone(resolvedCareTodayRepository),
    MarkCareSkipped(resolvedCareTodayRepository),
    EditCareSlot(_FakeCareHistoryRepository()),
  );
  final resolvedAuthRepository = authRepository ?? _FakeAuthRepository();
  // Resolved once so the widget's own `dataRevision` and the care adherence
  // controller's injected one are the same instance (mirrors main.dart's
  // wiring — design §D) — otherwise a caller-supplied [dataRevision] would
  // only reach the scaffold, never the card's controller.
  final resolvedDataRevision = dataRevision ?? DataRevision();
  final resolvedCareHistoryRepository =
      careHistoryRepository ?? _FakeCareHistoryRepository();
  final careAdherenceController = CareHistoryController(
    GetCareHistory(resolvedCareHistoryRepository),
    EditCareSlot(resolvedCareHistoryRepository),
    resolvedDataRevision,
    spanDays: 30,
  );

  return HealthScaffold(
    pushHealthController:
        pushHealthController ?? testPushHealthController(PushHealth.ok),
    authRepository: resolvedAuthRepository,
    signOut: SignOut(resolvedAuthRepository),
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
    careAdherenceController: careAdherenceController,
    onOpenSettings: () {},
    onOpenImport: () {},
    onOpenReminders: () {},
    onOpenCareItems: onOpenCareItems ?? () {},
    onOpenCareToday: () {},
    onOpenCareHistory: onOpenCareHistory ?? () {},
    dataRevision: resolvedDataRevision,
    clock: clock ?? () => DateTime(2026, 7, 24),
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

    testWidgets('the next-period card sits between the goal card and the '
        'record calendar — the whole point of it is being visible without '
        'scrolling past a full month grid', (tester) async {
      // A taller surface than the default test viewport: the care and goal
      // cards alone push the calendar card (and now the next-period card)
      // out of the default 800x600 viewport, where the ListView's sliver
      // viewport makes them offstage and so invisible to the finders below.
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(l10nRouterTestApp(home: _buildScaffold()));
      await tester.pumpAndSettle();

      expect(find.byType(NextPeriodCard), findsOneWidget);
      final goalTop = tester.getTopLeft(find.byType(GoalCard)).dy;
      final nextPeriodTop = tester.getTopLeft(find.byType(NextPeriodCard)).dy;
      final calendarTop = tester.getTopLeft(find.byType(HealthCalendarCard)).dy;
      expect(goalTop, lessThan(nextPeriodTop));
      expect(nextPeriodTop, lessThan(calendarTop));
    });

    testWidgets('tapping the next-period card opens the menstrual tracker', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(l10nRouterTestApp(home: _buildScaffold()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('next-period-card')));
      await tester.pumpAndSettle();

      // `l10nRouterTestApp` renders the matched location for a pushed route
      // it has no widget for, so this asserts the *path* — `/menstrual`
      // would be a not-found screen in the real router (app_test covers the
      // real route end to end).
      expect(find.text('/health/menstrual'), findsOneWidget);
    });
  });

  group('HealthScaffold trend tab cards', () {
    testWidgets(
      'the trends tab shows the vitals trend card and the care adherence '
      'card, with the care card after the vitals card',
      (tester) async {
        // A taller surface than the default test viewport: the vitals trend
        // card alone is tall enough to push the care adherence card below
        // the default viewport, which would make it "offstage" per the
        // ListView's sliver viewport and so invisible to the default
        // (skipOffstage: true) finders below.
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(l10nRouterTestApp(home: _buildScaffold()));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();

        expect(find.byType(TrendCard), findsOneWidget);
        expect(find.byType(CareAdherenceCard), findsOneWidget);
        final trendTop = tester.getTopLeft(find.byType(TrendCard)).dy;
        final careTop = tester.getTopLeft(find.byType(CareAdherenceCard)).dy;
        expect(trendTop, lessThan(careTop));
      },
    );

    testWidgets(
      'the care adherence card\'s "view records" entry is wired to the '
      'scaffold\'s care-history callback — the card is where a user sees '
      'the missed days they want to go correct',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var opened = 0;
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(onOpenCareHistory: () => opened++),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('care-adherence-open-history')));
        await tester.pumpAndSettle();

        expect(opened, 1);
      },
    );

    // The card-level test proves the empty state uses a callback distinct
    // from onOpenHistory; only this one proves the scaffold feeds it the
    // RIGHT one. Wiring it to onOpenCareHistory would send a user with no
    // care items to an empty record list — the dead end the scenario exists
    // to prevent — and every card-level test would still pass.
    testWidgets(
      "the empty card's manage entry goes to care management, not to the "
      'record list',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var manage = 0;
        var history = 0;
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              onOpenCareItems: () => manage++,
              onOpenCareHistory: () => history++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('care-adherence-empty-manage-button')),
        );
        await tester.pumpAndSettle();

        expect(manage, 1);
        expect(history, 0);
      },
    );
  });

  group('HealthScaffold data revision reload', () {
    testWidgets(
      'reloads once when the data revision bumps, but not on an unrelated '
      'rebuild',
      (tester) async {
        final calendarRepository = _FakeHealthCalendarRepository();
        final dataRevision = DataRevision();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              healthCalendarRepository: calendarRepository,
              dataRevision: dataRevision,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calendarRepository.calls, 1);

        // Switching tabs rebuilds the scaffold but must not reload.
        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();
        expect(calendarRepository.calls, 1);

        dataRevision.bump();
        await tester.pumpAndSettle();
        expect(calendarRepository.calls, 2);
      },
    );

    testWidgets(
      'a bump arriving while a load is in flight is coalesced into exactly '
      'one extra load afterwards (not dropped, not doubled)',
      (tester) async {
        final calendarRepository = _FakeHealthCalendarRepository();
        final dataRevision = DataRevision();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              healthCalendarRepository: calendarRepository,
              dataRevision: dataRevision,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calendarRepository.calls, 1);

        // Gate the next load(s) so a reload started by a bump stays in
        // flight while further bumps arrive.
        final gate = Completer<void>();
        calendarRepository.gate = gate;

        dataRevision.bump();
        await tester.pump();
        expect(calendarRepository.calls, 2);

        // Two more bumps while the reload above is still in flight must
        // coalesce into a single extra reload, not one per bump and not
        // none.
        dataRevision.bump();
        dataRevision.bump();
        await tester.pump();
        expect(calendarRepository.calls, 2);

        gate.complete();
        await tester.pumpAndSettle();
        expect(calendarRepository.calls, 3);
      },
    );
  });

  group('HealthScaffold overview reauth', () {
    testWidgets(
      'marking a dose done that 401s surfaces the same re-authenticate exit '
      'as the other overview controllers — the initial getToday load '
      'succeeds (so the card renders with an actionable slot), only the '
      'mark itself 401s, and the scaffold picks that up solely because '
      'careTodayController is in _overviewControllers',
      (tester) async {
        final careTodayRepository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-24', slots: [_slot()]),
        )..logError = const CareReauthRequired();

        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(careTodayRepository: careTodayRepository),
          ),
        );
        await tester.pumpAndSettle();

        // The load succeeded: the card rendered its Done control, and the
        // re-authenticate exit hasn't appeared yet.
        expect(
          find.byKey(const Key('care-today-summary-done')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('health-sign-in-again-button')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('care-today-summary-done')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('health-sign-in-again-button')),
          findsOneWidget,
        );
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      },
    );

    testWidgets(
      'switching the care adherence card\'s period that 401s surfaces the '
      'same re-authenticate exit as the other overview controllers — the '
      'initial load succeeds (so the card renders its heatmap), only the '
      'period switch itself 401s, and the scaffold picks that up solely '
      'because careAdherenceController is in _overviewControllers',
      (tester) async {
        // See the ordering test above: the vitals trend card pushes the
        // care adherence card's range selector below the default test
        // viewport, which would make it offstage (and so untappable via the
        // default finders) without a taller surface.
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final careHistoryRepository = _FakeCareHistoryRepository(
          days: [
            CareHistoryDay(
              date: '2026-07-24',
              slots: [_slot(status: CareTodayStatus.done)],
            ),
          ],
        )..errorAfterFirstLoad = const CareReauthRequired();

        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(careHistoryRepository: careHistoryRepository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();

        // The initial load succeeded: the card rendered its heatmap (not
        // just the header), and the re-authenticate exit hasn't appeared yet.
        expect(
          find.byKey(const Key('care-adherence-range-selector')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('care-adherence-heatmap')), findsOneWidget);
        expect(
          find.byKey(const Key('health-sign-in-again-button')),
          findsNothing,
        );

        final loc = lookupAppLocalizations(const Locale('en'));
        // Scoped to the card: the vitals trend card has its own "7 days"
        // segment too (a separate SegmentedButton), so an unscoped text
        // finder would match both.
        await tester.tap(
          find.descendant(
            of: find.byType(CareAdherenceCard),
            matching: find.text(loc.trendRange7),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('health-sign-in-again-button')),
          findsOneWidget,
        );
        expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      },
    );

    testWidgets(
      'a 401 from the menstrual load alone surfaces the re-authenticate exit '
      '— the next-period card has nothing to act on, so without menstrual in '
      '_overviewNeedsReauth its 401 would be a dead end',
      (tester) async {
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              menstrualRepository: _FakeMenstrualRepository(
                getOverviewError: const MenstrualReauthenticationRequired(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('health-sign-in-again-button')),
          findsOneWidget,
        );
      },
    );
  });

  group('HealthScaffold load failure recovery', () {
    testWidgets(
      'a failed token renewal no longer aborts the load — it proceeds '
      'unauthenticated, and later revision bumps keep working',
      (tester) async {
        final calendarRepository = _FakeHealthCalendarRepository();
        final dataRevision = DataRevision();
        final authRepository = _ThrowingAuthRepository();

        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              healthCalendarRepository: calendarRepository,
              dataRevision: dataRevision,
              authRepository: authRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calendarRepository.calls, 1);

        // Arm the token fetch to throw on its next call, then bump. This used
        // to abort the whole reload before any controller's `load` ran (the
        // token fetch was the one call in `_load` that could throw). Since
        // `guardedIdToken`, a failed renewal resolves to `''` instead: the
        // load proceeds and the request goes out unauthenticated, so the
        // backend's 401 drives the existing re-auth exit rather than the
        // refresh silently doing nothing.
        authRepository.arm();
        dataRevision.bump();
        await tester.pumpAndSettle();
        expect(
          calendarRepository.calls,
          2,
          reason: 'the renewal failure must not swallow the reload',
        );

        // And `_loading` is still released, so later bumps keep working.
        dataRevision.bump();
        await tester.pumpAndSettle();
        expect(
          calendarRepository.calls,
          3,
          reason: '_loading must not stay stuck after the renewal failure',
        );
      },
    );
  });

  group('HealthScaffold overview refresh failures', () {
    /// The four overview cards, each identified by the finder that resolves to
    /// the whole card (so a height/inset measurement covers all of it).
    Map<String, Finder> cardFinders() => {
      'care': find.byKey(const Key('care-today-summary-card')),
      'goal': find.byType(GoalCard),
      'nextPeriod': find.byType(NextPeriodCard),
      'calendar': find.byType(HealthCalendarCard),
    };

    testWidgets(
      'retrying one card reloads only that card — each card has its own '
      'source, so one failing says nothing about the others',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Every card in turn, not just the goal card: "only mine reloaded" is
        // a claim about the other three, and a single-card widget test cannot
        // make it (it holds one controller, so its own call count is trivially
        // 1). Only this rig has all four wired to separate counting fakes.
        for (final target in cardFinders().keys) {
          final bodyProfileRepository = _FakeBodyProfileRepository();
          final calendarRepository = _FakeHealthCalendarRepository();
          final menstrualRepository = _FakeMenstrualRepository();
          final careTodayRepository = _FakeCareTodayRepository(
            today: CareToday(date: '2026-07-24', slots: [_slot()]),
          );
          switch (target) {
            case 'care':
              careTodayRepository.errorAfterFirstLoad = const CareRequestFailed();
            case 'goal':
              bodyProfileRepository.errorAfterFirstLoad =
                  const BodyProfileFetchFailure();
            case 'nextPeriod':
              menstrualRepository.errorAfterFirstLoad =
                  const MenstrualFetchFailure();
            case 'calendar':
              calendarRepository.errorAfterFirstLoad =
                  const HealthCalendarFetchFailure();
          }
          final dataRevision = DataRevision();
          await tester.pumpWidget(
            l10nRouterTestApp(
              home: _buildScaffold(
                bodyProfileRepository: bodyProfileRepository,
                healthCalendarRepository: calendarRepository,
                menstrualRepository: menstrualRepository,
                careTodayRepository: careTodayRepository,
                dataRevision: dataRevision,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // One automatic reload of the whole overview: only this card's
          // source fails.
          dataRevision.bump();
          await tester.pumpAndSettle();
          final card = cardFinders()[target]!;
          expect(
            find.descendant(of: card, matching: find.byType(StaleNotice)),
            findsOneWidget,
            reason: '$target was not marked as unrefreshed',
          );

          Map<String, int> callCounts() => {
            'care': careTodayRepository.calls,
            'goal': bodyProfileRepository.calls,
            'nextPeriod': menstrualRepository.calls,
            'calendar': calendarRepository.calls,
          };
          final before = callCounts();

          await tester.tap(
            find.descendant(
              of: card,
              matching: find.byKey(const Key('stale-notice-retry')),
            ),
          );
          await tester.pumpAndSettle();

          final after = callCounts();
          for (final name in before.keys) {
            // Re-running the whole batch here would fire three requests nobody
            // asked for — a single card-level retry is the point of the
            // marking.
            expect(
              after[name],
              name == target ? before[name]! + 1 : before[name],
              reason: name == target
                  ? 'retrying $target did not reload $target'
                  : 'retrying $target also reloaded $name',
            );
          }
        }
      },
    );

    testWidgets(
      'the marking costs every card the same single extra row — the overview '
      'does not collapse, and the four cards do not each grow differently',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final bodyProfileRepository = _FakeBodyProfileRepository()
          ..goal = const WeightGoal(
            heightCm: 165,
            targetWeightKg: 51,
            currentWeightKg: 52,
            remainingKg: 1,
            achievementRate: 75,
            bmi: 19.1,
          );
        final calendarRepository = _FakeHealthCalendarRepository();
        final menstrualRepository = _FakeMenstrualRepository();
        final careTodayRepository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-24', slots: [_slot()]),
        );
        final dataRevision = DataRevision();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              bodyProfileRepository: bodyProfileRepository,
              healthCalendarRepository: calendarRepository,
              menstrualRepository: menstrualRepository,
              careTodayRepository: careTodayRepository,
              dataRevision: dataRevision,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = {
          for (final entry in cardFinders().entries)
            entry.key: tester.getSize(entry.value).height,
        };

        // Every card's next reload fails at once (the airplane-mode case).
        bodyProfileRepository.errorAfterFirstLoad =
            const BodyProfileFetchFailure();
        calendarRepository.errorAfterFirstLoad =
            const HealthCalendarFetchFailure();
        menstrualRepository.errorAfterFirstLoad = const MenstrualFetchFailure();
        careTodayRepository.errorAfterFirstLoad = const CareRequestFailed();
        dataRevision.bump();
        await tester.pumpAndSettle();

        expect(find.byType(StaleNotice), findsNWidgets(4));
        final deltas = <String, double>{
          for (final entry in cardFinders().entries)
            entry.key: tester.getSize(entry.value).height - before[entry.key]!,
        };
        // Every card grew (nothing was replaced by a shorter error card) and
        // grew by exactly the same one row.
        for (final entry in deltas.entries) {
          expect(
            entry.value,
            greaterThan(0),
            reason: '${entry.key} did not keep its content',
          );
          // One row, not a second card's worth of chrome.
          expect(
            entry.value,
            lessThan(80),
            reason: '${entry.key} grew by more than a single row',
          );
          expect(
            entry.value,
            deltas['goal'],
            reason: '${entry.key} grew by a different amount than the goal card',
          );
        }

        // And the marking is indented identically on all four — the calendar
        // card's own padding used to live on its LedgeCard, which would have
        // indented its marking twice.
        //
        // Both edges, separately: the retry button is the last thing in the
        // marking's row, so where it starts moves with the *right* inset and
        // stays put when only the left one changes. The leading icon is the
        // other end of the same row.
        final leftInsets = <String, double>{
          for (final entry in cardFinders().entries)
            entry.key:
                tester
                    .getTopLeft(
                      find.descendant(
                        of: entry.value,
                        matching: find.byIcon(Icons.cloud_off_outlined),
                      ),
                    )
                    .dx -
                tester.getTopLeft(entry.value).dx,
        };
        for (final entry in leftInsets.entries) {
          expect(
            entry.value,
            leftInsets['goal'],
            reason: '${entry.key} starts its marking at a different inset',
          );
        }

        final insets = <String, double>{
          for (final entry in cardFinders().entries)
            entry.key:
                tester
                    .getTopLeft(
                      find.descendant(
                        of: entry.value,
                        matching: find.byKey(const Key('stale-notice-retry')),
                      ),
                    )
                    .dx -
                tester.getTopLeft(entry.value).dx,
        };
        for (final entry in insets.entries) {
          expect(
            entry.value,
            insets['goal'],
            reason: '${entry.key} indents its marking differently',
          );
        }
      },
    );

    testWidgets(
      'the retry a user pressed keeps that card marked while it runs — a '
      'marking that disappears on the tap says "refreshed" about a request '
      'still in the air',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final loc = lookupAppLocalizations(const Locale('en'));

        // Every card in turn: each one wires the marking up to its own
        // controller's status, so "the row survives its own retry" has to be
        // proven four times, not once.
        for (final target in cardFinders().keys) {
          final bodyProfileRepository = _FakeBodyProfileRepository();
          final calendarRepository = _FakeHealthCalendarRepository();
          final menstrualRepository = _FakeMenstrualRepository();
          final careTodayRepository = _FakeCareTodayRepository(
            today: CareToday(date: '2026-07-24', slots: [_slot()]),
          );
          switch (target) {
            case 'care':
              careTodayRepository.errorAfterFirstLoad = const CareRequestFailed();
            case 'goal':
              bodyProfileRepository.errorAfterFirstLoad =
                  const BodyProfileFetchFailure();
            case 'nextPeriod':
              menstrualRepository.errorAfterFirstLoad =
                  const MenstrualFetchFailure();
            case 'calendar':
              calendarRepository.errorAfterFirstLoad =
                  const HealthCalendarFetchFailure();
          }
          final dataRevision = DataRevision();
          await tester.pumpWidget(
            l10nRouterTestApp(
              home: _buildScaffold(
                bodyProfileRepository: bodyProfileRepository,
                healthCalendarRepository: calendarRepository,
                menstrualRepository: menstrualRepository,
                careTodayRepository: careTodayRepository,
                dataRevision: dataRevision,
              ),
            ),
          );
          await tester.pumpAndSettle();
          dataRevision.bump();
          await tester.pumpAndSettle();
          final card = cardFinders()[target]!;

          // Arm a retry that succeeds but hangs, so the test can look at the
          // card during the round trip rather than after it.
          final gate = Completer<void>();
          switch (target) {
            case 'care':
              careTodayRepository
                ..errorAfterFirstLoad = null
                ..gate = gate;
            case 'goal':
              bodyProfileRepository
                ..errorAfterFirstLoad = null
                ..gate = gate;
            case 'nextPeriod':
              menstrualRepository
                ..errorAfterFirstLoad = null
                ..gate = gate;
            case 'calendar':
              calendarRepository
                ..errorAfterFirstLoad = null
                ..gate = gate;
          }
          await tester.tap(
            find.descendant(
              of: card,
              matching: find.byKey(const Key('stale-notice-retry')),
            ),
          );
          await tester.pump();

          expect(
            find.descendant(of: card, matching: find.text(loc.cardRefreshFailed)),
            findsOneWidget,
            reason: '$target dropped its marking the moment retry was pressed',
          );
          expect(
            tester
                .widget<TextButton>(
                  find.descendant(
                    of: card,
                    matching: find.byKey(const Key('stale-notice-retry')),
                  ),
                )
                .onPressed,
            isNull,
            reason: '$target left its retry pressable while it was running',
          );

          gate.complete();
          await tester.pumpAndSettle();
          // And the reload landing clears it, so the spinner is not a state
          // the card can get stuck in.
          expect(
            find.descendant(of: card, matching: find.text(loc.cardRefreshFailed)),
            findsNothing,
            reason: '$target kept its marking after a successful retry',
          );
        }
      },
    );

    testWidgets(
      'each marking names the card it belongs to — four at once must not read '
      'to a screen reader as four identical "Retry" buttons',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final handle = tester.ensureSemantics();
        final loc = lookupAppLocalizations(const Locale('en'));

        final bodyProfileRepository = _FakeBodyProfileRepository();
        final calendarRepository = _FakeHealthCalendarRepository();
        final menstrualRepository = _FakeMenstrualRepository();
        final careTodayRepository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-24', slots: [_slot()]),
        );
        final dataRevision = DataRevision();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              bodyProfileRepository: bodyProfileRepository,
              healthCalendarRepository: calendarRepository,
              menstrualRepository: menstrualRepository,
              careTodayRepository: careTodayRepository,
              dataRevision: dataRevision,
            ),
          ),
        );
        await tester.pumpAndSettle();

        bodyProfileRepository.errorAfterFirstLoad =
            const BodyProfileFetchFailure();
        calendarRepository.errorAfterFirstLoad =
            const HealthCalendarFetchFailure();
        menstrualRepository.errorAfterFirstLoad = const MenstrualFetchFailure();
        careTodayRepository.errorAfterFirstLoad = const CareRequestFailed();
        dataRevision.bump();
        await tester.pumpAndSettle();

        final labels = <String, String>{
          for (final entry in cardFinders().entries)
            entry.key: tester
                .getSemantics(
                  find.descendant(
                    of: entry.value,
                    matching: find.byType(StaleNotice),
                  ),
                )
                .getSemanticsData()
                .label,
        };

        // Exact, not `startsWith`: a marking merged into its card's own node
        // would carry a label that begins with the card title too (the title
        // is the first thing in every card), and pass a looser assertion while
        // being unreachable in the middle of a paragraph of card content.
        String marking(String title) =>
            '$title: ${loc.cardRefreshFailed}. ${loc.retry}';
        expect(labels['care'], marking(loc.careTodayTitle));
        expect(labels['goal'], marking(loc.goalCardTitle));
        expect(labels['nextPeriod'], marking(loc.nextPeriodTitle));
        expect(labels['calendar'], marking(loc.healthCalendarTitle));
        // Four cards, four distinguishable markings.
        expect(labels.values.toSet(), hasLength(4));

        handle.dispose();
      },
    );
  });

  group('HealthScaffold pull-to-refresh', () {
    /// The overview tab's RefreshIndicator (index 0 is shown first).
    RefreshIndicator overviewIndicator(WidgetTester tester) =>
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));

    // `HealthScaffold` is the other long-mounted shell issue #106 is about: it
    // used to fetch one token at mount and feed every overview/trend load from
    // it. Asserts on the token the repository RECEIVED, not on the provider
    // having been called.
    testWidgets(
      'a refresh after a token renewal carries the new token',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final auth = _RotatingAuthRepository(token: 'token-1');
        final bodyProfileRepository = _FakeBodyProfileRepository();

        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              authRepository: auth,
              bodyProfileRepository: bodyProfileRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(bodyProfileRepository.goalTokens, ['token-1']);

        // Firebase renewed the token while the shell stayed mounted.
        auth.token = 'token-2';

        await overviewIndicator(tester).onRefresh();
        await tester.pumpAndSettle();

        expect(bodyProfileRepository.goalTokens, ['token-1', 'token-2']);
      },
    );

    testWidgets(
      'the overview and trends tabs each wrap their list in a RefreshIndicator '
      'whose scrollable always accepts an overscroll pull (short content still '
      'refreshes)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(l10nRouterTestApp(home: _buildScaffold()));
        await tester.pumpAndSettle();

        // Overview.
        expect(find.byType(RefreshIndicator), findsOneWidget);
        var list = tester.widget<ListView>(
          find.descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(ListView),
          ),
        );
        expect(list.physics, isA<AlwaysScrollableScrollPhysics>());

        // Trends.
        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();
        expect(find.byType(RefreshIndicator), findsOneWidget);
        list = tester.widget<ListView>(
          find.descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(ListView),
          ),
        );
        expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
      },
    );

    testWidgets(
      'pulling to refresh reloads the overview and the gesture future settles '
      'only when that reload finishes',
      (tester) async {
        final calendarRepository = _FakeHealthCalendarRepository();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              healthCalendarRepository: calendarRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calendarRepository.calls, 1);

        // Hold the reload open, then invoke the indicator's callback directly
        // (the Future it returns is exactly what the gesture awaits).
        final gate = Completer<void>();
        calendarRepository.gate = gate;
        var settled = false;
        unawaited(overviewIndicator(tester).onRefresh().then((_) => settled = true));
        await tester.pump();

        expect(calendarRepository.calls, 2);
        expect(settled, isFalse, reason: 'the gesture settled before the reload finished');

        gate.complete();
        await tester.pumpAndSettle();
        expect(settled, isTrue);
      },
    );

    testWidgets(
      'a refresh arriving while a load is in flight does not run a second '
      'concurrent load; both waiters settle once the coalesced reload lands',
      (tester) async {
        final calendarRepository = _FakeHealthCalendarRepository();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              healthCalendarRepository: calendarRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calendarRepository.calls, 1);

        final gate = Completer<void>();
        calendarRepository.gate = gate;

        // First pull starts a reload (call 2) and is held on the gate.
        var firstSettled = false;
        var secondSettled = false;
        unawaited(
          overviewIndicator(tester).onRefresh().then((_) => firstSettled = true),
        );
        await tester.pump();
        expect(calendarRepository.calls, 2);

        // A second pull mid-flight must not start a concurrent load — it rides
        // the same in-flight completer and coalesces into one extra round.
        unawaited(
          overviewIndicator(tester).onRefresh().then((_) => secondSettled = true),
        );
        await tester.pump();
        expect(calendarRepository.calls, 2);
        expect(firstSettled, isFalse);
        expect(secondSettled, isFalse);

        gate.complete();
        await tester.pumpAndSettle();
        // Exactly one coalesced extra round ran after the first, and both
        // waiters resolved (a per-round completer would leave the gesture
        // future hanging or complete it twice).
        expect(calendarRepository.calls, 3);
        expect(firstSettled, isTrue);
        expect(secondSettled, isTrue);
      },
    );

    testWidgets(
      'a token fetch that throws during a pull still settles the gesture '
      '(the spinner never hangs forever)',
      (tester) async {
        final authRepository = _ThrowingAuthRepository();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              authRepository: authRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        authRepository.arm();
        var settled = false;
        unawaited(overviewIndicator(tester).onRefresh().then((_) => settled = true));
        await tester.pumpAndSettle();

        expect(settled, isTrue);
      },
    );
  });

  group('HealthScaffold overview last-loaded time', () {
    testWidgets('shows the last-loaded time after the initial load', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nRouterTestApp(
          home: _buildScaffold(clock: () => DateTime(2026, 7, 24, 9, 0)),
        ),
      );
      await tester.pumpAndSettle();

      final label = tester.widget<LastLoadedLabel>(
        find.byType(LastLoadedLabel),
      );
      expect(label.lastLoadedAt, DateTime(2026, 7, 24, 9, 0));
    });

    testWidgets(
      'a reload where at least one overview card loads advances the time',
      (tester) async {
        var now = DateTime(2026, 7, 24, 9, 0);
        final dataRevision = DataRevision();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(clock: () => now, dataRevision: dataRevision),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<LastLoadedLabel>(find.byType(LastLoadedLabel)).lastLoadedAt,
          DateTime(2026, 7, 24, 9, 0),
        );

        now = DateTime(2026, 7, 24, 10, 30);
        dataRevision.bump();
        await tester.pumpAndSettle();

        expect(
          tester.widget<LastLoadedLabel>(find.byType(LastLoadedLabel)).lastLoadedAt,
          DateTime(2026, 7, 24, 10, 30),
        );
      },
    );

    testWidgets(
      'the CRITICAL case: token fetch succeeds but every overview card fails '
      '(airplane mode) — the time is left unchanged, never claiming a just-now '
      'load that produced no fresh data',
      (tester) async {
        var now = DateTime(2026, 7, 24, 9, 0);
        final bodyProfileRepository = _FakeBodyProfileRepository();
        final calendarRepository = _FakeHealthCalendarRepository();
        final menstrualRepository = _FakeMenstrualRepository();
        final careTodayRepository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-24', slots: [_slot()]),
        );
        final careHistoryRepository = _FakeCareHistoryRepository(
          days: [
            CareHistoryDay(
              date: '2026-07-24',
              slots: [_slot(status: CareTodayStatus.done)],
            ),
          ],
        );
        final vitalsRepository = _FakeVitalsRepository();
        final dataRevision = DataRevision();
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              clock: () => now,
              bodyProfileRepository: bodyProfileRepository,
              healthCalendarRepository: calendarRepository,
              menstrualRepository: menstrualRepository,
              careTodayRepository: careTodayRepository,
              careHistoryRepository: careHistoryRepository,
              vitalsRepository: vitalsRepository,
              dataRevision: dataRevision,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<LastLoadedLabel>(find.byType(LastLoadedLabel)).lastLoadedAt,
          DateTime(2026, 7, 24, 9, 0),
        );

        // Every overview/trend source fails on the next reload — a fetch
        // failure (not a 401), so the controllers land in `error`, `Future.wait`
        // still resolves, and the overview stays rendered (with #103 markings).
        bodyProfileRepository.errorAfterFirstLoad = const BodyProfileFetchFailure();
        calendarRepository.errorAfterFirstLoad = const HealthCalendarFetchFailure();
        menstrualRepository.errorAfterFirstLoad = const MenstrualFetchFailure();
        careTodayRepository.errorAfterFirstLoad = const CareRequestFailed();
        careHistoryRepository.errorAfterFirstLoad = const CareRequestFailed();
        vitalsRepository.errorAfterFirstLoad = const VitalsFetchFailure('boom');

        now = DateTime(2026, 7, 24, 10, 30);
        dataRevision.bump();
        await tester.pumpAndSettle();

        // The time did NOT jump to 10:30 — it must reflect the last load that
        // actually produced data. Asserting only "success updates" would pass
        // this bug too (Future.wait resolves regardless), which is why this
        // case is the linchpin.
        expect(
          tester.widget<LastLoadedLabel>(find.byType(LastLoadedLabel)).lastLoadedAt,
          DateTime(2026, 7, 24, 9, 0),
        );
      },
    );
  });

  group('HealthScaffold overview push-off banner', () {
    testWidgets(
      'permissionPrompt with care slots today: the banner sits above the '
      'today-care summary card and its action pushes /reminders',
      (tester) async {
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              pushHealthController: testPushHealthController(
                PushHealth.permissionPrompt,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const Key('push-off-banner'))).dy,
          lessThan(tester.getTopLeft(find.byType(CareTodaySummaryCard)).dy),
        );

        await tester.tap(find.byKey(const Key('push-off-action')));
        await tester.pumpAndSettle();

        expect(find.text('/reminders'), findsOneWidget);
      },
    );

    testWidgets('permissionDenied with care slots today shows the banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nRouterTestApp(
          home: _buildScaffold(
            careTodaySlots: [_slot()],
            pushHealthController: testPushHealthController(
              PushHealth.permissionDenied,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
    });

    for (final health in [
      PushHealth.ok,
      PushHealth.unknown,
      PushHealth.unsupported,
      PushHealth.syncFailed,
    ]) {
      testWidgets('${health.name} with care slots today shows no banner', (
        tester,
      ) async {
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              pushHealthController: testPushHealthController(health),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('push-off-banner')), findsNothing);
      });
    }

    testWidgets(
      'no care slots today: no banner, even though the summary card still '
      'renders its setup prompt',
      (tester) async {
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              pushHealthController: testPushHealthController(
                PushHealth.permissionDenied,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CareTodaySummaryCard), findsOneWidget);
        expect(find.byKey(const Key('push-off-banner')), findsNothing);
      },
    );

    testWidgets(
      'a push-health change while the overview is open shows the banner '
      'without reopening it',
      (tester) async {
        final pushHealth = testPushHealthController(PushHealth.ok);
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: _buildScaffold(
              careTodaySlots: [_slot()],
              pushHealthController: pushHealth,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('push-off-banner')), findsNothing);

        pushHealth.health = PushHealth.permissionDenied;
        pushHealth.notifyListeners();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
      },
    );
  });
}
