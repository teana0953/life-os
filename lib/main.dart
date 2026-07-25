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
import 'contexts/health/application/change_meal_time.dart';
import 'contexts/health/application/create_meal.dart';
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
import 'contexts/health/infrastructure/http_daily_target_repository.dart';
import 'contexts/health/infrastructure/http_food_dictionary_repository.dart';
import 'contexts/health/infrastructure/http_meal_repository.dart';
import 'contexts/import/application/import_bowel.dart';
import 'contexts/import/application/import_diet.dart';
import 'contexts/import/application/import_diet_target.dart';
import 'contexts/import/application/import_water.dart';
import 'contexts/import/application/import_weight.dart';
import 'contexts/import/infrastructure/http_import_repository.dart';
import 'contexts/import/presentation/chaodays_import_controller.dart';
import 'contexts/notifications/application/care_items.dart';
import 'contexts/notifications/application/care_today.dart';
import 'contexts/notifications/application/enable_reminders.dart';
import 'contexts/notifications/application/send_test_push.dart';
import 'contexts/notifications/infrastructure/browser_web_push_gateway.dart';
import 'contexts/notifications/infrastructure/http_care_repository.dart';
import 'contexts/notifications/infrastructure/http_care_today_repository.dart';
import 'contexts/notifications/infrastructure/http_push_repository.dart';
import 'contexts/notifications/presentation/care_items_controller.dart';
import 'contexts/notifications/presentation/care_today_controller.dart';
import 'contexts/notifications/presentation/reminder_settings_controller.dart';
import 'contexts/health/presentation/create_meal_controller.dart';
import 'contexts/health/presentation/daily_target_controller.dart';
import 'contexts/health/presentation/dictionary_controller.dart';
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
    dataRevision,
  );
  final pushRepository = HttpPushRepository(
    baseUrl: apiBaseUrl,
    client: httpClient,
  );
  const webPushGateway = BrowserWebPushGateway();
  final reminderSettingsController = ReminderSettingsController(
    webPushGateway,
    EnableReminders(pushRepository, webPushGateway),
    SendTestPush(pushRepository),
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
  final careTodayController = CareTodayController(
    GetCareToday(careTodayRepository),
    MarkCareDone(careTodayRepository),
    MarkCareSkipped(careTodayRepository),
  );

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
      healthGetLoggedDays: healthGetLoggedDays,
      waterController: waterController,
      bowelController: bowelController,
      vitalsController: vitalsController,
      exerciseController: exerciseController,
      menstrualController: menstrualController,
      weightGoalController: weightGoalController,
      trendController: trendController,
      healthCalendarController: healthCalendarController,
      pwaUpdateController: pwaUpdateController,
      chaodaysImportController: chaodaysImportController,
      reminderSettingsController: reminderSettingsController,
      careItemsController: careItemsController,
      careTodayController: careTodayController,
      dataRevision: dataRevision,
    ),
  );
}
