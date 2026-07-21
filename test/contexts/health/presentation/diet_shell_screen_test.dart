import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/bowel/application/get_bowel_day.dart';
import 'package:life_os/contexts/bowel/application/save_bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_controller.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_screen.dart';
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
import 'package:life_os/contexts/health/presentation/diet_shell_screen.dart';
import 'package:life_os/contexts/health/presentation/food_search_screen.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/hydration/application/add_water.dart';
import 'package:life_os/contexts/hydration/application/get_water_day.dart';
import 'package:life_os/contexts/hydration/application/set_water_target.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/hydration/presentation/water_controller.dart';
import 'package:life_os/contexts/hydration/presentation/water_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/mascot.dart';

import '../../../support/l10n_test_app.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Map<String, dynamic> _mealJson({
  required String id,
  required String meal,
  required String time,
}) => {'id': id, 'meal': meal, 'time': time, 'items': <dynamic>[]};

class FakeMealRepository implements MealRepository {
  int getDayMealsCallCount = 0;
  final List<String> receivedDays = [];
  List<Map<String, dynamic>> meals = [];

  String? receivedMonth;
  List<String> loggedDaysToReturn = const [];
  Object? loggedDaysError;

  String? lastCreatedDay;
  String? lastCreatedMeal;

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    getDayMealsCallCount++;
    receivedDays.add(day);
    return DayMealsLog.fromJson({
      'day': day,
      'meals': meals,
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
    lastCreatedDay = day;
    lastCreatedMeal = meal;
    final id = 'meal-${meals.length + 1}';
    meals.add(_mealJson(id: id, meal: meal, time: '2026-07-18T09:00:00.000Z'));
    return MealEntry.fromJson(meals.last);
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    receivedMonth = month;
    if (loggedDaysError != null) throw loggedDaysError!;
    return loggedDaysToReturn;
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

class FakeWaterRepository implements WaterRepository {
  final List<String> receivedDays = [];

  @override
  Future<WaterDay> getDay(String idToken, String day) async {
    receivedDays.add(day);
    return WaterDay(
      day: day,
      totalMl: 0,
      targetMl: 2000,
      remainingMl: 2000,
    );
  }

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

class FakeBowelRepository implements BowelRepository {
  final List<String> receivedDays = [];

  @override
  Future<BowelDay> getDay(String idToken, String day) async {
    receivedDays.add(day);
    return BowelDay(day: day, count: 0, isNormal: null, note: '');
  }

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

FoodItem _riceItem() => FoodItem.fromJson({
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
  'base_amount': null,
  'measure_unit': null,
});

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  List<FoodItem> _favorites = [_riceItem()];

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => _favorites;

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {
    _favorites = _favorites.where((f) => f.id != foodItemId).toList();
  }
}

DietShellScreen _dietShell({
  required FakeMealRepository mealRepository,
  FakeDailyTargetRepository? dailyTargetRepository,
  FakeFoodDictionaryRepository? foodDictionaryRepository,
  FakeWaterRepository? waterRepository,
  FakeBowelRepository? bowelRepository,
  DateTime Function() clock = _defaultClock,
}) {
  final resolvedDailyTargetRepository =
      dailyTargetRepository ?? FakeDailyTargetRepository();
  final resolvedFoodDictionaryRepository =
      foodDictionaryRepository ?? FakeFoodDictionaryRepository();
  final resolvedWaterRepository = waterRepository ?? FakeWaterRepository();
  final resolvedBowelRepository = bowelRepository ?? FakeBowelRepository();
  return DietShellScreen(
    authRepository: FakeAuthRepository(),
    todayController: TodayController(
      GetDayMeals(mealRepository),
      GetDailyTargetWithRemaining(resolvedDailyTargetRepository),
      EditMealItem(mealRepository),
      DeleteMealItem(mealRepository),
      ChangeMealTime(mealRepository),
      DeleteMeal(mealRepository),
    ),
    dictionaryController: DictionaryController(
      SearchDictionary(resolvedFoodDictionaryRepository),
      ListFavorites(resolvedFoodDictionaryRepository),
      FavoriteFood(resolvedFoodDictionaryRepository),
      UnfavoriteFood(resolvedFoodDictionaryRepository),
    ),
    dailyTargetController: DailyTargetController(
      GetDailyTargetWithRemaining(resolvedDailyTargetRepository),
      SetDailyTarget(resolvedDailyTargetRepository),
    ),
    waterController: WaterController(
      GetWaterDay(resolvedWaterRepository),
      AddWater(resolvedWaterRepository),
      SetWaterTarget(resolvedWaterRepository),
    ),
    bowelController: BowelController(
      GetBowelDay(resolvedBowelRepository),
      SaveBowelDay(resolvedBowelRepository),
    ),
    createMealController: CreateMealController(CreateMeal(mealRepository)),
    getLoggedDays: GetLoggedDays(mealRepository),
    clock: clock,
  );
}

DateTime _defaultClock() => DateTime.utc(2026, 7, 18, 9);

Future<FakeMealRepository> _pumpShell(
  WidgetTester tester, {
  FakeMealRepository? mealRepository,
  Locale locale = const Locale('en'),
}) async {
  final resolvedMealRepository = mealRepository ?? FakeMealRepository();

  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: _dietShell(mealRepository: resolvedMealRepository),
    ),
  );
  await tester.pumpAndSettle();
  return resolvedMealRepository;
}

void main() {
  group('DietShellScreen', () {
    testWidgets('shows the Today section by default', (tester) async {
      await _pumpShell(tester);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietTabToday), findsWidgets);
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

    testWidgets(
      'shows only Today and Target, with no dictionary destination',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        expect(find.text(loc.dietTabToday), findsWidgets);
        expect(find.text(loc.dietTabTarget), findsWidgets);
      },
    );
  });

  group('DietShellScreen food search wiring', () {
    testWidgets(
      "tapping a meal card's add control pushes the full-screen food search for that meal",
      (tester) async {
        final mealRepository = await _pumpShell(tester);

        await tester.tap(find.byKey(const Key('add-to-meal-lunch')));
        await tester.pumpAndSettle();

        expect(find.byType(FoodSearchScreen), findsOneWidget);
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.dietAddToMealButton(loc.dietMealLunch)), findsOneWidget);
        expect(mealRepository.getDayMealsCallCount, greaterThan(0));
      },
    );

    testWidgets(
      'completing a search (Done) reloads Today and pops back to it',
      (tester) async {
        final mealRepository = await _pumpShell(tester);
        final loadsBeforeSave = mealRepository.getDayMealsCallCount;

        await tester.tap(find.byKey(const Key('add-to-meal-lunch')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();

        expect(find.byType(FoodSearchScreen), findsNothing);
        expect(mealRepository.lastCreatedDay, '2026-07-18');
        expect(mealRepository.lastCreatedMeal, 'lunch');
        expect(mealRepository.getDayMealsCallCount, greaterThan(loadsBeforeSave));
      },
    );

    testWidgets(
      "the snack area's add control seeds the next snack name",
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final loc = lookupAppLocalizations(const Locale('en'));
        final mealRepository = FakeMealRepository()
          ..meals.add(
            _mealJson(
              id: 'm1',
              meal: loc.dietSnackBaseName,
              time: '2026-07-18T15:00:00.000Z',
            ),
          );
        await _pumpShell(tester, mealRepository: mealRepository);

        await tester.tap(find.byKey(const Key('add-snack')));
        await tester.pumpAndSettle();

        expect(
          find.text(loc.dietAddToMealButton('${loc.dietSnackBaseName}2')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "a snack card's own add control continues that exact snack (no renumber)",
      (tester) async {
        final mealRepository = FakeMealRepository()
          ..meals.add(_mealJson(id: 'm1', meal: '點心2', time: '2026-07-18T15:00:00.000Z'));
        await _pumpShell(tester, mealRepository: mealRepository);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('add-to-snack-點心2')));
        await tester.pumpAndSettle();

        expect(
          find.text(loc.dietAddToMealButton('點心2')),
          findsOneWidget,
        );
      },
    );

    testWidgets('backing out of the search without completing does not reload', (
      tester,
    ) async {
      final mealRepository = await _pumpShell(tester);
      final loadsBefore = mealRepository.getDayMealsCallCount;

      await tester.tap(find.byKey(const Key('add-to-meal-lunch')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(FoodSearchScreen), findsNothing);
      expect(mealRepository.getDayMealsCallCount, loadsBefore);
    });
  });

  group('DietShellScreen home button', () {
    testWidgets(
      'tapping the home button in the Today header pops back to the previous screen',
      (tester) async {
        final mealRepository = FakeMealRepository();

        await tester.pumpWidget(
          l10nTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('open-diet-shell'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _dietShell(mealRepository: mealRepository),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('open-diet-shell')));
        await tester.pumpAndSettle();
        expect(find.byType(DietShellScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('today-home-button')));
        await tester.pumpAndSettle();

        expect(find.byType(DietShellScreen), findsNothing);
        expect(find.byKey(const Key('open-diet-shell')), findsOneWidget);
      },
    );

    testWidgets('the home button exposes a localized tooltip', (tester) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('today-home-button')))
            .tooltip,
        loc.dietGoHomeTooltip,
      );
    });
  });

  group('DietShellScreen day navigation', () {
    testWidgets(
      'the previous-day control reloads the prior day and shows "Yesterday"',
      (tester) async {
        final mealRepository = await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        expect(mealRepository.receivedDays.last, '2026-07-17');
        expect(find.text(loc.dietDayYesterday), findsOneWidget);
      },
    );

    testWidgets(
      'the next-day control is disabled on today and re-enables after going back',
      (tester) async {
        final mealRepository = await _pumpShell(tester);

        var nextButton = tester.widget<IconButton>(
          find.byKey(const Key('day-nav-next')),
        );
        expect(nextButton.onPressed, isNull);

        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        nextButton = tester.widget<IconButton>(
          find.byKey(const Key('day-nav-next')),
        );
        expect(nextButton.onPressed, isNotNull);

        await tester.tap(find.byKey(const Key('day-nav-next')));
        await tester.pumpAndSettle();

        expect(mealRepository.receivedDays.last, '2026-07-18');
        nextButton = tester.widget<IconButton>(
          find.byKey(const Key('day-nav-next')),
        );
        expect(nextButton.onPressed, isNull);
      },
    );

    testWidgets(
      'day navigation and the calendar-open button expose localized tooltips',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('day-nav-previous')))
              .tooltip,
          loc.dietDayPrevTooltip,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('day-nav-next')))
              .tooltip,
          loc.dietDayNextTooltip,
        );
      },
    );

    testWidgets(
      'the date shows in full (no overflow) at a narrow phone width',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));
        final expectedDate = DateFormat(
          'EEE, MMM d',
          'en',
        ).format(DateTime(2026, 7, 18));

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.calendar_month), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('day-nav-label')),
            matching: find.text(loc.dietDayToday),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );
  });

  group('DietShellScreen calendar', () {
    testWidgets(
      'opening the calendar marks logged days and picking one changes the view',
      (tester) async {
        final mealRepository = FakeMealRepository()
          ..loggedDaysToReturn = ['2026-07-15'];
        await _pumpShell(tester, mealRepository: mealRepository);

        await tester.tap(find.byKey(const Key('day-nav-label')));
        await tester.pumpAndSettle();

        expect(mealRepository.receivedMonth, '2026-07');
        expect(
          find.byKey(const Key('calendar-day-dot-2026-07-15')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('calendar-day-2026-07-15')));
        await tester.pumpAndSettle();

        expect(mealRepository.receivedDays.last, '2026-07-15');
        expect(find.byKey(const Key('calendar-close-button')), findsNothing);
      },
    );

    testWidgets('future days in the calendar are not selectable', (
      tester,
    ) async {
      final mealRepository = await _pumpShell(tester);

      await tester.tap(find.byKey(const Key('day-nav-label')));
      await tester.pumpAndSettle();
      final daysBefore = mealRepository.receivedDays.length;

      await tester.tap(find.byKey(const Key('calendar-day-2026-07-19')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar-close-button')), findsOneWidget);
      expect(mealRepository.receivedDays.length, daysBefore);
    });

    testWidgets(
      'a failure to load logged days still leaves the calendar usable',
      (tester) async {
        final mealRepository = FakeMealRepository()
          ..loggedDaysError = Exception('boom');
        await _pumpShell(tester, mealRepository: mealRepository);

        await tester.tap(find.byKey(const Key('day-nav-label')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('calendar-day-2026-07-10')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('calendar-day-2026-07-10')));
        await tester.pumpAndSettle();

        expect(mealRepository.receivedDays.last, '2026-07-10');
      },
    );
  });

  group('DietShellScreen header', () {
    testWidgets(
      'shows the mascot, the today title, and a "Today" chip alongside the full date',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));
        final expectedDate = DateFormat(
          'EEE, MMM d',
          'en',
        ).format(DateTime(2026, 7, 18));

        expect(find.byType(Mascot), findsOneWidget);
        expect(find.text(loc.dietTodayTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('day-nav-label')),
            matching: find.text(loc.dietDayToday),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets(
      'formats the full date per the active locale (Traditional Chinese)',
      (tester) async {
        await _pumpShell(
          tester,
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
        );
        final expectedDate = DateFormat(
          'M月d日 EEEE',
          'zh_Hant',
        ).format(DateTime(2026, 7, 18));

        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets(
      'centers the header within a maxWidth column on a wide (tablet/desktop) screen',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpShell(tester);

        final constrainedBoxFinder = find.ancestor(
          of: find.byKey(const Key('day-nav-label')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox && widget.constraints.maxWidth == 600,
          ),
        );
        expect(constrainedBoxFinder, findsOneWidget);
      },
    );

    testWidgets(
      'centers the date label group between the prev/next arrows',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        // The tappable label fills the space between the two chevrons; its
        // content (chip · date · calendar icon) should sit centered within it,
        // so the free space to the left of the content mirrors the space to
        // its right. Left-aligned, the whole gap would pile up on the right.
        final labelRect = tester.getRect(find.byKey(const Key('day-nav-label')));
        final chipRect = tester.getRect(
          find.descendant(
            of: find.byKey(const Key('day-nav-label')),
            matching: find.text(loc.dietDayToday),
          ),
        );
        final iconRect = tester.getRect(find.byIcon(Icons.calendar_month));

        final leftGap = chipRect.left - labelRect.left;
        final rightGap = labelRect.right - iconRect.right;
        expect((leftGap - rightGap).abs(), lessThan(24));
      },
    );
  });

  group('DietShellScreen water tab', () {
    testWidgets(
      'selecting the water destination shows the water screen for the '
      'viewed day, and Today/Target remain reachable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final waterRepository = FakeWaterRepository();
        await tester.pumpWidget(
          l10nTestApp(
            home: _dietShell(
              mealRepository: FakeMealRepository(),
              waterRepository: waterRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final loc = lookupAppLocalizations(const Locale('en'));

        expect(find.byType(WaterScreen), findsNothing);
        // The shell loaded the water tab for its viewed day even before it is
        // shown (the shell owns loading).
        expect(waterRepository.receivedDays, contains('2026-07-18'));

        await tester.tap(find.text(loc.dietTabWater));
        await tester.pumpAndSettle();

        expect(find.byType(WaterScreen), findsOneWidget);
        expect(find.text(loc.waterTitle), findsOneWidget);
        // Today and Target are still reachable.
        expect(find.text(loc.dietTabToday), findsWidgets);
        expect(find.text(loc.dietTabTarget), findsWidgets);
      },
    );

    testWidgets('the water tab follows the shell day navigation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final waterRepository = FakeWaterRepository();
      await tester.pumpWidget(
        l10nTestApp(
          home: _dietShell(
            mealRepository: FakeMealRepository(),
            waterRepository: waterRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('day-nav-previous')));
      await tester.pumpAndSettle();

      expect(waterRepository.receivedDays.last, '2026-07-17');
    });
  });

  group('DietShellScreen bowel tab', () {
    testWidgets(
      'selecting the bowel destination shows the bowel screen for the '
      'viewed day, and Today/Target/Water remain reachable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final bowelRepository = FakeBowelRepository();
        await tester.pumpWidget(
          l10nTestApp(
            home: _dietShell(
              mealRepository: FakeMealRepository(),
              bowelRepository: bowelRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final loc = lookupAppLocalizations(const Locale('en'));

        expect(find.byType(BowelScreen), findsNothing);
        // The shell loaded the bowel tab for its viewed day even before it is
        // shown (the shell owns loading).
        expect(bowelRepository.receivedDays, contains('2026-07-18'));

        await tester.tap(find.text(loc.dietTabBowel));
        await tester.pumpAndSettle();

        expect(find.byType(BowelScreen), findsOneWidget);
        expect(find.text(loc.bowelTitle), findsOneWidget);
        // Today, Target, and Water are still reachable.
        expect(find.text(loc.dietTabToday), findsWidgets);
        expect(find.text(loc.dietTabTarget), findsWidgets);
        expect(find.text(loc.dietTabWater), findsWidgets);
      },
    );

    testWidgets('the bowel tab follows the shell day navigation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bowelRepository = FakeBowelRepository();
      await tester.pumpWidget(
        l10nTestApp(
          home: _dietShell(
            mealRepository: FakeMealRepository(),
            bowelRepository: bowelRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('day-nav-previous')));
      await tester.pumpAndSettle();

      expect(bowelRepository.receivedDays.last, '2026-07-17');
    });
  });
}
