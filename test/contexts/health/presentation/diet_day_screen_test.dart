import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
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
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/diet_day_screen.dart';
import 'package:life_os/contexts/health/presentation/food_search_screen.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> idToken() async => 'token';
  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

class _FakeMealRepository implements MealRepository {
  final List<String> receivedDays = [];

  /// The months the calendar asked for logged days for, so a test can prove a
  /// month change refetched instead of leaving the old month's markers up.
  final List<String> receivedMonths = [];

  /// Meal group names to report per day, so a test can set up a day that
  /// already has meals (e.g. to check the snapshot handed to the dictionary).
  final Map<String, List<String>> mealNamesByDay;

  _FakeMealRepository({this.mealNamesByDay = const {}});

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    receivedDays.add(day);
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
  Future<MealEntry> createMeal(String idToken, {required String day, required String meal, DateTime? time, required List<CreateMealItem> items}) async => throw UnimplementedError();
  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    receivedMonths.add(month);
    return const [];
  }
  @override
  Future<void> patchMealItem(String idToken, String id, {double? quantity, double? measure, Portions? portions}) async => throw UnimplementedError();
  @override
  Future<void> deleteMealItem(String idToken, String id) async => throw UnimplementedError();
  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async => throw UnimplementedError();
  @override
  Future<void> deleteMeal(String idToken, String id) async => throw UnimplementedError();
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
  Future<DailyTarget> setTarget(String idToken, {required String day, required double baseStaple, required double baseMeat, required double baseFruit, required double baseVeg, double? bonusStaple, double? bonusMeat, double? bonusFruit, double? bonusVeg}) async => throw UnimplementedError();
}

FoodItem _riceItem() => FoodItem.fromJson({
  'id': 'rice-1',
  'owner_user_id': null,
  'name': '飯/1碗',
  'carb_g': 60, 'protein_g': 4, 'fat_g': 0.5, 'sugar_g': 0, 'fiber_g': 1, 'kcal': 280,
  'staple': 4, 'meat': 0, 'fruit': 0, 'veg': 0,
  'base_amount': null, 'measure_unit': null,
});

class _FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];
  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [];
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

/// The diet day screen wired to the given [meals] repo. Controllers are created
/// fresh each call unless [reuse] is passed, so a re-mount can share state.
Widget _dietDay({
  required _FakeMealRepository meals,
  DateTime Function() clock = _clock,
  _Controllers? reuse,
}) {
  final target = _FakeDailyTargetRepository();
  final dict = _FakeFoodDictionaryRepository();
  final c = reuse ??
      _Controllers(
        today: TodayController(
          GetDayMeals(meals),
          GetDailyTargetWithRemaining(target),
          EditMealItem(meals),
          DeleteMealItem(meals),
          ChangeMealTime(meals),
          DeleteMeal(meals),
        ),
        dailyTarget: DailyTargetController(
          GetDailyTargetWithRemaining(target),
          SetDailyTarget(target),
        ),
        // Loaded up front, as the health shell does before the diet day is
        // reachable — an unloaded controller would leave the pushed food
        // search sitting on its loading state forever.
        dictionary: DictionaryController(
          SearchDictionary(dict),
          ListFavorites(dict),
          FavoriteFood(dict),
          UnfavoriteFood(dict),
        )..load('token'),
        createMeal: CreateMealController(CreateMeal(meals)),
        getLoggedDays: GetLoggedDays(meals),
      );
  return DietDayScreen(
    authRepository: _FakeAuthRepository(),
    idToken: 'token',
    todayController: c.today,
    dictionaryController: c.dictionary,
    dailyTargetController: c.dailyTarget,
    createMealController: c.createMeal,
    getLoggedDays: c.getLoggedDays,
    clock: clock,
  );
}

class _Controllers {
  final TodayController today;
  final DailyTargetController dailyTarget;
  final DictionaryController dictionary;
  final CreateMealController createMeal;
  final GetLoggedDays getLoggedDays;
  _Controllers({required this.today, required this.dailyTarget, required this.dictionary, required this.createMeal, required this.getLoggedDays});
}

DateTime _clock() => DateTime(2026, 7, 15, 9);

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('loads today on mount', (tester) async {
    final meals = _FakeMealRepository();
    await tester.pumpWidget(l10nRouterTestApp(home: _dietDay(meals: meals)));
    await tester.pumpAndSettle();

    expect(meals.receivedDays.last, '2026-07-15');
  });

  testWidgets('browsing to the previous day loads that day', (tester) async {
    final meals = _FakeMealRepository();
    await tester.pumpWidget(l10nRouterTestApp(home: _dietDay(meals: meals)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_en.dietDayPrevTooltip));
    await tester.pumpAndSettle();

    expect(meals.receivedDays.last, '2026-07-14');
  });

  testWidgets(
    'regression: re-entering the screen reloads today after a past day was browsed',
    (tester) async {
      final meals = _FakeMealRepository();
      // Build once, keep the (shared) controllers so a fresh mount reuses them —
      // mirroring re-opening the diet tile from the record hub.
      final first = _dietDay(meals: meals) as DietDayScreen;
      final shared = _Controllers(
        today: first.todayController,
        dailyTarget: first.dailyTargetController,
        dictionary: first.dictionaryController,
        createMeal: first.createMealController,
        getLoggedDays: first.getLoggedDays,
      );
      await tester.pumpWidget(l10nRouterTestApp(home: first));
      await tester.pumpAndSettle();

      // Browse to a past day: the shared controllers now hold that day.
      await tester.tap(find.byTooltip(_en.dietDayPrevTooltip));
      await tester.pumpAndSettle();
      expect(meals.receivedDays.last, '2026-07-14');

      // Fully unmount, then re-mount a fresh screen with the same controllers —
      // exactly what re-opening the diet tile (a new pushed route) does, so
      // initState runs again.
      await tester.pumpWidget(l10nRouterTestApp(home: const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        l10nRouterTestApp(home: _dietDay(meals: meals, reuse: shared)),
      );
      await tester.pumpAndSettle();

      // initState reloads today — not the last-browsed day.
      expect(meals.receivedDays.last, '2026-07-15');
    },
  );

  group('food dictionary entry', () {
    /// Wraps [screen] in a router that both records what it pushed in
    /// `state.extra` and builds the real [FoodSearchScreen] from it — the
    /// shared `l10nRouterTestApp` stub can't do either, since it only renders
    /// `matchedLocation`.
    Widget dietDayWithDictionaryRoute(
      DietDayScreen screen, {
      void Function(({String day, List<String> mealNames}) args)? onPush,
      Locale locale = const Locale('en'),
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => screen),
          GoRoute(
            path: '/health/diet/dictionary',
            builder: (context, state) {
              final args = state.extra as ({String day, List<String> mealNames});
              onPush?.call(args);
              return FoodSearchScreen(
                meal: null,
                mealNames: args.mealNames,
                dictionaryController: screen.dictionaryController,
                createMealController: screen.createMealController,
                idToken: 'token',
                day: args.day,
                signOut: SignOut(_FakeAuthRepository()),
              );
            },
          ),
        ],
      );
      return MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: router,
      );
    }

    testWidgets('the diet screen offers a dictionary action with a tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nRouterTestApp(home: _dietDay(meals: _FakeMealRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diet-open-dictionary')), findsOneWidget);
      expect(find.byTooltip(_en.dietOpenDictionaryTooltip), findsOneWidget);
    });

    testWidgets(
      'opening the dictionary carries the day being viewed and its meal names',
      (tester) async {
        // The 14th (yesterday relative to the pinned clock) already has meals,
        // so both halves of the snapshot are observable.
        final meals = _FakeMealRepository(
          mealNamesByDay: {
            '2026-07-14': ['breakfast', 'Snack'],
            '2026-07-15': ['dinner'],
          },
        );
        ({String day, List<String> mealNames})? pushed;
        await tester.pumpWidget(
          dietDayWithDictionaryRoute(
            _dietDay(meals: meals) as DietDayScreen,
            onPush: (args) => pushed = args,
          ),
        );
        await tester.pumpAndSettle();

        // Browse OFF today first — otherwise "carries the viewed day" would
        // hold even if the screen hard-coded today.
        await tester.tap(find.byTooltip(_en.dietDayPrevTooltip));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('diet-open-dictionary')));
        await tester.pumpAndSettle();

        expect(pushed?.day, '2026-07-14');
        expect(pushed?.mealNames, ['breakfast', 'Snack']);
      },
    );

    testWidgets(
      'a dictionary session starts clean after an abandoned per-meal search',
      (tester) async {
        final screen = _dietDay(meals: _FakeMealRepository()) as DietDayScreen;
        await tester.pumpWidget(dietDayWithDictionaryRoute(screen));
        await tester.pumpAndSettle();

        // Stand in for a per-meal search that was backed out of with items
        // still in the tray.
        screen.createMealController.start('lunch');
        screen.createMealController.add(_riceItem());

        await tester.tap(find.byKey(const Key('diet-open-dictionary')));
        await tester.pumpAndSettle();

        expect(screen.createMealController.meal, isNull);
        expect(screen.createMealController.tray, isEmpty);
        // …so the dictionary opens showing no recording controls at all.
        expect(find.byKey(const Key('food-search-tray')), findsNothing);
        expect(find.byKey(const Key('food-search-done-button')), findsNothing);
        expect(find.byKey(const Key('manual-entry-link')), findsNothing);
      },
    );

    // The AppBar now carries the text-labelled target action AND the
    // icon-only dictionary action; neither may overflow on a narrow phone.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the diet AppBar does not overflow at ${width.toInt()}dp, locale=$locale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await tester.pumpWidget(
              l10nRouterTestApp(
                locale: locale,
                home: _dietDay(meals: _FakeMealRepository()),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.byKey(const Key('diet-open-target')), findsOneWidget);
            expect(find.byKey(const Key('diet-open-dictionary')), findsOneWidget);
          },
        );
      }
    }
  });

  testWidgets('the target action navigates to the daily target route', (tester) async {
    await tester.pumpWidget(l10nRouterTestApp(home: _dietDay(meals: _FakeMealRepository())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diet-open-target')));
    await tester.pumpAndSettle();

    // Diet pushes `/health/diet/target`; the app router builds the screen there.
    expect(find.text('/health/diet/target'), findsOneWidget);
  });

  testWidgets(
    'jumping the calendar to a month a year back shows it and refetches its '
    'logged days',
    (tester) async {
      final meals = _FakeMealRepository();
      await tester.pumpWidget(l10nRouterTestApp(home: _dietDay(meals: meals)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('day-nav-label')));
      await tester.pumpAndSettle();
      expect(meals.receivedMonths.last, '2026-07');

      await tester.tap(find.byKey(const Key('calendar-month-label')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month-picker-year-previous')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month-picker-month-7')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('calendar-month-label'))).data,
        DateFormat.yMMM('en').format(DateTime(2025, 7)),
      );
      // Without the refetch the grid would keep July 2026's logged-day dots.
      expect(meals.receivedMonths.last, '2025-07');
    },
  );

  testWidgets('dismissing the calendar month picker changes nothing', (
    tester,
  ) async {
    final meals = _FakeMealRepository();
    await tester.pumpWidget(l10nRouterTestApp(home: _dietDay(meals: meals)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('day-nav-label')));
    await tester.pumpAndSettle();
    final fetchesBefore = meals.receivedMonths.length;

    await tester.tap(find.byKey(const Key('calendar-month-label')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('calendar-month-label'))).data,
      DateFormat.yMMM('en').format(DateTime(2026, 7)),
    );
    expect(meals.receivedMonths.length, fetchesBefore);
  });

  testWidgets('the calendar month label shows a caret and a tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      l10nRouterTestApp(home: _dietDay(meals: _FakeMealRepository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-nav-label')));
    await tester.pumpAndSettle();

    final entry = find.ancestor(
      of: find.byKey(const Key('calendar-month-label')),
      matching: find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == _en.monthPickerOpenTooltip,
      ),
    );
    expect(entry, findsOneWidget);
    expect(
      find.descendant(of: entry, matching: find.byIcon(Icons.arrow_drop_down)),
      findsOneWidget,
    );
  });

  // Regression: the month label's `▾` affordance added an icon to a centred,
  // non-shrinkable Row inside the calendar dialog. Widget tests default to an
  // 800x600 surface, so nothing else in this mobile-first PWA's suite caught
  // it.
  for (final width in [320.0, 360.0]) {
    for (final locale in testSupportedLocales) {
      testWidgets(
        'the calendar month header does not overflow at ${width.toInt()}dp, '
        'locale=$locale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            l10nRouterTestApp(
              locale: locale,
              home: _dietDay(meals: _FakeMealRepository()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('day-nav-label')));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expectMonthLabelFullyVisible(
            tester,
            const Key('calendar-month-label'),
          );
          expectMonthLabelReadable(tester, const Key('calendar-month-label'));
        },
      );
    }
  }

  // Regression: the readable floor was computed from the **authored** font
  // size while the `FittedBox` scales `textScaler`-sized glyphs, so the width
  // cap bit `textScaler`× too early — a user on a large system font size got
  // the month digits ellipsized away (`2026年7月` → `202…`): the exact failure
  // the floor was added to prevent, reintroduced by the fix for it. Nothing in
  // this suite set a text scale at all before this.
  for (final locale in testSupportedLocales) {
    testWidgets(
      'the calendar month label stays whole at 320dp/textScale=2, '
      'locale=$locale',
      (tester) async {
        useTextScaleFactor(tester, 2.0);
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          l10nRouterTestApp(
            locale: locale,
            home: _dietDay(meals: _FakeMealRepository()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('day-nav-label')));
        await tester.pumpAndSettle();

        // The dialog's grid was never the overflow this drained — that was
        // the shared `CategoryProgressBar` on the screen behind it (fixed;
        // see the layout guard below).
        expect(tester.takeException(), isNull);
        expectMonthLabelFullyVisible(tester, const Key('calendar-month-label'));
        expectMonthLabelPaintedReadable(
          tester,
          const Key('calendar-month-label'),
        );
      },
    );
  }

  // The screen's own overflow guard. What actually overflowed here was the
  // shared `CategoryProgressBar` (label + used/target on one rigid row), not
  // the calendar dialog. Asserts *no layout error of any kind* rather than
  // draining — see `test/support/layout_guard.dart`.
  group('narrow-width layout guard', () {
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'the diet day lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, 2400));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(
                  l10nRouterTestApp(
                    locale: locale,
                    home: _dietDay(meals: _FakeMealRepository()),
                  ),
                );
                await tester.pumpAndSettle();
              });
            },
          );
        }
      }
    }

    // Landscape: the calendar dialog is content-sized, so on a 360dp-tall
    // surface its month grid ran 140px off the bottom (176px at 2x).
    for (final locale in testSupportedLocales) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          'the calendar dialog lays out cleanly in landscape (640x360), '
          'textScale=$textScale, locale=$locale',
          (tester) async {
            useTextScaleFactor(tester, textScale);
            await tester.binding.setSurfaceSize(const Size(640, 360));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await expectNoLayoutErrors(() async {
              await tester.pumpWidget(
                l10nRouterTestApp(
                  locale: locale,
                  home: _dietDay(meals: _FakeMealRepository()),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('day-nav-label')));
              await tester.pumpAndSettle();
            });

            expect(
              find.byKey(const Key('calendar-month-label')),
              findsOneWidget,
            );
          },
        );
      }
    }
  });
}
