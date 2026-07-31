import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:life_os/contexts/health/application/create_shared_food_item.dart';
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
import 'package:life_os/contexts/health/application/update_shared_food_item.dart';
import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/delete_budget.dart';
import 'package:life_os/contexts/finance/application/delete_transaction.dart';
import 'package:life_os/contexts/finance/application/get_finance_month.dart';
import 'package:life_os/contexts/finance/application/update_transaction.dart';
import 'package:life_os/contexts/finance/application/upsert_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_category.dart';
import 'package:life_os/contexts/finance/domain/finance_repository.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/monthly_summary.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:life_os/contexts/import/application/import_bowel.dart';
import 'package:life_os/contexts/import/application/import_diet.dart';
import 'package:life_os/contexts/import/application/import_diet_target.dart';
import 'package:life_os/contexts/import/application/import_menstrual.dart';
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
import 'package:life_os/contexts/notifications/presentation/push_health_controller.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_controller.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';
import 'package:life_os/contexts/health/presentation/shared_food_item_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/snack_naming.dart';
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
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:life_os/shared/pwa/pending_deep_link.dart';
import 'package:life_os/shared/pwa/pwa_update.dart';
import 'package:life_os/shared/pwa/pwa_update_controller.dart';
import 'package:life_os/shared/theme/app_colors.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/l10n_test_app.dart';
import 'support/push_health.dart';

FoodItem _riceItem() => FoodItem.fromJson({
  'id': 'rice-1',
  'owner_user_id': null,
  'name': '飯/1碗',
  'carb_g': 60, 'protein_g': 4, 'fat_g': 0.5, 'sugar_g': 0, 'fiber_g': 1, 'kcal': 280,
  'staple': 4, 'meat': 0, 'fruit': 0, 'veg': 0,
  'base_amount': null, 'measure_unit': null,
});

class _FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  /// Foods reported as favorites (so they show as the food search's default,
  /// no-query results) and as any search's hits. Empty unless a test needs a
  /// food to pick.
  final List<FoodItem> foods;

  _FakeFoodDictionaryRepository({this.foods = const []});

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => foods;

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => foods;

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}

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

/// A meal repository that can hold ONE named day's fetch in flight — for
/// observing what the dictionary does while somebody else's load has not landed
/// yet (`dayMealsLog` still holding the day being replaced).
class _GateOneDayMealRepository extends _FakeMealRepository {
  String? gatedDay;
  final _release = Completer<void>();

  void release() {
    gatedDay = null;
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    // Waits, then delegates — the parent does the single `receivedDays` entry,
    // so the list keeps meaning "one entry per fetch, in completion order".
    if (day == gatedDay) await _release.future;
    return super.getDayMeals(idToken, day);
  }
}

/// A meal repository whose fetches start failing on demand — for reaching the
/// "the dictionary never managed to take the controller over" path.
class _FailAfterFirstDaysMealRepository extends _FakeMealRepository {
  bool failFromNowOn = false;

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    // `async`, matching the parent — a synchronous throw would land the
    // loading→error notifies in one synchronous block, a timing a real HTTP
    // failure never produces.
    if (failFromNowOn) {
      receivedDays.add(day);
      throw const DietFetchFailure('boom');
    }
    return super.getDayMeals(idToken, day);
  }
}

class _FakeMealRepository implements MealRepository {
  /// Meal group names to report per day, so a test can set up a day that
  /// already has meals.
  final Map<String, List<String>> mealNamesByDay;

  /// When set, every fetch waits on this before answering — lets a test hold
  /// the day's record in flight and observe what the UI does meanwhile.
  final Future<void>? gate;

  /// When set, every fetch throws it — lets a test drive the controller into
  /// its error / needsReauth states.
  final Object? fetchError;

  _FakeMealRepository({
    this.mealNamesByDay = const {},
    this.gate,
    this.fetchError,
  });

  String? createdDay;
  String? createdMeal;

  /// Every day fetched, in order — so a test can tell a refresh apart from
  /// the load that first showed the day.
  final List<String> receivedDays = [];

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    receivedDays.add(day);
    if (gate != null) await gate;
    if (fetchError != null) throw fetchError!;
    return DayMealsLog.fromJson({
      'day': day,
      'meals': [
        for (final name in mealNamesByDay[day] ?? const <String>[])
          {
            'id': 'meal-$name',
            'meal': name,
            'time': '2026-07-14T12:00:00.000Z',
            'items': const <dynamic>[],
          },
      ],
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
    createdDay = day;
    createdMeal = meal;
    return MealEntry.fromJson({
      'id': 'meal-1',
      'meal': meal,
      'time': '2026-07-14T12:00:00.000Z',
      'items': <dynamic>[],
    });
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

/// An inert fake: empty categories/transactions, an empty summary for any
/// month — enough for `App` construction/routing tests that don't exercise
/// the finance module itself.
class _FakeFinanceRepository implements FinanceRepository {
  @override
  Future<List<FinanceCategory>> getCategories(String idToken) async => const [];

  @override
  Future<List<FinanceTransaction>> getTransactions(
    String idToken, {
    required String from,
    required String to,
  }) async => const [];

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async =>
      MonthlySummary(month: month, totals: const [], byCategory: const []);

  @override
  Future<FinanceTransaction> addTransaction(
    String idToken, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) async => FinanceTransaction(
    id: 't1',
    type: type,
    amount: amount,
    currency: currency,
    categoryId: categoryId,
    date: date,
    note: note,
  );

  @override
  Future<FinanceTransaction> updateTransaction(
    String idToken,
    String id, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) async => FinanceTransaction(
    id: id,
    type: type,
    amount: amount,
    currency: currency,
    categoryId: categoryId,
    date: date,
    note: note,
  );

  @override
  Future<void> deleteTransaction(String idToken, String id) async {}

  @override
  Future<List<FinanceBudget>> listBudgets(String idToken, String month) async =>
      const [];

  @override
  Future<void> upsertBudget(
    String idToken, {
    String? categoryId,
    required int amount,
  }) async {}

  @override
  Future<void> deleteBudget(String idToken, String id) async {}

  @override
  Future<List<NetWorthAccount>> listNetWorthAccounts(String idToken) async =>
      const [];

  @override
  Future<NetWorthAccount> createNetWorthAccount(
    String idToken, {
    required NetWorthKind kind,
    required String name,
    int? sortOrder,
  }) async => throw UnimplementedError();

  @override
  Future<NetWorthAccount> updateNetWorthAccount(
    String idToken,
    String id, {
    String? name,
    int? sortOrder,
    bool? archived,
  }) async => throw UnimplementedError();

  @override
  Future<NetWorthSnapshot> upsertNetWorthSnapshot(
    String idToken, {
    required String accountId,
    required String month,
    required int value,
  }) async => throw UnimplementedError();

  @override
  Future<MonthlyNetWorth> getMonthlyNetWorth(String idToken, String month) async =>
      MonthlyNetWorth(
        month: month,
        accounts: const [],
        totalAsset: 0,
        totalLiability: 0,
        netWorth: 0,
        prevNetWorth: null,
        growthRate: null,
      );

  @override
  Future<List<NetWorthTrendPoint>> getNetWorthTrend(
    String idToken, {
    required String from,
    required String to,
  }) async => const [];
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

  @override
  Future<ChaodaysImportSummary> importMenstrual(
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
    DateTime? doneTime,
  }) async {}
}

CareTodaySlot _careSlot(CareTodayStatus status, {String localDate = '2026-07-22'}) =>
    CareTodaySlot(
      careItemId: 'care-1',
      careScheduleId: 'sch-1',
      category: CareCategory.medication,
      title: 'Metformin',
      timeOfDay: '08:00',
      localDate: localDate,
      status: status,
      doseQuantity: 1,
    );

/// [slot] with only its [status] changed — every other field (identity
/// included) carried over unchanged. Mirrors
/// `care_history_screen_test.dart`'s `_withStatus`.
CareTodaySlot _withStatus(CareTodaySlot slot, CareTodayStatus status) =>
    CareTodaySlot(
      careItemId: slot.careItemId,
      careScheduleId: slot.careScheduleId,
      category: slot.category,
      title: slot.title,
      note: slot.note,
      dose: slot.dose,
      timeOfDay: slot.timeOfDay,
      localDate: slot.localDate,
      status: status,
      doneTime: slot.doneTime,
      doseQuantity: slot.doseQuantity,
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
    DateTime? doneTime,
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
                _withStatus(
                  slot,
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
  SharedFoodItemController sharedFoodItem,
  GetLoggedDays getLoggedDays,
  WaterController water,
  BowelController bowel,
  VitalsController vitals,
  ExerciseController exercise,
  MenstrualController menstrual,
  WeightGoalController weightGoal,
  TrendController trend,
  HealthCalendarController healthCalendar,
}) testHealthControllers({
  MealRepository? mealRepository,
  FoodDictionaryRepository? foodDictionaryRepository,
}) {
  mealRepository ??= _FakeMealRepository();
  final dailyTargetRepository = _FakeDailyTargetRepository();
  foodDictionaryRepository ??= _FakeFoodDictionaryRepository();
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
    sharedFoodItem: SharedFoodItemController(
      CreateSharedFoodItem(foodDictionaryRepository),
      UpdateSharedFoodItem(foodDictionaryRepository),
    ),
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
  isAdmin: false,
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
  PushHealthController? pushHealthController,
  CareItemsController? careItemsController,
  CareTodayController? careTodayController,
  CareHistoryController? careHistoryController,
  CareHistoryController? careAdherenceController,
  FinanceController? financeController,

  /// Shared, mirroring main.dart, between the import controller (which
  /// bumps it), the health shell (which listens to it), and both
  /// [CareHistoryController] instances (which are injected with it, so an
  /// edit on `/care-history` bumps the trend tab's card too — design §D).
  /// Defaults to a fresh instance; pass one explicitly to inject it into a
  /// caller-supplied controller as well, so the two stay wired to the same
  /// revision.
  DataRevision? dataRevision,
  PendingDeepLinkStore? pendingDeepLinkStore,

  /// Back the health controllers with these fakes instead of the inert
  /// defaults — for tests that need the diet module to actually have a food
  /// to pick, or to observe what a meal save sent.
  MealRepository? mealRepository,
  FoodDictionaryRepository? foodDictionaryRepository,

  /// Pins (and lets a test advance) the "today" the day-keyed routes resolve.
  DateTime Function()? clock,
}) async {
  final resolvedLocaleController =
      localeController ?? await testLocaleController();
  final resolvedThemeController =
      themeController ?? await testThemeController();
  final resolvedSignOut = signOut ?? SignOut(authRepository);
  final resolvedSignUp = signUp ?? SignUp(authRepository);
  final resolvedFinanceController =
      financeController ??
      () {
        final repository = _FakeFinanceRepository();
        return FinanceController(
          GetFinanceMonth(repository),
          AddTransaction(repository),
          UpdateTransaction(repository),
          DeleteTransaction(repository),
          UpsertBudget(repository),
          DeleteBudget(repository),
        );
      }();
  final health = testHealthControllers(
    mealRepository: mealRepository,
    foodDictionaryRepository: foodDictionaryRepository,
  );
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
          ImportMenstrual(importRepository),
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
          EditCareSlot(_FakeCareHistoryRepository()),
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
      healthSharedFoodItemController: health.sharedFoodItem,
      healthGetLoggedDays: health.getLoggedDays,
      waterController: health.water,
      bowelController: health.bowel,
      vitalsController: health.vitals,
      exerciseController: health.exercise,
      menstrualController: health.menstrual,
      financeController: resolvedFinanceController,
      weightGoalController: health.weightGoal,
      trendController: health.trend,
      healthCalendarController: health.healthCalendar,
      // Not started (no timer): on the VM the stub reports no update, and
      // these tests don't exercise the update banner.
      pwaUpdateController: PwaUpdateController(const PwaUpdateImpl()),
      chaodaysImportController: resolvedChaodaysImportController,
      reminderSettingsController: resolvedReminderSettingsController,
      pushHealthController:
          pushHealthController ?? testPushHealthController(PushHealth.ok),
      careItemsController: resolvedCareItemsController,
      careTodayController: resolvedCareTodayController,
      careHistoryController: resolvedCareHistoryController,
      careAdherenceController: resolvedCareAdherenceController,
      // `resolvedDataRevision`, not the raw parameter: it is nullable now
      // that callers can inject one to share with their own controller.
      dataRevision: resolvedDataRevision,
      pendingDeepLinkStore:
          pendingDeepLinkStore ?? const PendingDeepLinkStoreImpl(),
      clock: clock ?? DateTime.now,
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
      'a URL-driven food dictionary route with no extra opens the dictionary',
      (tester) async {
        // The launcher shortcut is pure URL — none of the `extra` an in-app
        // navigation carries — so the route must supply the day and its meal
        // names itself rather than fall back to the diet day.
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
        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('food-search-field')), findsOneWidget);
      },
    );

    testWidgets(
      'the URL-driven dictionary waits for the day\'s record before taking its '
      'meal-name snapshot',
      (tester) async {
        // `FoodSearchScreen.mealNames` is a construction-time snapshot and the
        // route builder is not rebuilt when the controller later notifies — so
        // building it while the day is still in flight would freeze an empty
        // list in, and every snack would then be named the base name and
        // collide with the day's existing one.
        final today = dayString(DateTime.now());
        final gate = Completer<void>();
        final mealRepository = _FakeMealRepository(
          mealNamesByDay: {
            today: const ['breakfast', 'Snack'],
          },
          gate: gate.future,
        );
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
          mealRepository: mealRepository,
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet/dictionary');
        // Explicit pumps, not `pumpAndSettle`: the waiting state is a spinner,
        // which never settles.
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('food-search-field')), findsNothing);

        gate.complete();
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('food-search-field')), findsOneWidget);

        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(
            nextSnackName(const ['breakfast', 'Snack'], loc.dietSnackBaseName),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a failed load leaves the URL-driven dictionary recoverable, not spinning',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final mealRepository = _FakeMealRepository(
          fetchError: const DietFetchFailure('boom'),
        );
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          mealRepository: mealRepository,
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('dictionary-error-message')), findsOneWidget);
        expect(find.byKey(const Key('dictionary-sign-out-button')), findsOneWidget);
        // A failed cold start must not be a dead end. The AppBar (hence the
        // back arrow, since this route builds a stack) is present in every
        // pre-dictionary state, and the failure is retryable — signing out is
        // not a reasonable only-option for a transient network error.
        expect(find.byType(AppBar), findsOneWidget);
        final before = mealRepository.receivedDays.length;
        await tester.tap(find.byKey(const Key('dictionary-retry-button')));
        await tester.pumpAndSettle();
        expect(mealRepository.receivedDays.length, greaterThan(before));
      },
    );

    testWidgets(
      'a 401 while opening the URL-driven dictionary offers a sign-in-again exit',
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
          mealRepository: _FakeMealRepository(
            fetchError: const DietReauthenticationRequired(),
          ),
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('dictionary-sign-in-again-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the URL-driven dictionary uses TODAY\'s meal names even when the app was '
      'browsing an earlier day',
      (tester) async {
        // The shortcut records against today, but `todayController` is shared
        // with the diet day's day-nav and may be holding an earlier day. Nobody
        // else would trigger that reload, so the wrapper must trigger it itself
        // rather than wait (which would spin forever).
        final today = dayString(DateTime.now());
        final yesterday = dayString(
          DateUtils.addDaysToDate(DateTime.now(), -1),
        );
        final mealRepository = _FakeMealRepository(
          mealNamesByDay: {
            today: const ['breakfast', 'Snack'],
            yesterday: const [],
          },
        );
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
          mealRepository: mealRepository,
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        // Park the shared controller on yesterday first. `/health/diet` stays
        // in the stack, so the diet day's own State (and its mount-time reload)
        // is NOT re-run by the dictionary navigation below.
        router.go('/health/diet');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('food-search-field')), findsOneWidget);

        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        // Today already has a "Snack", so the option continues TODAY's series.
        // Yesterday's (empty) names would have produced the base name instead.
        expect(
          find.text(
            nextSnackName(const ['breakfast', 'Snack'], loc.dietSnackBaseName),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('choose-meal-snack')));
        await tester.pumpAndSettle();
        expect(mealRepository.createdDay, today);
      },
    );

    testWidgets(
      'a dictionary arriving mid-load does not hand back the day being replaced',
      (tester) async {
        // `dayMealsLog` still holds the OUTGOING day while someone else's load
        // is in flight. Recording it as the day to hand back would restore a
        // day the user has already navigated away from — the diet day would
        // then show a past day's records under today's header, and file food
        // added from there under today. Hence: return on `loading` BEFORE
        // capturing.
        final today = dayString(DateTime.now());
        final mealRepository = _GateOneDayMealRepository();
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
          mealRepository: mealRepository,
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        // Head back to today, but hold that fetch in flight.
        mealRepository.gatedDay = today;
        await tester.tap(find.byKey(const Key('day-nav-next')));
        await tester.pump();

        // The shortcut arrives mid-load.
        router.go('/health/diet/dictionary');
        await tester.pump();
        mealRepository.release();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('food-search-field')), findsOneWidget);

        router.go('/health/diet');
        await tester.pumpAndSettle();
        // Today — the day the user actually navigated to — not yesterday.
        expect(mealRepository.receivedDays.last, today);
      },
    );

    testWidgets(
      'a dictionary arriving while the diet day is already in error still hands '
      'the browsed day back',
      (tester) async {
        // `_returnDay` is captured BEFORE the error guard, because the diet day
        // can sit in `error` with `dayMealsLog` intact — the status changes,
        // the record does not. Reached here through a FAILED DAY SWITCH (a
        // failed mutation lands in the same state via `_mutate`). Note the
        // day asserted below is what `dayMealsLog` holds, which a failed switch
        // leaves one day behind `DietDayScreen._day` — that gap is the
        // "DietDayScreen self-sync" follow-up in design.md, not this test's
        // subject. What this test pins is that capturing at the takeover
        // instead would never run at all, leaving `dispose` to restore today.
        final yesterday = dayString(
          DateUtils.addDaysToDate(DateTime.now(), -1),
        );
        final mealRepository = _FailAfterFirstDaysMealRepository();
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
          mealRepository: mealRepository,
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        // Drive the controller into `error` BEFORE the dictionary mounts, with
        // `dayMealsLog` left holding yesterday — the state a failed mutation
        // leaves behind. The dictionary's own load then never even starts.
        mealRepository.failFromNowOn = true;
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dictionary-error-message')), findsOneWidget);

        router.go('/health/diet');
        await tester.pumpAndSettle();
        expect(mealRepository.receivedDays.last, yesterday);
      },
    );

    testWidgets(
      'the URL-driven dictionary survives midnight instead of spinning forever',
      (tester) async {
        // `day` comes from `_today`, a live value. `_requestedLoad` is one-shot,
        // so without the rollover handling the build would keep seeing
        // `log.day != widget.day` with nobody left to fix it. And the reload it
        // triggers must be post-frame: `load` notifies synchronously and the
        // TodayScreen below has a bare `setState` listener.
        var now = DateTime(2026, 7, 28, 23, 59);
        final today = dayString(now);
        final tomorrow = dayString(DateUtils.addDaysToDate(now, 1));
        final mealRepository = _FakeMealRepository();
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
          mealRepository: mealRepository,
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
          clock: () => now,
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet');
        await tester.pumpAndSettle();
        // Borrow a PAST day first, so the rollover has something it could
        // wrongly overwrite `_returnDay` with.
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();
        final borrowedDay = dayString(DateUtils.addDaysToDate(now, -1));

        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('food-search-field')), findsOneWidget);
        expect(mealRepository.receivedDays.last, today);

        // Cross midnight, then make go_router re-run the route builder — the
        // only thing that actually hands the screen a new `day`.
        now = DateTime(2026, 7, 29, 0, 1);
        router.push('/health/vitals');
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();

        // Still the dictionary, now on the new day — not a permanent spinner —
        // and the rollover reload did not throw during build.
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('food-search-field')), findsOneWidget);
        expect(mealRepository.receivedDays.last, tomorrow);

        // And the day to hand back is still the one BORROWED FROM THE USER —
        // the rollover must not overwrite it with the pre-midnight "today"
        // (that is what `_returnDay ??=` is for).
        router.go('/health/diet');
        await tester.pumpAndSettle();
        expect(mealRepository.receivedDays.last, borrowedDay);
      },
    );

    testWidgets(
      'leaving the URL-driven dictionary hands the browsed day back, so the '
      'diet day underneath is not left showing today under a past-day header',
      (tester) async {
        // The wrapper borrows the SHARED `todayController` to read today's meal
        // names. The diet day below keeps its own `_viewedDate`/`_day` and only
        // reloads on its own day-switch, so restoring today unconditionally
        // would leave it showing today's meals under yesterday's header — and
        // file food added from there under yesterday.
        final today = dayString(DateTime.now());
        final yesterday = dayString(
          DateUtils.addDaysToDate(DateTime.now(), -1),
        );
        final mealRepository = _FakeMealRepository(
          mealNamesByDay: {
            today: const ['ZZTodayOnlyMeal'],
            yesterday: const [],
          },
        );
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
          mealRepository: mealRepository,
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();
        router.go('/health/diet');
        await tester.pumpAndSettle();

        // Back on yesterday, in both directions: the last fetch asked for
        // yesterday, and today's meal is not on screen under yesterday's
        // header. Asserting only the header would pass while the list showed
        // today's records.
        expect(mealRepository.receivedDays.last, yesterday);
        expect(find.text('ZZTodayOnlyMeal'), findsNothing);
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.dietHistoryTitle), findsOneWidget);
      },
    );

    testWidgets(
      'leaving the URL-driven dictionary reloads the diet day, so what was just '
      'added is on screen',
      (tester) async {
        // The shortcut arrives via `go`, so the `true` the dictionary pops has
        // nobody to catch it (in-app it is an `await push<bool>`) — the wrapper
        // reloads on dispose instead.
        final today = dayString(DateTime.now());
        final mealRepository = _FakeMealRepository();
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
          mealRepository: mealRepository,
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();

        final loadsBeforeRecording = mealRepository.receivedDays
            .where((d) => d == today)
            .length;

        await tester.tap(find.byKey(const Key('choose-meal-dinner')));
        await tester.pumpAndSettle();

        expect(mealRepository.createdMeal, 'dinner');
        expect(find.byKey(const Key('diet-open-target')), findsOneWidget);
        expect(
          mealRepository.receivedDays.where((d) => d == today).length,
          greaterThan(loadsBeforeRecording),
        );
      },
    );

    testWidgets(
      'the URL-driven dictionary does not inherit an abandoned per-meal tray',
      (tester) async {
        // In-app, `_openDictionary` resets the shared CreateMealController
        // first; a URL arrival must do the same or the dictionary opens with
        // the abandoned tray's recording controls and its target meal.
        await tester.binding.setSurfaceSize(const Size(800, 1600));
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
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet');
        await tester.pumpAndSettle();

        // Start a per-meal entry and leave it unfinished.
        await tester.tap(find.byKey(const Key('add-snack')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('food-search-done-button')), findsOneWidget);

        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('food-search-field')), findsOneWidget);
        // An empty tray has no recording controls at all.
        expect(find.byKey(const Key('food-search-done-button')), findsNothing);
      },
    );

    testWidgets(
      'the diet day\'s dictionary entry opens the real dictionary route as a '
      'lookup for the day being browsed',
      (tester) async {
        // Drives the REAL router from lib/app.dart end to end, so a builder
        // that ignored `extra` — a target meal instead of none, today instead
        // of the browsed day, or no meal names — is caught here. A test-local
        // router only proves what the push carried, not what the route did
        // with it.
        final yesterday = dayString(
          DateUtils.addDaysToDate(DateTime.now(), -1),
        );
        final mealRepository = _FakeMealRepository(
          mealNamesByDay: {
            yesterday: const ['breakfast', 'Snack'],
          },
        );
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
          mealRepository: mealRepository,
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_note));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('hub-tile-diet')));
        await tester.pumpAndSettle();

        // Browse yesterday BEFORE opening the dictionary — recording against
        // today would pass even for a route that hard-codes the current day.
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        final loadsBeforeRecording = mealRepository.receivedDays
            .where((d) => d == yesterday)
            .length;

        await tester.tap(find.byKey(const Key('diet-open-dictionary')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        // Opened as the dictionary (no target meal): its own title, and with
        // an empty tray no recording controls at all.
        expect(find.text(loc.dietDictionaryTitle), findsOneWidget);
        expect(find.byKey(const Key('food-search-done-button')), findsNothing);
        expect(find.byKey(const Key('manual-entry-link')), findsNothing);

        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();

        // The snack option continues the browsed day's own series (it already
        // has "Snack"), so the day's meal names came across too.
        expect(
          find.text(
            nextSnackName(const ['breakfast', 'Snack'], loc.dietSnackBaseName),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('choose-meal-dinner')));
        await tester.pumpAndSettle();

        expect(mealRepository.createdMeal, 'dinner');
        expect(mealRepository.createdDay, yesterday);
        // …and the diet day the dictionary was opened from re-fetched itself,
        // so the meal just recorded is actually on screen.
        expect(
          mealRepository.receivedDays.where((d) => d == yesterday).length,
          loadsBeforeRecording + 1,
        );
      },
    );

    testWidgets(
      'a vitals URL carrying ?add=glucose starts a glucose reading',
      (tester) async {
        // A behavior test, NOT a proof of the hash URL strategy: a widget test
        // has no web URL strategy at all. That half rests on Flutter's
        // `HashUrlStrategy.getPath()` returning everything after `#` (query
        // included), which go_router parses into `state.uri`.
        await tester.binding.setSurfaceSize(const Size(800, 1600));
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

        GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        ).go('/health/vitals?add=glucose');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vitals-glucose-value-0')), findsOneWidget);
        expect(find.byKey(const Key('vitals-glucose-value-1')), findsNothing);
      },
    );

    testWidgets(
      'every manifest shortcut URL actually lands on its destination',
      (tester) async {
        // Guards the manifest against the failure mode section 2 fixed: a
        // route that exists but bounces because it is missing its `extra`. So
        // this navigates for real rather than comparing strings. The two
        // vitals shortcuts land on the SAME screen, so each also asserts its
        // own reading count — otherwise nothing would tell them apart.
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final manifest =
            jsonDecode(File('web/manifest.json').readAsStringSync())
                as Map<String, dynamic>;
        final shortcuts = (manifest['shortcuts'] as List).cast<Map<String, dynamic>>();
        expect(shortcuts, hasLength(4));
        // Each shortcut must be a DISTINCT destination. Without this, pointing
        // two of them at the same url still passes the per-url loop below —
        // and "two shortcuts open the same screen" is exactly what D2b fixed.
        final urls = shortcuts.map((s) => s['url'] as String).toList();
        expect(urls.toSet(), hasLength(urls.length));

        // ORDER IS LOAD-BEARING. Chrome adds its own "site settings" row to the
        // long-press menu, so only the FIRST THREE shortcuts actually show on
        // the device — verified on a real install, where the fourth was simply
        // absent. Blood pressure is the one that loses, because it shares the
        // vitals screen with glucose and is one scroll away once you are there.
        expect(urls.take(3), [
          '/#/health/vitals?add=glucose',
          '/#/health/diet',
          '/#/health/diet/dictionary',
        ]);

        // Every shortcut needs its OWN icon file, and the file has to exist.
        // Launchers do not fall back to the app icon when `icons` is missing —
        // they render a blank placeholder, which is what shipped first time and
        // only showed up on a real device.
        final iconPaths = <String>[];
        for (final shortcut in shortcuts) {
          final icons = (shortcut['icons'] as List?)
              ?.cast<Map<String, dynamic>>();
          expect(
            icons,
            isNotNull,
            reason: 'shortcut ${shortcut['url']} declares no icon',
          );
          expect(icons, isNotEmpty);
          final src = icons!.first['src'] as String;
          expect(
            File('web/$src').existsSync(),
            isTrue,
            reason: 'web/$src is declared but missing',
          );
          iconPaths.add(src);
        }
        expect(iconPaths.toSet(), hasLength(iconPaths.length));

        final expectations = <String, void Function()>{
          '/health/diet/dictionary': () {
            expect(find.byKey(const Key('food-search-field')), findsOneWidget);
          },
          '/health/diet': () {
            expect(find.byKey(const Key('diet-open-target')), findsOneWidget);
          },
          '/health/vitals?add=glucose': () {
            expect(
              find.byKey(const Key('vitals-glucose-value-0')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('vitals-glucose-value-1')),
              findsNothing,
            );
          },
          '/health/vitals?add=bp': () {
            expect(
              find.byKey(const Key('vitals-bp-systolic-0')),
              findsOneWidget,
            );
            expect(find.byKey(const Key('vitals-bp-systolic-1')), findsNothing);
            // …and the glucose reading the previous shortcut started is not
            // added a second time (the two share one screen State).
            expect(
              find.byKey(const Key('vitals-glucose-value-1')),
              findsNothing,
            );
          },
        };

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
          foodDictionaryRepository: _FakeFoodDictionaryRepository(
            foods: [_riceItem()],
          ),
        );
        await tester.pumpAndSettle();

        // Resolved ONCE: after the first navigation the health tile is gone
        // from the tree, so re-reading the router from it would fail.
        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );

        for (final shortcut in shortcuts) {
          final url = shortcut['url'] as String;
          expect(url, startsWith('/#'), reason: 'the app uses hash URLs');
          final location = url.substring(2);
          expect(
            expectations.containsKey(location),
            isTrue,
            reason: 'no expectation declared for shortcut $url',
          );

          router.go(location);
          await tester.pumpAndSettle();
          expectations[location]!();
        }
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
      "the overview's next-period card opens the menstrual tracker through "
      'the real router, and back returns to the overview',
      (tester) async {
        // Driven through the app's own router: the tracker is a nested child
        // of /health, so the shortcut has to push '/health/menstrual' —
        // '/menstrual' matches nothing, and the router has no errorBuilder,
        // so it would land on go_router's built-in not-found page.
        //
        // A taller surface than the default viewport: the care and goal cards
        // above it would otherwise leave the card offstage and untappable.
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

        await tester.tap(find.byKey(const Key('next-period-card')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('menstrual-add-button')), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        // Back lands on the health module's overview, not the grid.
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byKey(const Key('next-period-card')), findsOneWidget);
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
        // The care record must be dated the real "today": CareHistoryScreen
        // (wired in app.dart, unlike the isolated screen test) gets no
        // injected `clock` override, so it falls back to its own default
        // (`DateTime.now`) to decide which slots are editable (design §D) —
        // a fixed past literal here would now correctly read as read-only.
        final now = DateTime.now();
        final todayString = dayString(now);
        // One shared repository and one shared DataRevision across both
        // CareHistoryController instances, mirroring main.dart.
        final careHistoryRepository = _MutableCareHistoryRepository([
          CareHistoryDay(
            date: todayString,
            slots: [_careSlot(CareTodayStatus.missed, localDate: todayString)],
          ),
        ]);
        final dataRevision = DataRevision();
        CareHistoryController careController(int spanDays) =>
            CareHistoryController(
              GetCareHistory(careHistoryRepository),
              EditCareSlot(careHistoryRepository),
              dataRevision,
              spanDays: spanDays,
              clock: () => now,
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
          find.byKey(Key('care-history-slot-sch-1-$todayString-08:00')),
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

  group('App admin entry points', () {
    testWidgets(
      'entering the dictionary deep link before the profile has loaded shows '
      'admin entry points once it resolves',
      (tester) async {
        final adminProfile = UserProfile(
          id: 'admin-1',
          firebaseUid: 'firebase-admin',
          email: 'admin@example.com',
          displayName: 'Admin',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: true,
        );
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(adminProfile);
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
        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        // The launcher-shortcut path (`_UrlDictionaryScreen`) never goes
        // through `_AuthenticatedHome.initState`, so without `ensureLoaded`
        // triggered from `FoodSearchScreen.initState` (design.md D2) the
        // profile — and so the admin entry point — would never load here.
        expect(find.byKey(const Key('food-search-create-button')), findsOneWidget);
      },
    );

    testWidgets(
      'signing out then signing in as a non-admin shows no admin entry point',
      (tester) async {
        final adminProfile = UserProfile(
          id: 'admin-1',
          firebaseUid: 'firebase-admin',
          email: 'admin@example.com',
          displayName: 'Admin',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: true,
        );
        final nonAdminProfile = UserProfile(
          id: 'user-2',
          firebaseUid: 'firebase-user-2',
          email: 'user2@example.com',
          displayName: 'Non Admin',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = _SwitchableProfileRepository(adminProfile);
        final homeController = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: homeController,
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-tile'))),
        );
        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('food-search-create-button')), findsOneWidget);

        // Sign out (reset fires from app.dart's auth listener — design.md
        // D2/2.5), then sign in as a non-admin. Without the reset, the new
        // user would inherit the previous (admin) user's `isAdmin`.
        await authRepository.signOut();
        await tester.pumpAndSettle();
        profileRepository.profile = nonAdminProfile;
        await authRepository.signIn(
          FakeAuthRepository.validEmail,
          FakeAuthRepository.validPassword,
        );
        await tester.pumpAndSettle();

        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('food-search-create-button')), findsNothing);
      },
    );
  });
}

class _SwitchableProfileRepository implements ProfileRepository {
  UserProfile profile;

  _SwitchableProfileRepository(this.profile);

  @override
  Future<UserProfile> getProfile(String idToken) async => profile;
}
