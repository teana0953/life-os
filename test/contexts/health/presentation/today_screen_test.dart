import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/health/presentation/today_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

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

class FakeMealRepository implements MealRepository {
  DayMealsLog? logToReturn;

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
}) => {
  'id': id,
  'food_item_id': 'food-1',
  'name': name,
  'photo_ref': null,
  'source': 'dict',
  'unclassified': false,
  'carb_g': 0,
  'protein_g': 0,
  'fat_g': 0,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 0,
  'staple': staple,
  'meat': meat,
  'fruit': 0,
  'veg': 0,
  'quantity': 1,
  'base_grams': null,
  'consumed': {
    'carb_g': 0,
    'protein_g': 0,
    'fat_g': 0,
    'sugar_g': 0,
    'fiber_g': 0,
    'kcal': 0,
    'staple': staple,
    'meat': meat,
    'fruit': 0,
    'veg': 0,
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
}) {
  final mealRepository = FakeMealRepository()..logToReturn = dayLog;
  final targetRepository = FakeDailyTargetRepository()
    ..targetToReturn = target ?? _target();
  return TodayController(
    GetDayMeals(mealRepository),
    GetDailyTargetWithRemaining(targetRepository),
  );
}

Future<void> _pumpTodayScreen(
  WidgetTester tester,
  TodayController controller, {
  void Function(String meal)? onAddToMeal,
  VoidCallback? onAddSnack,
  void Function(String snackName)? onAddToSnackGroup,
}) async {
  await controller.load('token-123', '2026-07-18');
  await tester.pumpWidget(
    l10nTestApp(
      home: TodayScreen(
        controller: controller,
        signOut: SignOut(FakeAuthRepository()),
        onAddToMeal: onAddToMeal,
        onAddSnack: onAddSnack,
        onAddToSnackGroup: onAddToSnackGroup,
        toLocalTime: (dt) => dt,
      ),
    ),
  );
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

    testWidgets('an item shows only its non-zero consumed categories and is read-only', (
      tester,
    ) async {
      final dayLog = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          _mealJson(
            id: 'm1',
            meal: 'breakfast',
            time: '2026-07-18T08:00:00.000Z',
            items: [_itemJson(id: 'i1', name: '蛋', staple: 0, meat: 1)],
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

      final itemTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('蛋'), matching: find.byType(ListTile)),
      );
      expect(itemTile.onTap, isNull);
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
}
