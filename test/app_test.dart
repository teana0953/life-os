import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/app.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/application/sign_up.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/body_profile/presentation/weight_goal_controller.dart';
import 'package:life_os/contexts/health_calendar/application/get_health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_repository.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal_item.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/import/application/import_bowel.dart';
import 'package:life_os/contexts/import/application/import_diet.dart';
import 'package:life_os/contexts/import/application/import_diet_target.dart';
import 'package:life_os/contexts/import/application/import_water.dart';
import 'package:life_os/contexts/import/application/import_weight.dart';
import 'package:life_os/contexts/import/domain/chaodays_import_summary.dart';
import 'package:life_os/contexts/import/domain/import_repository.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_controller.dart';
import 'package:life_os/contexts/notifications/application/care_items.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/application/enable_reminders.dart';
import 'package:life_os/contexts/notifications/application/get_care_history.dart';
import 'package:life_os/contexts/notifications/application/send_test_push.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';
import 'package:life_os/contexts/notifications/domain/web_push_gateway.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_controller.dart';
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
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/hydration/application/add_water.dart';
import 'package:life_os/contexts/hydration/application/get_water_day.dart';
import 'package:life_os/contexts/hydration/application/set_water_target.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/hydration/presentation/water_controller.dart';
import 'package:life_os/contexts/bowel/application/get_bowel_day.dart';
import 'package:life_os/contexts/bowel/application/save_bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_controller.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/presentation/trend_controller.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';
import 'package:life_os/contexts/exercise/application/add_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/delete_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/get_exercise_day.dart';
import 'package:life_os/contexts/exercise/application/list_exercise_activities.dart';
import 'package:life_os/contexts/exercise/domain/exercise_day.dart';
import 'package:life_os/contexts/exercise/domain/exercise_repository.dart';
import 'package:life_os/contexts/exercise/presentation/exercise_controller.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/data_revision.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:life_os/shared/pwa/pwa_update.dart';
import 'package:life_os/shared/pwa/pwa_update_controller.dart';
import 'package:life_os/shared/theme/app_colors.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/l10n_test_app.dart';

class _FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}
}

class _FakeMealRepository implements MealRepository {
  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    return DayMealsLog.fromJson({
      'day': day,
      'meals': <dynamic>[],
      'totals': {
        'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
        'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
      },
    });
  }

  @override
  Future<MealEntry> createMeal(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }

  @override
  Future<void> patchMealItem(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMealItem(String idToken, String id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMeal(String idToken, String id) async {
    throw UnimplementedError();
  }
}

class _FakeDailyTargetRepository implements DailyTargetRepository {
  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    return DailyTargetWithRemaining.fromJson({
      'day': day,
      'base': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'effective': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'logged': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'remaining': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
    });
  }

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
  }) async {
    throw UnimplementedError();
  }
}

class _FakeWaterRepository implements WaterRepository {
  @override
  Future<WaterDay> getDay(String idToken, String day) async => WaterDay(
    day: day,
    totalMl: 0,
    targetMl: 2000,
    remainingMl: 2000,
  );

  @override
  Future<int> addWater(
    String idToken, {
    required String day,
    required int addMl,
  }) async => 0;

  @override
  Future<int> setTarget(
    String idToken, {
    required String day,
    required int targetMl,
  }) async => targetMl;
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
  }) async =>
      BowelDay(day: day, count: count, isNormal: isNormal, note: note);
}

class _FakeVitalsRepository implements VitalsRepository {
  @override
  Future<VitalsRange> getRange(
    String idToken,
    DateTime from,
    DateTime to,
  ) async => VitalsRange(
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
  }) async => throw UnimplementedError();

  @override
  Future<bool> deleteEntry(String idToken, String entryId) async => true;
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
  }) async => throw UnimplementedError();

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async => throw UnimplementedError();

  @override
  Future<bool> deletePeriod(String idToken, String id) async => true;
}

class _FakeImportRepository implements ImportRepository {
  static const _summary = ChaodaysImportSummary(imported: 0, skipped: 0);

  @override
  Future<ChaodaysImportSummary> importWeight(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => _summary;

  @override
  Future<ChaodaysImportSummary> importDiet(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => _summary;

  @override
  Future<ChaodaysImportSummary> importWater(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => _summary;

  @override
  Future<ChaodaysImportSummary> importBowel(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => _summary;

  @override
  Future<ChaodaysImportSummary> importDietTarget(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => _summary;
}

class _FakePushRepository implements PushRepository {
  @override
  Future<String> fetchVapidPublicKey(String idToken) async => 'fake-vapid-key';

  @override
  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  ) async {}

  @override
  Future<TestPushResult> sendTest(String idToken) async =>
      const TestPushResult(sent: 0, failed: 0);
}

class _FakeWebPushGateway implements WebPushGateway {
  @override
  PushEnvironment describeEnvironment() => const PushEnvironment(
    supported: true,
    iosNeedsInstall: false,
  );

  @override
  PushPermissionStatus permissionStatus() => PushPermissionStatus.prompt;

  @override
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey) async =>
      null;
}

class _FakeCareItemRepository implements CareItemRepository {
  @override
  Future<List<CareItem>> list(String idToken) async => const [];

  @override
  Future<CareItem> create(String idToken, CareItemDraft draft) async =>
      CareItem(
        id: 'care-new',
        category: draft.category,
        title: draft.title,
        note: draft.note,
        dose: draft.dose,
        stock: draft.stock,
        stockAlert: draft.stockAlert,
        schedules: draft.schedules,
      );

  @override
  Future<CareItem> update(
    String idToken,
    String id,
    CareItemUpdate update,
  ) async => CareItem(
    id: id,
    category: update.category,
    title: update.title,
    note: update.note,
    dose: update.dose,
    stock: update.stock,
    stockAlert: update.stockAlert,
    schedules: update.schedules,
  );

  @override
  Future<void> delete(String idToken, String id) async {}
}

class _FakeCareTodayRepository implements CareTodayRepository {
  @override
  Future<CareToday> getToday(String idToken) async =>
      const CareToday(date: '2026-07-22', slots: []);

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {}
}

class _FakeCareHistoryRepository implements CareHistoryRepository {
  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async => const [];

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {}
}

CareTodaySlot _careSlot(CareTodayStatus status) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: 'sch-1',
  category: CareCategory.medication,
  title: 'Metformin',
  timeOfDay: '08:00',
  localDate: '2026-07-22',
  status: status,
  doseQuantity: 1,
);

/// A [CareHistoryRepository] whose records actually change when a slot is
/// edited — unlike [_FakeCareHistoryRepository], which always returns an
/// empty range — so an end-to-end test can assert that a correction made on
/// `/care-history` shows up on the trend tab's card after the shared
/// [DataRevision] bump reloads the health module (design §D).
class _MutableCareHistoryRepository implements CareHistoryRepository {
  List<CareHistoryDay> days;

  _MutableCareHistoryRepository(this.days);

  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async => days;

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {
    days = [
      for (final day in days)
        CareHistoryDay(
          date: day.date,
          slots: [
            for (final slot in day.slots)
              if (slot.careScheduleId == careScheduleId &&
                  slot.localDate == localDate &&
                  slot.timeOfDay == timeOfDay)
                _careSlot(
                  status == CareLogStatus.done
                      ? CareTodayStatus.done
                      : CareTodayStatus.skipped,
                )
              else
                slot,
          ],
        ),
    ];
  }
}

class _FakeBodyProfileRepository implements BodyProfileRepository {
  @override
  Future<WeightGoal> getWeightGoal(String idToken) async =>
      const WeightGoal(targetWeightKg: 51);

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async =>
      const BodyProfile(heightCm: 165);

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async => BodyProfile(heightCm: heightCm, targetWeightKg: targetWeightKg);
}

/// Builds a fresh set of fake-backed health controllers for wiring [App] in
/// tests that don't exercise the diet module themselves.
({
  TodayController today,
  DictionaryController dictionary,
  DailyTargetController dailyTarget,
  CreateMealController createMeal,
  GetLoggedDays getLoggedDays,
  WaterController water,
  BowelController bowel,
  VitalsController vitals,
  ExerciseController exercise,
  MenstrualController menstrual,
  WeightGoalController weightGoal,
  TrendController trend,
  HealthCalendarController healthCalendar,
}) testHealthControllers() {
  final mealRepository = _FakeMealRepository();
  final dailyTargetRepository = _FakeDailyTargetRepository();
  final foodDictionaryRepository = _FakeFoodDictionaryRepository();
  final waterRepository = _FakeWaterRepository();
  final bowelRepository = _FakeBowelRepository();
  final vitalsRepository = _FakeVitalsRepository();
  final exerciseRepository = _FakeExerciseRepository();
  final menstrualRepository = _FakeMenstrualRepository();
  final bodyProfileRepository = _FakeBodyProfileRepository();
  return (
    today: TodayController(
      GetDayMeals(mealRepository),
      GetDailyTargetWithRemaining(dailyTargetRepository),
      EditMealItem(mealRepository),
      DeleteMealItem(mealRepository),
      ChangeMealTime(mealRepository),
      DeleteMeal(mealRepository),
    ),
    dictionary: DictionaryController(
      SearchDictionary(foodDictionaryRepository),
      ListFavorites(foodDictionaryRepository),
      FavoriteFood(foodDictionaryRepository),
      UnfavoriteFood(foodDictionaryRepository),
    ),
    dailyTarget: DailyTargetController(
      GetDailyTargetWithRemaining(dailyTargetRepository),
      SetDailyTarget(dailyTargetRepository),
    ),
    createMeal: CreateMealController(CreateMeal(mealRepository)),
    getLoggedDays: GetLoggedDays(mealRepository),
    water: WaterController(
      GetWaterDay(waterRepository),
      AddWater(waterRepository),
      SetWaterTarget(waterRepository),
    ),
    bowel: BowelController(
      GetBowelDay(bowelRepository),
      SaveBowelDay(bowelRepository),
    ),
    vitals: VitalsController(
      GetVitalsDay(vitalsRepository),
      SaveVitalsDay(vitalsRepository),
    ),
    exercise: ExerciseController(
      ListExerciseActivities(exerciseRepository),
      GetExerciseDay(exerciseRepository),
      AddExerciseEntry(exerciseRepository),
      DeleteExerciseEntry(exerciseRepository),
    ),
    menstrual: MenstrualController(
      GetMenstrualOverview(menstrualRepository),
      AddPeriod(menstrualRepository),
      UpdatePeriod(menstrualRepository),
      DeletePeriod(menstrualRepository),
    ),
    weightGoal: WeightGoalController(
      GetWeightGoal(bodyProfileRepository),
      GetBodyProfile(bodyProfileRepository),
      SetBodyProfile(bodyProfileRepository),
    ),
    trend: TrendController(GetVitalsTrends(vitalsRepository)),
    healthCalendar: HealthCalendarController(
      GetHealthCalendar(_FakeHealthCalendarRepository()),
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

class FakeAuthRepository implements AuthRepository {
  static const validEmail = 'user@example.com';
  static const validPassword = 'correct-password';

  FakeAuthRepository({bool initiallyAuthenticated = false})
      : _isAuthenticated = initiallyAuthenticated;

  bool _isAuthenticated;
  bool signOutCalled = false;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<void> signIn(String email, String password) async {
    if (email != validEmail || password != validPassword) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
    _isAuthenticated = true;
    _controller.add(true);
  }

  @override
  Future<void> signUp(String email, String password) async {
    _isAuthenticated = true;
    _controller.add(true);
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _isAuthenticated = false;
    _controller.add(false);
  }

  @override
  Future<String?> idToken() async => _isAuthenticated ? 'fake-token' : null;

  @override
  Stream<bool> get authStateChanges async* {
    yield _isAuthenticated;
    yield* _controller.stream;
  }
}

class ErroringAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges =>
      Stream<bool>.error(Exception('boom: internal stream detail'));
}

class FakeProfileRepository implements ProfileRepository {
  final UserProfile profile;

  FakeProfileRepository(this.profile);

  @override
  Future<UserProfile> getProfile(String idToken) async => profile;
}

final _testProfile = UserProfile(
  id: 'user-1',
  firebaseUid: 'firebase-abc',
  email: 'user@example.com',
  displayName: 'Test User',
  createdAt: '2026-01-01T00:00:00.000Z',
);

/// Builds a fresh [ThemeController] backed by an empty, mocked
/// [SharedPreferences] instance (so it defaults to [ThemeMode.system]).
Future<ThemeController> testThemeController() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ThemeController(prefs);
}

/// Pumps [App], wiring in a [LocaleController] (defaulting to a fresh one
/// that follows the system locale, or [localeController] if provided).
/// Returns the [LocaleController] used, so tests can drive it directly.
Future<LocaleController> pumpApp(
  WidgetTester tester, {
  required AuthRepository authRepository,
  required LoginController loginController,
  required HomeController homeController,
  LocaleController? localeController,
  ThemeController? themeController,
  SignOut? signOut,
  SignUp? signUp,
  ChaodaysImportController? chaodaysImportController,
  ReminderSettingsController? reminderSettingsController,
  CareItemsController? careItemsController,
  CareTodayController? careTodayController,
  CareHistoryController? careHistoryController,
  CareHistoryController? careAdherenceController,

  /// Shared, mirroring main.dart, between the import controller (which
  /// bumps it), the health shell (which listens to it), and both
  /// [CareHistoryController] instances (which are injected with it, so an
  /// edit on `/care-history` bumps the trend tab's card too — design §D).
  /// Defaults to a fresh instance; pass one explicitly to inject it into a
  /// caller-supplied controller as well, so the two stay wired to the same
  /// revision.
  DataRevision? dataRevision,
}) async {
  final resolvedLocaleController =
      localeController ?? await testLocaleController();
  final resolvedThemeController =
      themeController ?? await testThemeController();
  final resolvedSignOut = signOut ?? SignOut(authRepository);
  final resolvedSignUp = signUp ?? SignUp(authRepository);
  final health = testHealthControllers();
  final resolvedDataRevision = dataRevision ?? DataRevision();
  final resolvedChaodaysImportController =
      chaodaysImportController ??
      () {
        final importRepository = _FakeImportRepository();
        return ChaodaysImportController(
          ImportWeight(importRepository),
          ImportDiet(importRepository),
          ImportWater(importRepository),
          ImportBowel(importRepository),
          ImportDietTarget(importRepository),
          resolvedDataRevision,
        );
      }();
  final resolvedReminderSettingsController =
      reminderSettingsController ??
      () {
        final pushRepository = _FakePushRepository();
        final webPushGateway = _FakeWebPushGateway();
        return ReminderSettingsController(
          webPushGateway,
          EnableReminders(pushRepository, webPushGateway),
          SendTestPush(pushRepository),
        );
      }();
  final resolvedCareItemsController =
      careItemsController ??
      () {
        final repository = _FakeCareItemRepository();
        return CareItemsController(
          ListCareItems(repository),
          CreateCareItem(repository),
          UpdateCareItem(repository),
          DeleteCareItem(repository),
        );
      }();
  final resolvedCareTodayController =
      careTodayController ??
      () {
        final repository = _FakeCareTodayRepository();
        return CareTodayController(
          GetCareToday(repository),
          MarkCareDone(repository),
          MarkCareSkipped(repository),
        );
      }();
  final resolvedCareHistoryController =
      careHistoryController ??
      () {
        final repository = _FakeCareHistoryRepository();
        return CareHistoryController(
          GetCareHistory(repository),
          EditCareSlot(repository),
          resolvedDataRevision,
          spanDays: 7,
        );
      }();
  final resolvedCareAdherenceController =
      careAdherenceController ??
      () {
        final repository = _FakeCareHistoryRepository();
        return CareHistoryController(
          GetCareHistory(repository),
          EditCareSlot(repository),
          resolvedDataRevision,
          spanDays: 30,
        );
      }();
  await tester.pumpWidget(
    App(
      authRepository: authRepository,
      loginController: loginController,
      homeController: homeController,
      localeController: resolvedLocaleController,
      themeController: resolvedThemeController,
      signOut: resolvedSignOut,
      signUp: resolvedSignUp,
      healthTodayController: health.today,
      healthDictionaryController: health.dictionary,
      healthDailyTargetController: health.dailyTarget,
      healthCreateMealController: health.createMeal,
      healthGetLoggedDays: health.getLoggedDays,
      waterController: health.water,
      bowelController: health.bowel,
      vitalsController: health.vitals,
      exerciseController: health.exercise,
      menstrualController: health.menstrual,
      weightGoalController: health.weightGoal,
      trendController: health.trend,
      healthCalendarController: health.healthCalendar,
      // Not started (no timer): on the VM the stub reports no update, and
      // these tests don't exercise the update banner.
      pwaUpdateController: PwaUpdateController(const PwaUpdateImpl()),
      chaodaysImportController: resolvedChaodaysImportController,
      reminderSettingsController: resolvedReminderSettingsController,
      careItemsController: resolvedCareItemsController,
      careTodayController: resolvedCareTodayController,
      careHistoryController: resolvedCareHistoryController,
      careAdherenceController: resolvedCareAdherenceController,
      dataRevision: resolvedDataRevision,
    ),
  );
  return resolvedLocaleController;
}

void main() {
  group('App auth-state routing', () {
    testWidgets('starts unauthenticated shows the login screen', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('email-field')), findsOneWidget);
    });

    testWidgets(
      'starts authenticated fetches the profile and shows the home screen',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('user@example.com'), findsOneWidget);
      },
    );

    testWidgets('successful sign-in transitions to the home screen', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('email-field')),
        FakeAuthRepository.validEmail,
      );
      await tester.enterText(
        find.byKey(const Key('password-field')),
        FakeAuthRepository.validPassword,
      );
      await tester.tap(find.byKey(const Key('submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets(
      'sign-out from settings returns to the login screen',
      (tester) async {
        final authRepository = FakeAuthRepository(
          initiallyAuthenticated: true,
        );
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('settings-icon-button')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('settings-sign-out-button')),
        );
        await tester.tap(find.byKey(const Key('settings-sign-out-button')));
        await tester.pumpAndSettle();

        expect(authRepository.signOutCalled, isTrue);
        expect(find.byKey(const Key('email-field')), findsOneWidget);
      },
    );

    testWidgets(
      'regression: back from a deep diet route returns one level, not to the grid',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_note));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('hub-tile-diet')), findsOneWidget);
        await tester.tap(find.byKey(const Key('hub-tile-diet')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('diet-open-target')), findsOneWidget);
        await tester.tap(find.byKey(const Key('diet-open-target')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('diet-open-target')), findsNothing);

        // Back from the target screen must return to the diet day screen —
        // NOT collapse all the way to the grid.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('diet-open-target')), findsOneWidget);
        expect(find.byKey(const Key('health-tile')), findsNothing);
      },
    );

    testWidgets(
      'regression: a URL-driven deep route (go) pops one level via the real '
      'router, not to the grid',
      (tester) async {
        // Drives the REAL app router by URL — what a web browser back / refresh
        // does — to prove the nested routes rebuild the stack (the flat-route
        // version collapsed a URL-reached leaf straight to the grid on pop).
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/water');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('water-add-250')), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();
        // One level up = the health module (its bottom nav), NOT the grid.
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byKey(const Key('water-add-250')), findsNothing);
        expect(find.byKey(const Key('health-tile')), findsNothing);
      },
    );

    testWidgets(
      'auth stream error shows a recoverable error screen instead of an '
      'infinite spinner',
      (tester) async {
        final authRepository = ErroringAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('auth-retry-button')), findsOneWidget);
      },
    );
  });

  group('App chaodays import entry', () {
    testWidgets(
      'the health module\'s More tab import tile navigates to /import/chaodays',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('health-more-import')), findsOneWidget);

        await tester.tap(find.byKey(const Key('health-more-import')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('import-account-field')), findsOneWidget);
      },
    );
  });

  group('App reminders entry', () {
    testWidgets(
      'the health module\'s More tab reminders tile navigates to /reminders',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('health-more-reminders')), findsOneWidget);

        await tester.tap(find.byKey(const Key('health-more-reminders')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reminder-enable-button')), findsOneWidget);
      },
    );
  });

  group('App care reminders entry', () {
    testWidgets(
      'the health module\'s More tab care-items tile navigates to '
      '/care-items',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('health-more-care-items')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('health-more-care-items')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-items-add-fab')), findsOneWidget);
      },
    );

    testWidgets(
      'the trend tab\'s care adherence card links straight to /care-history '
      '— the heatmap is where a user sees the day they want to correct, and '
      'the record list is otherwise only reachable through the More tab',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('care-adherence-open-history')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('care-history-range-selector')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'correcting a record on /care-history refreshes the trend tab\'s care '
      'adherence card: the edit bumps the shared DataRevision, the health '
      'module reloads, and the card shows the corrected day at its own '
      'period',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        // One shared repository and one shared DataRevision across both
        // CareHistoryController instances, mirroring main.dart.
        final careHistoryRepository = _MutableCareHistoryRepository([
          CareHistoryDay(
            date: '2026-07-22',
            slots: [_careSlot(CareTodayStatus.missed)],
          ),
        ]);
        final dataRevision = DataRevision();
        CareHistoryController careController(int spanDays) =>
            CareHistoryController(
              GetCareHistory(careHistoryRepository),
              EditCareSlot(careHistoryRepository),
              dataRevision,
              spanDays: spanDays,
              clock: () => DateTime(2026, 7, 22),
            );

        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          careHistoryController: careController(7),
          careAdherenceController: careController(30),
          dataRevision: dataRevision,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        final missedLegend = loc.careAdherenceLegendWithCount(
          loc.careHistoryLegendMissed,
          1,
        );
        final fullLegend = loc.careAdherenceLegendWithCount(
          loc.careHistoryLegendFull,
          1,
        );

        // Trends tab: the day currently counts as missed.
        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();
        expect(find.text(missedLegend), findsOneWidget);

        // More tab → care management → history, and correct the record.
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('health-more-care-items')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-items-history-button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        await tester.pumpAndSettle();

        expect(dataRevision.revision, 1);

        // Back to the health module (still mounted below /care-items and
        // /care-history) and its trends tab.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.show_chart));
        await tester.pumpAndSettle();

        expect(find.text(fullLegend), findsOneWidget);
        expect(find.text(missedLegend), findsNothing);
        // The card kept its own 30-day period — the refresh is about
        // staleness, not about adopting the history screen's period.
        final selector = tester.widget<SegmentedButton<int>>(
          find.byKey(const Key('care-adherence-range-selector')),
        );
        expect(selector.selected, {30});
      },
    );
  });

  group('App theming', () {
    testWidgets(
      'wires light/dark Material 3 themes and follows the system',
      (tester) async {
        final authRepository = FakeAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(materialApp.theme!.useMaterial3, isTrue);
        expect(materialApp.theme!.colorScheme.primary, hachiwareBlue);
        expect(materialApp.theme!.colorScheme.brightness, Brightness.light);
        expect(materialApp.darkTheme!.useMaterial3, isTrue);
        expect(materialApp.darkTheme!.colorScheme.primary, hachiwareBlue);
        expect(
          materialApp.darkTheme!.colorScheme.brightness,
          Brightness.dark,
        );
        expect(materialApp.themeMode, ThemeMode.system);
      },
    );

    testWidgets(
      'themeMode follows the injected ThemeController and updates the '
      'MaterialApp on change',
      (tester) async {
        final authRepository = FakeAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        final themeController = await testThemeController();
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          themeController: themeController,
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.system,
        );

        await themeController.setThemeMode(ThemeMode.dark);
        await tester.pumpAndSettle();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );
      },
    );
  });

  group('App i18n', () {
    testWidgets('unsupported system locale falls back to English', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('fr');
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final authRepository = ErroringAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('supported zh-Hant system locale shows Traditional Chinese', (
      tester,
    ) async {
      const zhHant = Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      );
      tester.platformDispatcher.localeTestValue = zhHant;
      tester.platformDispatcher.localesTestValue = [zhHant];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final authRepository = ErroringAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('重試'), findsOneWidget);
    });

    testWidgets(
      'switching the locale via the controller updates the UI immediately',
      (tester) async {
        final authRepository = ErroringAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        final localeController = await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Retry'), findsOneWidget);

        await localeController.setLocale(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        );
        await tester.pumpAndSettle();

        expect(find.text('重試'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets('a persisted language choice overrides the system locale', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'locale_language_code': 'zh'});
      final prefs = await SharedPreferences.getInstance();
      final localeController = LocaleController(prefs);
      tester.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final authRepository = ErroringAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
        localeController: localeController,
      );
      await tester.pumpAndSettle();

      expect(find.text('重試'), findsOneWidget);
    });
  });
}
