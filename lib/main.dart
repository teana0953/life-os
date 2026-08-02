import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'contexts/auth/application/sign_in.dart';
import 'contexts/auth/application/sign_out.dart';
import 'contexts/auth/application/sign_up.dart';
import 'contexts/auth/infrastructure/firebase_auth_repository.dart';
import 'contexts/auth/presentation/login_controller.dart';
import 'contexts/body_profile/application/get_body_profile.dart';
import 'contexts/body_profile/application/get_weight_goal.dart';
import 'contexts/body_profile/application/set_body_profile.dart';
import 'contexts/body_profile/infrastructure/http_body_profile_repository.dart';
import 'contexts/body_profile/presentation/weight_goal_controller.dart';
import 'contexts/health_calendar/application/get_health_calendar.dart';
import 'contexts/health_calendar/infrastructure/http_health_calendar_repository.dart';
import 'contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'contexts/bowel/application/get_bowel_day.dart';
import 'contexts/bowel/application/save_bowel_day.dart';
import 'contexts/bowel/infrastructure/http_bowel_repository.dart';
import 'contexts/bowel/presentation/bowel_controller.dart';
import 'contexts/exercise/application/add_exercise_entry.dart';
import 'contexts/exercise/application/delete_exercise_entry.dart';
import 'contexts/exercise/application/get_exercise_day.dart';
import 'contexts/exercise/application/list_exercise_activities.dart';
import 'contexts/exercise/infrastructure/http_exercise_repository.dart';
import 'contexts/exercise/presentation/exercise_controller.dart';
import 'contexts/finance/application/add_transaction.dart';
import 'contexts/finance/application/delete_budget.dart';
import 'contexts/finance/application/delete_transaction.dart';
import 'contexts/finance/application/get_finance_month.dart';
import 'contexts/finance/application/update_transaction.dart';
import 'contexts/finance/application/networth_use_cases.dart';
import 'contexts/finance/application/upsert_budget.dart';
import 'contexts/finance/infrastructure/http_finance_repository.dart';
import 'contexts/finance/presentation/finance_controller.dart';
import 'contexts/finance/presentation/networth_controller.dart';
import 'contexts/health/application/change_meal_time.dart';
import 'contexts/health/application/create_meal.dart';
import 'contexts/health/application/create_shared_food_item.dart';
import 'contexts/health/application/delete_meal.dart';
import 'contexts/health/application/delete_meal_item.dart';
import 'contexts/health/application/edit_meal_item.dart';
import 'contexts/health/application/favorite_food.dart';
import 'contexts/health/application/get_day_meals.dart';
import 'contexts/health/application/get_daily_target_with_remaining.dart';
import 'contexts/health/application/get_logged_days.dart';
import 'contexts/health/application/list_favorites.dart';
import 'contexts/health/application/search_dictionary.dart';
import 'contexts/health/application/set_daily_target.dart';
import 'contexts/health/application/unfavorite_food.dart';
import 'contexts/health/application/update_shared_food_item.dart';
import 'contexts/health/infrastructure/http_daily_target_repository.dart';
import 'contexts/health/infrastructure/http_food_dictionary_repository.dart';
import 'contexts/health/infrastructure/http_meal_repository.dart';
import 'contexts/import/application/import_bowel.dart';
import 'contexts/import/application/import_diet.dart';
import 'contexts/import/application/import_diet_target.dart';
import 'contexts/import/application/import_menstrual.dart';
import 'contexts/import/application/import_water.dart';
import 'contexts/import/application/import_weight.dart';
import 'contexts/import/infrastructure/http_import_repository.dart';
import 'contexts/import/presentation/chaodays_import_controller.dart';
import 'contexts/notifications/application/care_items.dart';
import 'contexts/notifications/application/care_today.dart';
import 'contexts/notifications/application/edit_care_slot.dart';
import 'contexts/notifications/application/enable_reminders.dart';
import 'contexts/notifications/application/get_care_history.dart';
import 'contexts/notifications/application/send_test_push.dart';
import 'contexts/notifications/infrastructure/browser_web_push_gateway.dart';
import 'contexts/notifications/infrastructure/http_care_history_repository.dart';
import 'contexts/notifications/infrastructure/http_care_repository.dart';
import 'contexts/notifications/infrastructure/http_care_today_repository.dart';
import 'contexts/notifications/infrastructure/http_push_repository.dart';
import 'contexts/notifications/presentation/care_history_controller.dart';
import 'contexts/notifications/presentation/care_items_controller.dart';
import 'contexts/notifications/presentation/care_today_controller.dart';
import 'contexts/notifications/presentation/push_health_controller.dart';
import 'contexts/notifications/presentation/reminder_settings_controller.dart';
import 'contexts/social/application/friend_use_cases.dart';
import 'contexts/social/application/invite_use_cases.dart';
import 'contexts/social/infrastructure/http_social_repository.dart';
import 'contexts/health/presentation/create_meal_controller.dart';
import 'contexts/health/presentation/daily_target_controller.dart';
import 'contexts/health/presentation/dictionary_controller.dart';
import 'contexts/health/presentation/shared_food_item_controller.dart';
import 'contexts/health/presentation/today_controller.dart';
import 'contexts/hydration/application/add_water.dart';
import 'contexts/hydration/application/get_water_day.dart';
import 'contexts/hydration/application/set_water_target.dart';
import 'contexts/hydration/infrastructure/http_water_repository.dart';
import 'contexts/hydration/presentation/water_controller.dart';
import 'contexts/menstrual/application/add_period.dart';
import 'contexts/menstrual/application/delete_period.dart';
import 'contexts/menstrual/application/get_menstrual_overview.dart';
import 'contexts/menstrual/application/update_period.dart';
import 'contexts/menstrual/infrastructure/http_menstrual_repository.dart';
import 'contexts/menstrual/presentation/menstrual_controller.dart';
import 'contexts/vitals/application/get_vitals_day.dart';
import 'contexts/vitals/application/get_vitals_trends.dart';
import 'contexts/vitals/application/save_vitals_day.dart';
import 'contexts/vitals/infrastructure/http_vitals_repository.dart';
import 'contexts/vitals/presentation/trend_controller.dart';
import 'contexts/vitals/presentation/vitals_controller.dart';
import 'contexts/user/application/get_profile.dart';
import 'contexts/user/infrastructure/http_profile_repository.dart';
import 'contexts/user/presentation/home_controller.dart';
import 'firebase_options.dart';
import 'shared/config.dart';
import 'shared/data_revision.dart';
import 'shared/i18n/locale_controller.dart';
import 'shared/pwa/pending_deep_link.dart';
import 'shared/pwa/pwa_update.dart';
import 'shared/pwa/pwa_update_controller.dart';
import 'shared/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authRepository = FirebaseAuthRepository(firebase_auth.FirebaseAuth.instance);
  final profileRepository = HttpProfileRepository(
    baseUrl: apiBaseUrl,
    client: http.Client(),
  );

  final signOut = SignOut(authRepository);
  final signUp = SignUp(authRepository);
  final loginController = LoginController(SignIn(authRepository));
  final homeController = HomeController(GetProfile(profileRepository), signOut);
  final prefs = await SharedPreferences.getInstance();
  final localeController = LocaleController(prefs);
  final themeController = ThemeController(prefs);

  final httpClient = http.Client();
  final foodDictionaryRepository = HttpFoodDictionaryRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final mealRepository = HttpMealRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final dailyTargetRepository = HttpDailyTargetRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final healthTodayController = TodayController(
    GetDayMeals(mealRepository),
    GetDailyTargetWithRemaining(dailyTargetRepository),
    EditMealItem(mealRepository),
    DeleteMealItem(mealRepository),
    ChangeMealTime(mealRepository),
    DeleteMeal(mealRepository),
  );
  final healthDictionaryController = DictionaryController(
    SearchDictionary(foodDictionaryRepository),
    ListFavorites(foodDictionaryRepository),
    FavoriteFood(foodDictionaryRepository),
    UnfavoriteFood(foodDictionaryRepository),
  );
  final healthDailyTargetController = DailyTargetController(
    GetDailyTargetWithRemaining(dailyTargetRepository),
    SetDailyTarget(dailyTargetRepository),
  );
  final healthCreateMealController = CreateMealController(
    CreateMeal(mealRepository),
  );
  final healthSharedFoodItemController = SharedFoodItemController(
    CreateSharedFoodItem(foodDictionaryRepository),
    UpdateSharedFoodItem(foodDictionaryRepository),
  );
  final healthGetLoggedDays = GetLoggedDays(mealRepository);
  final waterRepository = HttpWaterRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final waterController = WaterController(
    GetWaterDay(waterRepository),
    AddWater(waterRepository),
    SetWaterTarget(waterRepository),
  );
  final bowelRepository = HttpBowelRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final bowelController = BowelController(
    GetBowelDay(bowelRepository),
    SaveBowelDay(bowelRepository),
  );
  final vitalsRepository = HttpVitalsRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final vitalsController = VitalsController(
    GetVitalsDay(vitalsRepository),
    SaveVitalsDay(vitalsRepository),
  );
  final trendController = TrendController(GetVitalsTrends(vitalsRepository));
  final exerciseRepository = HttpExerciseRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final exerciseController = ExerciseController(
    ListExerciseActivities(exerciseRepository),
    GetExerciseDay(exerciseRepository),
    AddExerciseEntry(exerciseRepository),
    DeleteExerciseEntry(exerciseRepository),
  );
  final menstrualRepository = HttpMenstrualRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final menstrualController = MenstrualController(
    GetMenstrualOverview(menstrualRepository),
    AddPeriod(menstrualRepository),
    UpdatePeriod(menstrualRepository),
    DeletePeriod(menstrualRepository),
  );
  final financeRepository = HttpFinanceRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final financeController = FinanceController(
    GetFinanceMonth(financeRepository),
    AddTransaction(financeRepository),
    UpdateTransaction(financeRepository),
    DeleteTransaction(financeRepository),
    UpsertBudget(financeRepository),
    DeleteBudget(financeRepository),
  );
  final netWorthController = NetWorthController(
    ListNetWorthAccounts(financeRepository),
    CreateNetWorthAccount(financeRepository),
    UpdateNetWorthAccount(financeRepository),
    UpsertSnapshot(financeRepository),
    GetMonthlyNetWorth(financeRepository),
    GetNetWorthTrend(financeRepository),
  );
  final bodyProfileRepository = HttpBodyProfileRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final weightGoalController = WeightGoalController(
    GetWeightGoal(bodyProfileRepository),
    GetBodyProfile(bodyProfileRepository),
    SetBodyProfile(bodyProfileRepository),
  );
  final healthCalendarController = HealthCalendarController(
    GetHealthCalendar(
      HttpHealthCalendarRepository(baseUrl: apiBaseUrl, client: httpClient),
    ),
  );
  final pwaUpdateController = PwaUpdateController(const PwaUpdateImpl())
    ..start();
  final dataRevision = DataRevision();
  final importRepository = HttpImportRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final chaodaysImportController = ChaodaysImportController(
    ImportWeight(importRepository),
    ImportDiet(importRepository),
    ImportWater(importRepository),
    ImportBowel(importRepository),
    ImportDietTarget(importRepository),
    ImportMenstrual(importRepository),
    dataRevision,
  );
  final pushRepository = HttpPushRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  const webPushGateway = BrowserWebPushGateway();
  // One instance, shared with the push-health controller below: both re-run
  // the same idempotent grant → subscribe → save flow.
  final enableReminders = EnableReminders(pushRepository, webPushGateway);
  final reminderSettingsController = ReminderSettingsController(
    webPushGateway,
    enableReminders,
    SendTestPush(pushRepository),
  );
  // Never `check()`ed here: it subscribes to `authStateChanges` itself, and a
  // check at start would find no user (restoring a persisted sign-in on web is
  // asynchronous) and never run again.
  final pushHealthController = PushHealthController(
    gateway: webPushGateway,
    enableReminders: enableReminders,
    authRepository: authRepository,
    reminderSettingsController: reminderSettingsController,
  );
  final careItemRepository = HttpCareRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final careItemsController = CareItemsController(
    ListCareItems(careItemRepository),
    CreateCareItem(careItemRepository),
    UpdateCareItem(careItemRepository),
    DeleteCareItem(careItemRepository),
  );
  final careTodayRepository = HttpCareTodayRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final careHistoryRepository = HttpCareHistoryRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final careTodayController = CareTodayController(
    GetCareToday(careTodayRepository),
    MarkCareDone(careTodayRepository),
    MarkCareSkipped(careTodayRepository),
    EditCareSlot(careHistoryRepository),
  );
  // 30 days, matching the trend tab's adherence card below: the card links
  // straight here, and a user arriving from a missed day it showed must not
  // have to widen the period before that day is even in range.
  final careHistoryController = CareHistoryController(
    GetCareHistory(careHistoryRepository),
    EditCareSlot(careHistoryRepository),
    dataRevision,
    spanDays: 30,
  );
  // The trend tab's care adherence card gets its own controller instance
  // (design §B) — sharing the same (stateless) HttpCareHistoryRepository and
  // the same DataRevision as careHistoryController, but its own `spanDays`
  // so the two periods don't fight over shared state (they start at the same
  // 30 days; each moves independently from there).
  final careAdherenceController = CareHistoryController(
    GetCareHistory(careHistoryRepository),
    EditCareSlot(careHistoryRepository),
    dataRevision,
    spanDays: 30,
  );

  // Stateless only (design D9): `/friends`/`/invite` build their own
  // controllers per-screen, so nothing social lives here as a singleton.
  final socialRepository = HttpSocialRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  final listFriends = ListFriends(socialRepository);
  final removeFriend = RemoveFriend(socialRepository);
  final createInvite = CreateInvite(socialRepository);
  final listInvites = ListInvites(socialRepository);
  final revokeInvite = RevokeInvite(socialRepository);
  final previewInvite = PreviewInvite(socialRepository);
  final acceptInvite = AcceptInvite(socialRepository);

  runApp(
    App(
      authRepository: authRepository,
      loginController: loginController,
      homeController: homeController,
      localeController: localeController,
      themeController: themeController,
      signOut: signOut,
      signUp: signUp,
      healthTodayController: healthTodayController,
      healthDictionaryController: healthDictionaryController,
      healthDailyTargetController: healthDailyTargetController,
      healthCreateMealController: healthCreateMealController,
      healthSharedFoodItemController: healthSharedFoodItemController,
      healthGetLoggedDays: healthGetLoggedDays,
      waterController: waterController,
      bowelController: bowelController,
      vitalsController: vitalsController,
      exerciseController: exerciseController,
      menstrualController: menstrualController,
      financeController: financeController,
      netWorthController: netWorthController,
      weightGoalController: weightGoalController,
      trendController: trendController,
      healthCalendarController: healthCalendarController,
      pwaUpdateController: pwaUpdateController,
      chaodaysImportController: chaodaysImportController,
      reminderSettingsController: reminderSettingsController,
      listFriends: listFriends,
      removeFriend: removeFriend,
      createInvite: createInvite,
      listInvites: listInvites,
      revokeInvite: revokeInvite,
      previewInvite: previewInvite,
      acceptInvite: acceptInvite,
      pushHealthController: pushHealthController,
      careItemsController: careItemsController,
      careTodayController: careTodayController,
      careHistoryController: careHistoryController,
      careAdherenceController: careAdherenceController,
      dataRevision: dataRevision,
      pendingDeepLinkStore: const PendingDeepLinkStoreImpl(),
    ),
  );
}
