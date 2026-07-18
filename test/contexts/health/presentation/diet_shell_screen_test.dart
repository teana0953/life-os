import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_day_diet_log.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/application/log_manual_entry.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/diet_shell_screen.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/log_entry_screen.dart';
import 'package:life_os/contexts/health/presentation/manual_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/manual_entry_screen.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

class FakeDietLogRepository implements DietLogRepository {
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
    return FoodEntry.fromJson({
      'id': 'entry-1',
      'day': day,
      'meal': meal,
      'name': 'food',
      'photo_ref': null,
      'source': 'dict',
      'unclassified': false,
      'carb_g': 0,
      'protein_g': 0,
      'fat_g': 0,
      'sugar_g': 0,
      'fiber_g': 0,
      'kcal': 0,
      'staple': 0,
      'meat': 0,
      'fruit': 0,
      'veg': 0,
      'eaten_at': DateTime.now().toUtc().toIso8601String(),
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  int getDayLogCallCount = 0;

  @override
  Future<FoodEntry> logManualEntry(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
  }) async {
    return FoodEntry.fromJson({
      'id': 'manual-entry-1',
      'day': day,
      'meal': meal,
      'name': name,
      'photo_ref': null,
      'source': 'manual',
      'unclassified': false,
      'carb_g': 0,
      'protein_g': 0,
      'fat_g': 0,
      'sugar_g': 0,
      'fiber_g': 0,
      'kcal': 0,
      'staple': portions.staple,
      'meat': portions.meat,
      'fruit': portions.fruit,
      'veg': portions.veg,
      'eaten_at': eatenAt.toUtc().toIso8601String(),
      'logged_at': eatenAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    getDayLogCallCount++;
    return DayDietLog.fromJson({
      'day': day,
      'meals': [],
      'totals': {'carbG': 0, 'proteinG': 0, 'fatG': 0, 'sugarG': 0, 'fiberG': 0, 'kcal': 0},
    });
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {}
}

class FakeDailyTargetRepository implements DailyTargetRepository {
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

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [
    FoodItem.fromJson({
      'id': 'rice-1',
      'owner_user_id': null,
      'name': '飯/1碗',
      'carb_g': 60,
      'protein_g': 4,
      'fat_g': 0.5,
      'sugar_g': 0,
      'fiber_g': 1,
      'kcal': 280,
      'staple': 4,
      'meat': 0,
      'fruit': 0,
      'veg': 0,
      'base_grams': null,
    }),
  ];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}
}

Future<FakeDietLogRepository> _pumpShell(WidgetTester tester) async {
  final dietLogRepository = FakeDietLogRepository();
  final dailyTargetRepository = FakeDailyTargetRepository();
  final foodDictionaryRepository = FakeFoodDictionaryRepository();

  await tester.pumpWidget(
    l10nTestApp(
      home: DietShellScreen(
        authRepository: FakeAuthRepository(),
        todayController: TodayController(
          GetDayDietLog(dietLogRepository),
          GetDailyTargetWithRemaining(dailyTargetRepository),
        ),
        dictionaryController: DictionaryController(
          SearchDictionary(foodDictionaryRepository),
          ListFavorites(foodDictionaryRepository),
          FavoriteFood(foodDictionaryRepository),
          UnfavoriteFood(foodDictionaryRepository),
        ),
        dailyTargetController: DailyTargetController(
          GetDailyTargetWithRemaining(dailyTargetRepository),
          SetDailyTarget(dailyTargetRepository),
        ),
        logEntryController: LogEntryController(
          LogFoodFromDictionary(dietLogRepository),
        ),
        manualEntryController: ManualEntryController(
          LogManualEntry(dietLogRepository),
        ),
        clock: () => DateTime.utc(2026, 7, 18, 9),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return dietLogRepository;
}

void main() {
  group('DietShellScreen', () {
    testWidgets('shows the Today section by default', (tester) async {
      await _pumpShell(tester);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietTabToday), findsWidgets);
    });

    testWidgets('switching to Dictionary shows the dictionary section', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(loc.dietTabDictionary));
      await tester.pumpAndSettle();

      expect(find.text('飯/1碗'), findsOneWidget);
    });

    testWidgets('switching to Target shows the daily target section', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(loc.dietTabTarget));
      await tester.pumpAndSettle();

      expect(find.text(loc.dietSetTargetTitle), findsOneWidget);
    });

    testWidgets('selecting a dictionary item opens the log-entry screen', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(loc.dietTabDictionary));
      await tester.pumpAndSettle();
      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(find.byType(LogEntryScreen), findsOneWidget);
    });

    testWidgets(
      'the manual-entry affordance on Dictionary opens the manual-entry screen',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.text(loc.dietTabDictionary));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('dictionary-manual-entry-button')));
        await tester.pumpAndSettle();

        expect(find.byType(ManualEntryScreen), findsOneWidget);
      },
    );

    testWidgets(
      'saving a manual entry reloads Today',
      (tester) async {
        final dietLogRepository = await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));
        final loadsBeforeSave = dietLogRepository.getDayLogCallCount;

        await tester.tap(find.text(loc.dietTabDictionary));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('dictionary-manual-entry-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('manual-portion-staple-field')),
          '1',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('manual-save-button')));
        await tester.pumpAndSettle();

        expect(find.byType(ManualEntryScreen), findsNothing);
        expect(dietLogRepository.getDayLogCallCount, greaterThan(loadsBeforeSave));
      },
    );
  });
}
