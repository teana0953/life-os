import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/delete_entry.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_day_diet_log.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/application/log_manual_entry.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/application/update_food_entry.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/edit_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/manual_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

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

class _FakeDietLogRepository implements DietLogRepository {
  @override
  Future<FoodEntry> logFromDictionary(
    String idToken, {
    required String day,
    required String meal,
    required String foodItemId,
    double? quantity,
    double? grams,
    DateTime? eatenAt,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<FoodEntry> logManualEntry(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    return DayDietLog.fromJson({
      'day': day,
      'meals': [],
      'totals': {'carbG': 0, 'proteinG': 0, 'fatG': 0, 'sugarG': 0, 'fiberG': 0, 'kcal': 0},
    });
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {}

  @override
  Future<FoodEntry> updateEntry(
    String idToken,
    String entryId, {
    String? name,
    String? meal,
    DateTime? eatenAt,
    Portions? portions,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
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

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> getProfile(String idToken) async => UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'test@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Future<HomeController> _pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = HomeController(
    GetProfile(_FakeProfileRepository()),
    SignOut(_FakeAuthRepository()),
  );
  await controller.load('token-123');
  final localeController = await testLocaleController();
  SharedPreferences.setMockInitialValues({});
  final themeController = ThemeController(await SharedPreferences.getInstance());
  final dietLogRepository = _FakeDietLogRepository();
  final dailyTargetRepository = _FakeDailyTargetRepository();
  final foodDictionaryRepository = _FakeFoodDictionaryRepository();
  await tester.pumpWidget(
    l10nTestApp(
      theme: lightTheme,
      home: HomeScreen(
        controller: controller,
        localeController: localeController,
        themeController: themeController,
        signOut: SignOut(_FakeAuthRepository()),
        authRepository: _FakeAuthRepository(),
        healthTodayController: TodayController(
          GetDayDietLog(dietLogRepository),
          GetDailyTargetWithRemaining(dailyTargetRepository),
        ),
        healthDictionaryController: DictionaryController(
          SearchDictionary(foodDictionaryRepository),
          ListFavorites(foodDictionaryRepository),
          FavoriteFood(foodDictionaryRepository),
          UnfavoriteFood(foodDictionaryRepository),
        ),
        healthDailyTargetController: DailyTargetController(
          GetDailyTargetWithRemaining(dailyTargetRepository),
          SetDailyTarget(dailyTargetRepository),
        ),
        healthLogEntryController: LogEntryController(
          LogFoodFromDictionary(dietLogRepository),
        ),
        healthManualEntryController: ManualEntryController(
          LogManualEntry(dietLogRepository),
        ),
        healthEditEntryController: EditEntryController(
          UpdateFoodEntry(dietLogRepository),
          DeleteEntry(dietLogRepository),
        ),
        healthGetLoggedDays: GetLoggedDays(dietLogRepository),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

SliverGridDelegateWithFixedCrossAxisCount _gridDelegate(WidgetTester tester) {
  final gridView = tester.widget<GridView>(find.byKey(const Key('spaces-grid')));
  return gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
}

void main() {
  group('HomeScreen responsive layout', () {
    testWidgets('narrow phone width: spaces grid uses fewer columns, no overflow', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(360, 800));

      expect(tester.takeException(), isNull);
      expect(_gridDelegate(tester).crossAxisCount, 2);
    });

    testWidgets('wide desktop width: spaces grid uses more columns', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(1200, 800));

      expect(tester.takeException(), isNull);
      expect(_gridDelegate(tester).crossAxisCount, 4);
    });
  });
}
