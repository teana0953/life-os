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
import 'contexts/health/presentation/create_meal_controller.dart';
import 'contexts/health/presentation/daily_target_controller.dart';
import 'contexts/health/presentation/dictionary_controller.dart';
import 'contexts/health/presentation/today_controller.dart';
import 'contexts/user/application/get_profile.dart';
import 'contexts/user/infrastructure/http_profile_repository.dart';
import 'contexts/user/presentation/home_controller.dart';
import 'firebase_options.dart';
import 'shared/config.dart';
import 'shared/i18n/locale_controller.dart';
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
    ),
  );
}
