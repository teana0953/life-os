import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal_item.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/health/presentation/today_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

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

class FakeMealRepository implements MealRepository {
  DayMealsLog? logToReturn;

  String? patchedItemId;
  double? patchedQuantity;
  double? patchedMeasure;
  Portions? patchedPortions;
  String? deletedItemId;
  String? patchedMealId;
  DateTime? patchedTime;
  String? deletedMealId;

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async => logToReturn!;

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
    patchedItemId = id;
    patchedQuantity = quantity;
    patchedMeasure = measure;
    patchedPortions = portions;
    // Reflect the edit in the next getDayMeals so the reload shows it.
    _applyItemPatch(id, quantity: quantity, measure: measure, portions: portions);
  }

  void _applyItemPatch(
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) {
    final log = logToReturn;
    if (log == null) return;
    logToReturn = DayMealsLog(
      day: log.day,
      totals: log.totals,
      meals: log.meals.map((meal) {
        return MealEntry(
          id: meal.id,
          meal: meal.meal,
          time: meal.time,
          items: meal.items.map((item) {
            if (item.id != id) return item;
            final newQuantity = quantity ?? item.quantity;
            return MealItem(
              id: item.id,
              foodItemId: item.foodItemId,
              name: item.name,
              source: item.source,
              quantity: newQuantity,
              staple: portions?.staple ?? item.staple,
              meat: portions?.meat ?? item.meat,
              fruit: portions?.fruit ?? item.fruit,
              veg: portions?.veg ?? item.veg,
              baseAmount: item.baseAmount,
              measureUnit: item.measureUnit,
              consumed: item.consumed,
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  @override
  Future<void> deleteMealItem(String idToken, String id) async {
    deletedItemId = id;
    final log = logToReturn;
    if (log == null) return;
    logToReturn = DayMealsLog(
      day: log.day,
      totals: log.totals,
      meals: log.meals
          .map((meal) => MealEntry(
                id: meal.id,
                meal: meal.meal,
                time: meal.time,
                items: meal.items.where((item) => item.id != id).toList(),
              ))
          .toList(),
    );
  }

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async {
    patchedMealId = id;
    patchedTime = time;
    final log = logToReturn;
    if (log == null) return;
    logToReturn = DayMealsLog(
      day: log.day,
      totals: log.totals,
      meals: log.meals
          .map((meal) => meal.id == id
              ? MealEntry(id: meal.id, meal: meal.meal, time: time, items: meal.items)
              : meal)
          .toList(),
    );
  }

  @override
  Future<void> deleteMeal(String idToken, String id) async {
    deletedMealId = id;
    final log = logToReturn;
    if (log == null) return;
    logToReturn = DayMealsLog(
      day: log.day,
      totals: log.totals,
      meals: log.meals.where((meal) => meal.id != id).toList(),
    );
  }
}

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTargetWithRemaining? targetToReturn;

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async =>
      targetToReturn!;

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

Map<String, dynamic> _itemJson({
  required String id,
  String? name,
  double staple = 0,
  double meat = 0,
  double fruit = 0,
  double veg = 0,
  String? foodItemId = 'food-1',
  String source = 'dict',
  double quantity = 1,
  double? baseAmount,
  String? measureUnit,
}) => {
  'id': id,
  'food_item_id': foodItemId,
  'name': name,
  'photo_ref': null,
  'source': source,
  'unclassified': false,
  'carb_g': 0,
  'protein_g': 0,
  'fat_g': 0,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 0,
  'staple': staple,
  'meat': meat,
  'fruit': fruit,
  'veg': veg,
  'quantity': quantity,
  'base_amount': baseAmount,
  'measure_unit': measureUnit,
  'consumed': {
    'carb_g': 0,
    'protein_g': 0,
    'fat_g': 0,
    'sugar_g': 0,
    'fiber_g': 0,
    'kcal': 0,
    'staple': staple,
    'meat': meat,
    'fruit': fruit,
    'veg': veg,
  },
};

Map<String, dynamic> _mealJson({
  required String id,
  required String meal,
  required String time,
  List<Map<String, dynamic>> items = const [],
}) => {'id': id, 'meal': meal, 'time': time, 'items': items};

DailyTargetWithRemaining _target({double staple = 12}) =>
    DailyTargetWithRemaining.fromJson({
      'day': '2026-07-18',
      'base': {'staple': staple, 'meat': 6, 'fruit': 4, 'veg': 3},
      'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'effective': {'staple': staple, 'meat': 6, 'fruit': 4, 'veg': 3},
      'logged': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'remaining': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
    });

TodayController _controllerWith({
  required DayMealsLog dayLog,
  DailyTargetWithRemaining? target,
  FakeMealRepository? mealRepository,
}) {
  final resolvedMealRepository = mealRepository ?? FakeMealRepository();
  resolvedMealRepository.logToReturn = dayLog;
  final targetRepository = FakeDailyTargetRepository()
    ..targetToReturn = target ?? _target();
  return TodayController(
    GetDayMeals(resolvedMealRepository),
    GetDailyTargetWithRemaining(targetRepository),
    EditMealItem(resolvedMealRepository),
    DeleteMealItem(resolvedMealRepository),
    ChangeMealTime(resolvedMealRepository),
    DeleteMeal(resolvedMealRepository),
  );
}

DateTime _identityTime(DateTime value) => value;

Future<void> _pumpTodayScreen(
  WidgetTester tester,
  TodayController controller, {
  Locale locale = const Locale('en'),
  void Function(String meal)? onAddToMeal,
  VoidCallback? onAddSnack,
  void Function(String snackName)? onAddToSnackGroup,
  Future<DateTime?> Function(BuildContext, DateTime, DateTime Function(DateTime))? pickMealTime,
  // When true, leaves TodayScreen.pickMealTime unset so it runs its own
  // real default (the actual `showTimePicker`-backed implementation)
  // instead of a test fake — needed to prove the default itself is 24h
  // (task 6b: this is the only screen that injects the whole pick
  // operation, so proving the real default needs a way to ask for it).
  bool useRealPickMealTime = false,
  // The real `_defaultPickMealTime` converts the picked wall time with
  // `.toUtc()`, so a test driving it must render with the true inverse
  // (`.toLocal()`) or the round trip shifts by the machine's offset — green
  // under `TZ=UTC`, red at UTC+8, which is exactly the trap this repo has
  // hit before. Every other test keeps the identity conversion, which is
  // correct for them because they inject the pick as well.
  DateTime Function(DateTime) toLocalTime = _identityTime,
}) async {
  await controller.load('token-123', '2026-07-18');
  final screen = useRealPickMealTime
      ? TodayScreen(
          controller: controller,
          signOut: SignOut(FakeAuthRepository()),
          idToken: () async => 'token-123',
          day: '2026-07-18',
          onAddToMeal: onAddToMeal,
          onAddSnack: onAddSnack,
          onAddToSnackGroup: onAddToSnackGroup,
          toLocalTime: toLocalTime,
        )
      : TodayScreen(
          controller: controller,
          signOut: SignOut(FakeAuthRepository()),
          idToken: () async => 'token-123',
          day: '2026-07-18',
          onAddToMeal: onAddToMeal,
          onAddSnack: onAddSnack,
          onAddToSnackGroup: onAddToSnackGroup,
          toLocalTime: toLocalTime,
          pickMealTime: pickMealTime ?? (_, current, __) async => current,
        );
  await tester.pumpWidget(l10nTestApp(locale: locale, home: screen));
  await tester.pumpAndSettle();
}

void main() {
  group('TodayScreen progress bars', () {
    testWidgets('use the day totals vs the effective target', (tester) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': <dynamic>[],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 9, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog, target: _target(staple: 12));
      await _pumpTodayScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietProgressOfTarget(9, 12)), findsOneWidget);
    });
  });

  group('TodayScreen timeline', () {
    testWidgets('interleaves meals and snacks by time, snacks between meals', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: 'breakfast', time: '2026-07-18T08:00:00.000Z'),
          _mealJson(id: 'm2', meal: '點心2', time: '2026-07-18T10:30:00.000Z'),
          _mealJson(id: 'm3', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
          _mealJson(id: 'm4', meal: '點心', time: '2026-07-18T15:00:00.000Z'),
          _mealJson(id: 'm5', meal: 'dinner', time: '2026-07-18T19:00:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      final order = [
        loc.dietMealBreakfast,
        '點心2',
        loc.dietMealLunch,
        '點心',
        loc.dietMealDinner,
      ];
      final positions = order
          .map((label) => tester.getTopLeft(find.text(label).first).dy)
          .toList();
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
    });

    testWidgets('empty standard meals render after the timeline, in fixed order', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller, onAddToMeal: (_) {});
      final loc = lookupAppLocalizations(const Locale('en'));

      final lunchY = tester.getTopLeft(find.text(loc.dietMealLunch).first).dy;
      final breakfastY = tester.getTopLeft(find.text(loc.dietMealBreakfast).first).dy;
      final dinnerY = tester.getTopLeft(find.text(loc.dietMealDinner).first).dy;

      expect(breakfastY, greaterThan(lunchY));
      expect(dinnerY, greaterThan(breakfastY));
      // Empty meal cards still offer an add control.
      expect(find.byKey(const Key('add-to-meal-breakfast')), findsOneWidget);
      expect(find.byKey(const Key('add-to-meal-dinner')), findsOneWidget);
    });
  });

  group('TodayScreen meal card', () {
    testWidgets('shows the meal time and a total pill summing item consumed portions', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'breakfast',
            time: '2026-07-18T08:10:00.000Z',
            items: [
              _itemJson(id: 'i1', name: '飯/1碗', staple: 4),
              _itemJson(id: 'i2', name: '蛋', meat: 1),
            ],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 4, 'meat': 1, 'fruit': 0, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(find.text('08:10'), findsOneWidget);
      final totalPill = find.byKey(const Key('meal-total-breakfast'));
      expect(
        find.descendant(of: totalPill, matching: find.text('${loc.dietCategoryStaple} 4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: totalPill, matching: find.text('${loc.dietCategoryMeat} 1')),
        findsOneWidget,
      );
    });

    testWidgets('an item shows only its non-zero consumed categories, its consumed amount, and is tappable', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'breakfast',
            time: '2026-07-18T08:00:00.000Z',
            items: [_itemJson(id: 'i1', name: '蛋', staple: 0, meat: 1, quantity: 1)],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 1, 'fruit': 0, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(find.text('蛋'), findsOneWidget);
      // Only one "meat 1" pill for the item row itself; no lone "0" shown.
      expect(find.text('${loc.dietCategoryStaple} 0'), findsNothing);
      // Consumed amount shown ("蛋" has no base measure -> generic 份 word).
      expect(find.text('1 ${loc.dietPortionUnit}'), findsOneWidget);

      final itemRow = tester.widget<InkWell>(
        find.ancestor(of: find.text('蛋'), matching: find.byType(InkWell)),
      );
      expect(itemRow.onTap, isNotNull);
    });

    testWidgets('a household-unit item shows its consumed amount in that unit ("9 顆")', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'breakfast',
            time: '2026-07-18T08:00:00.000Z',
            items: [
              _itemJson(
                id: 'i1',
                name: '櫻桃/9顆',
                fruit: 1,
                quantity: 1,
                baseAmount: 9,
                measureUnit: '顆',
              ),
            ],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 1, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller);

      // quantity 1 * base 9 = 9, in the item's own unit 顆.
      expect(find.text('9 顆'), findsOneWidget);
    });

    testWidgets('an item with a base but an empty measure unit falls back to 份, not a blank unit', (
      tester,
    ) async {
      final loc = lookupAppLocalizations(const Locale('en'));
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'breakfast',
            time: '2026-07-18T08:00:00.000Z',
            items: [
              _itemJson(
                id: 'i1',
                name: 'X',
                fruit: 1,
                quantity: 1,
                baseAmount: 9,
                measureUnit: '',
              ),
            ],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 1, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller);

      // An empty measure unit must not render "9 " (a number with a blank
      // unit); the guard treats it as no unit and falls back to 份.
      expect(find.text('1 ${loc.dietPortionUnit}'), findsOneWidget);
      expect(find.text('9 '), findsNothing);
    });

    testWidgets('a household-unit item editor labels its after-field unit 份 and its measure segment 顆', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'breakfast',
            time: '2026-07-18T08:00:00.000Z',
            items: [
              _itemJson(
                id: 'i1',
                name: '櫻桃/9顆',
                fruit: 1,
                quantity: 1,
                baseAmount: 9,
                measureUnit: '顆',
              ),
            ],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 1, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.byKey(const Key('meal-item-i1')));
      await tester.pumpAndSettle();

      // Household foods now carry a base measure, so the toggle is offered.
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      // After-field unit label is the generic 份, not a name-scraped 顆.
      expect(find.text(loc.dietPortionUnit), findsWidgets);
      // The measure segment reads the item's own unit 顆.
      expect(find.text('顆'), findsOneWidget);
    });

    testWidgets('a snack card shows its own meal value verbatim, with the snack emoji', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: '點心2', time: '2026-07-18T15:00:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller);

      expect(find.text('點心2'), findsOneWidget);
    });
  });

  group('TodayScreen add affordances', () {
    testWidgets('a meal card\'s add control invokes onAddToMeal with that meal', (
      tester,
    ) async {
      String? added;
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller, onAddToMeal: (meal) => added = meal);

      await tester.tap(find.byKey(const Key('add-to-meal-lunch')));
      await tester.pumpAndSettle();

      expect(added, 'lunch');
    });

    testWidgets('a snack card\'s add control invokes onAddToSnackGroup with its exact name', (
      tester,
    ) async {
      String? added;
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: '點心2', time: '2026-07-18T15:00:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(
        tester,
        controller,
        onAddToSnackGroup: (name) => added = name,
      );

      await tester.tap(find.byKey(const Key('add-to-snack-點心2')));
      await tester.pumpAndSettle();

      expect(added, '點心2');
    });

    testWidgets('the "add new snack" control invokes onAddSnack', (tester) async {
      var tapped = false;
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': <dynamic>[],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller, onAddSnack: () => tapped = true);

      await tester.tap(find.byKey(const Key('add-snack')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('TodayScreen inline item edit', () {
    testWidgets('tapping a dictionary item reveals an inline editor in quantity mode', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'lunch',
            time: '2026-07-18T12:30:00.000Z',
            items: [_itemJson(id: 'i1', name: '飯/1碗', staple: 4, quantity: 1)],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 4, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final controller = _controllerWith(dayLog: dayLog);
      await _pumpTodayScreen(tester, controller);

      expect(find.byKey(const Key('item-editor-i1')), findsNothing);

      await tester.tap(find.byKey(const Key('meal-item-i1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('item-editor-i1')), findsOneWidget);
      // Quantity mode: no measure toggle for an item with no base measure.
      expect(find.byType(SegmentedButton<bool>), findsNothing);
    });

    testWidgets('a quantity edit persists as {quantity} and Today refreshes', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'lunch',
            time: '2026-07-18T12:30:00.000Z',
            items: [_itemJson(id: 'i1', name: '飯/1碗', staple: 4, quantity: 1)],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 4, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(tester, controller);

      await tester.tap(find.byKey(const Key('meal-item-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-item-i1')));
      await tester.pumpAndSettle();

      expect(mealRepository.patchedItemId, 'i1');
      expect(mealRepository.patchedQuantity, 2);
      expect(mealRepository.patchedMeasure, isNull);
      expect(find.byKey(const Key('item-editor-i1')), findsNothing);
    });

    testWidgets('switching to measure mode and typing persists as {measure}', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'lunch',
            time: '2026-07-18T12:30:00.000Z',
            items: [
              _itemJson(
                id: 'i1',
                name: '飯/50g',
                staple: 1,
                quantity: 1,
                baseAmount: 50,
                measureUnit: 'g',
              ),
            ],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 1, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.byKey(const Key('meal-item-i1')));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);

      await tester.tap(find.text(loc.dietGramsLabel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '80');
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-item-i1')));
      await tester.pumpAndSettle();

      expect(mealRepository.patchedItemId, 'i1');
      expect(mealRepository.patchedMeasure, 80);
      expect(mealRepository.patchedQuantity, isNull);
    });

    testWidgets('switching to measure mode seeds the amount with baseAmount', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'lunch',
            time: '2026-07-18T12:30:00.000Z',
            items: [
              _itemJson(
                id: 'i1',
                name: '飯/50g',
                staple: 1,
                quantity: 1,
                baseAmount: 50,
                measureUnit: 'g',
              ),
            ],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 1, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.byKey(const Key('meal-item-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.dietGramsLabel));
      await tester.pumpAndSettle();

      // Seeded with the item's baseAmount (50g), not 0 — saving right after
      // the mode toggle, without typing anything, must not send
      // `measure: 0` (which the backend rejects with a 400).
      await tester.tap(find.byKey(const Key('save-item-i1')));
      await tester.pumpAndSettle();

      expect(mealRepository.patchedItemId, 'i1');
      expect(mealRepository.patchedMeasure, 50);
    });

    testWidgets('an amount of 0 cannot be saved: the save button is disabled and no PATCH is sent', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'lunch',
            time: '2026-07-18T12:30:00.000Z',
            items: [_itemJson(id: 'i1', name: '飯/1碗', staple: 4, quantity: 1)],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 4, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(tester, controller);

      await tester.tap(find.byKey(const Key('meal-item-i1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('save-item-i1')));
      expect(saveButton.onPressed, isNull);

      await tester.tap(find.byKey(const Key('save-item-i1')));
      await tester.pumpAndSettle();

      expect(mealRepository.patchedItemId, isNull);
      expect(find.byKey(const Key('item-editor-i1')), findsOneWidget);
    });

    testWidgets('a manual item edit persists as {portions}', (tester) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'lunch',
            time: '2026-07-18T12:30:00.000Z',
            items: [
              _itemJson(
                id: 'i1',
                name: '自製便當',
                staple: 1,
                meat: 1,
                foodItemId: null,
                source: 'manual',
              ),
            ],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 1, 'meat': 1, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(tester, controller);

      await tester.tap(find.byKey(const Key('meal-item-i1')));
      await tester.pumpAndSettle();
      // No AmountStepper for a manual item; four portion fields instead.
      expect(find.byKey(const Key('edit-staple-i1')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('edit-staple-i1')), '3');
      await tester.tap(find.byKey(const Key('save-item-i1')));
      await tester.pumpAndSettle();

      expect(mealRepository.patchedItemId, 'i1');
      expect(mealRepository.patchedPortions?.staple, 3);
      expect(mealRepository.patchedPortions?.meat, 1);
    });

    testWidgets('a delete-item control deletes the item and Today refreshes without it', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'lunch',
            time: '2026-07-18T12:30:00.000Z',
            items: [
              _itemJson(id: 'i1', name: '飯/1碗', staple: 4),
              _itemJson(id: 'i2', name: '蛋', meat: 1),
            ],
          ),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 4, 'meat': 1, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(tester, controller);

      // The delete control lives in the expanded editor (not the collapsed
      // row, to avoid a stray tap target next to the expand affordance) —
      // expand the item first.
      await tester.tap(find.byKey(const Key('meal-item-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-item-i1')));
      await tester.pumpAndSettle();

      expect(mealRepository.deletedItemId, 'i1');
      expect(find.text('飯/1碗'), findsNothing);
      expect(find.text('蛋'), findsOneWidget);
    });
  });

  group('TodayScreen meal time + delete meal', () {
    testWidgets('the change-time control persists the new time and Today refreshes', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      final newTime = DateTime.utc(2026, 7, 18, 9, 0);
      await _pumpTodayScreen(
        tester,
        controller,
        pickMealTime: (_, __, ___) async => newTime,
      );

      await tester.tap(find.byKey(const Key('change-meal-time-m1')));
      await tester.pumpAndSettle();

      expect(mealRepository.patchedMealId, 'm1');
      expect(mealRepository.patchedTime, newTime);
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets(
      "the screen's own default picker is always 24-hour, whatever the "
      "locale — the card renders the time with DateFormat('HH:mm'), so a "
      "12-hour picker would have an English-locale user choose '9:30 PM' "
      "and then read it back as '21:30'",
      (tester) async {
        final dayLog = DayMealsLog.fromJson({
          'day': '2026-07-18',
          'meals': [
            _mealJson(id: 'm1', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
          ],
          'totals': {
            'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
            'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
          },
        });
        final controller = _controllerWith(dayLog: dayLog);
        await _pumpTodayScreen(
          tester,
          controller,
          // The real default picker — no injected fake — so this actually
          // exercises TodayScreen's own `showTimePicker` call, not a stand-in.
          useRealPickMealTime: true,
        );

        await tester.tap(find.byKey(const Key('change-meal-time-m1')));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
        // The day-period (AM/PM) control only exists in the 12-hour layout.
        expect(find.text('AM'), findsNothing);
        expect(find.text('PM'), findsNothing);
      },
    );

    testWidgets(
      "picking 21:30 via the screen's own default picker sends 21:30 local "
      "as a UTC instant to the repository and renders 21:30 back onto the "
      "meal card — proving the picked value survives _defaultPickMealTime's "
      "local/UTC combine unmangled, not just that the dialog itself was "
      "24-hour. The wire assertion is the load-bearing one: the card renders "
      "through `.toLocal()`, which is a no-op on an already-local DateTime "
      "and so would silently cancel a dropped `.toUtc()` at every host "
      "offset.",
      (tester) async {
        final dayLog = DayMealsLog.fromJson({
          'day': '2026-07-18',
          'meals': [
            _mealJson(id: 'm1', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
          ],
          'totals': {
            'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
            'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
          },
        });
        final mealRepository = FakeMealRepository();
        final controller = _controllerWith(
          dayLog: dayLog,
          mealRepository: mealRepository,
        );
        await _pumpTodayScreen(
          tester,
          controller,
          // The real default picker — no injected fake — so this actually
          // exercises TodayScreen's own `_defaultPickMealTime`, not a
          // stand-in.
          useRealPickMealTime: true,
          // The inverse of `_defaultPickMealTime`'s `.toUtc()`, so the round
          // trip holds at any machine offset rather than only under TZ=UTC.
          toLocalTime: (dt) => dt.toLocal(),
        );

        await tester.tap(find.byKey(const Key('change-meal-time-m1')));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);

        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();

        final fields = find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(TextField),
        );
        // Typing hour 21 is itself part of the proof: a 12-hour input field
        // would reject it outright.
        await tester.enterText(fields.at(0), '21');
        await tester.enterText(fields.at(1), '30');
        await tester.tap(find.widgetWithText(TextButton, 'OK'));
        await tester.pumpAndSettle();

        // What actually went on the wire. This is the assertion the display
        // cannot stand in for: dropping `.toUtc()` in `_defaultPickMealTime`
        // sends a naive local DateTime to the backend, and `.toLocal()` on it
        // is a no-op, so the card below would still read 21:30.
        expect(mealRepository.patchedMealId, 'm1');
        expect(mealRepository.patchedTime!.isUtc, isTrue);
        expect(mealRepository.patchedTime, DateTime(2026, 7, 18, 21, 30).toUtc());

        expect(find.text('21:30'), findsOneWidget);
      },
    );

    testWidgets('cancelling the time picker (returns null) makes no change', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(
        tester,
        controller,
        pickMealTime: (_, __, ___) async => null,
      );

      await tester.tap(find.byKey(const Key('change-meal-time-m1')));
      await tester.pumpAndSettle();

      expect(mealRepository.patchedMealId, isNull);
      expect(find.text('12:30'), findsOneWidget);
    });

    testWidgets('deleting a meal asks for confirmation first; dismissing deletes nothing', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.byKey(const Key('delete-meal-m1')));
      await tester.pumpAndSettle();

      expect(find.text(loc.dietDeleteMealConfirmTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete-meal-cancel')));
      await tester.pumpAndSettle();

      expect(mealRepository.deletedMealId, isNull);
      expect(find.text(loc.dietMealLunch), findsOneWidget);
    });

    testWidgets('confirming deletes the meal and Today refreshes without it', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(id: 'm1', meal: 'lunch', time: '2026-07-18T12:30:00.000Z'),
        ],
        'totals': {
          'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
          'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
        },
      });
      final mealRepository = FakeMealRepository();
      final controller = _controllerWith(dayLog: dayLog, mealRepository: mealRepository);
      await _pumpTodayScreen(tester, controller, onAddToMeal: (_) {});

      await tester.tap(find.byKey(const Key('delete-meal-m1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-meal-confirm')));
      await tester.pumpAndSettle();

      expect(mealRepository.deletedMealId, 'm1');
      final loc = lookupAppLocalizations(const Locale('en'));
      // The lunch meal is gone; only the empty-card fallback remains.
      expect(find.byKey(const Key('meal-total-lunch')), findsNothing);
      expect(find.text(loc.dietMealEmptyLabel), findsWidgets);

      // Tier 2 (unify-empty-states): the shared one-line muted note. The
      // only converted site with no key at all — located by its text, as it
      // always was.
      expect(
        find.ancestor(
          of: find.text(loc.dietMealEmptyLabel).first,
          matching: find.byType(EmptyStateNote),
        ),
        findsOneWidget,
      );
      expect(find.byType(EmptyStateGuide), findsNothing);
    });
  });

  group('TodayScreen narrow width', () {
    testWidgets(
      'a collapsed item row with several non-zero portion pills does not overflow at 320/360dp',
      (tester) async {
        final dayLog = DayMealsLog.fromJson({
          'day': '2026-07-18',
          'meals': [
            _mealJson(
              id: 'm1',
              meal: 'lunch',
              time: '2026-07-18T12:30:00.000Z',
              items: [
                _itemJson(
                  id: 'i1',
                  name: '綜合豐盛便當',
                  staple: 4,
                  meat: 3,
                  fruit: 2,
                  veg: 1,
                ),
              ],
            ),
          ],
          'totals': {
            'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
            'staple': 4, 'meat': 3, 'fruit': 2, 'veg': 1,
          },
        });

        for (final width in [320.0, 360.0]) {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = _controllerWith(dayLog: dayLog);
          await _pumpTodayScreen(tester, controller);

          expect(tester.takeException(), isNull);
        }
      },
    );

    // The screen-level guard for the shared `CategoryProgressBar` (this is
    // its other host besides DailyTargetScreen, and the diet day screen
    // reaches it through here). Wider than the row test above: it sweeps the
    // text scale and both locales, and asserts on *every* layout error
    // rather than only the first one `takeException` hands back.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'the screen lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, 2400));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final dayLog = DayMealsLog.fromJson({
                'day': '2026-07-18',
                'meals': <dynamic>[],
                'totals': {
                  'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0,
                  'fiber_g': 0, 'kcal': 0,
                  'staple': 9, 'meat': 5, 'fruit': 3, 'veg': 2,
                },
              });
              final controller = _controllerWith(dayLog: dayLog);

              await expectNoLayoutErrors(() async {
                await _pumpTodayScreen(tester, controller, locale: locale);
              });

              expect(
                find.byKey(const Key('today-progress-staple')).evaluate(),
                isNotEmpty,
              );
            },
          );
        }
      }
    }
  });
}
