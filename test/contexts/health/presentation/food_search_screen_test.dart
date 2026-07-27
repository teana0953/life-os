import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/food_search_screen.dart';
import 'package:life_os/contexts/health/presentation/snack_naming.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

FoodItem _riceItem({double? baseAmount, String? measureUnit}) => FoodItem.fromJson({
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
  'base_amount': baseAmount,
  'measure_unit': measureUnit,
});

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  List<FoodItem> favorites;

  /// What [search] returns when it differs from the favorites — used to drive
  /// "a search found nothing" independently of "there are no favorites".
  final List<FoodItem>? searchResults;

  /// Thrown by [listFavorites] instead of returning, to drive the results
  /// area's failure states.
  final Object? listFavoritesError;

  /// Held open (never completed) to keep [listFavorites] in flight, so the
  /// controller stays in its loading state.
  final Completer<List<FoodItem>>? favoritesGate;

  /// Thrown by [favorite]/[unfavorite] — a write failure, which must not be
  /// mistaken for the list failing to load.
  final Object? toggleError;

  FakeFoodDictionaryRepository({
    List<FoodItem>? favorites,
    this.searchResults,
    this.listFavoritesError,
    this.favoritesGate,
    this.toggleError,
  }) : favorites = favorites ?? [_riceItem()];

  @override
  Future<List<FoodItem>> search(String idToken, String query) async =>
      searchResults ?? favorites;

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async {
    if (listFavoritesError != null) throw listFavoritesError!;
    if (favoritesGate != null) return favoritesGate!.future;
    return favorites;
  }

  @override
  Future<void> favorite(String idToken, String foodItemId) async {
    if (toggleError != null) throw toggleError!;
  }

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {
    if (toggleError != null) throw toggleError!;
  }
}

class FakeMealRepository implements MealRepository {
  String? receivedDay;
  String? receivedMeal;
  List<CreateMealItem>? receivedItems;
  Object? errorToThrow;

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    throw UnimplementedError();
  }

  @override
  Future<MealEntry> createMeal(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    receivedDay = day;
    receivedMeal = meal;
    receivedItems = items;
    return MealEntry.fromJson({
      'id': 'meal-1',
      'meal': meal,
      'time': '2026-07-18T12:30:00.000Z',
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

class FakeAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password) async {}
  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
  @override
  Future<String?> idToken() async => 'fake-token';
  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

DictionaryController _dictionaryController(FakeFoodDictionaryRepository repo) =>
    DictionaryController(
      SearchDictionary(repo),
      ListFavorites(repo),
      FavoriteFood(repo),
      UnfavoriteFood(repo),
    );

Future<FakeMealRepository> _pumpScreen(
  WidgetTester tester, {
  FakeFoodDictionaryRepository? dictionaryRepository,
  FakeMealRepository? mealRepository,
  FakeAuthRepository? authRepository,
  String? meal = 'lunch',
  List<String> mealNames = const <String>[],
  Locale locale = const Locale('en'),
}) async {
  final resolvedDictionaryRepository =
      dictionaryRepository ?? FakeFoodDictionaryRepository();
  final resolvedMealRepository = mealRepository ?? FakeMealRepository();
  final dictionaryController = _dictionaryController(resolvedDictionaryRepository);
  await dictionaryController.load('token-123');
  final createMealController = CreateMealController(CreateMeal(resolvedMealRepository))
    ..start(meal);

  await tester.pumpWidget(
    l10nRouterTestApp(
      locale: locale,
      home: FoodSearchScreen(
        meal: meal,
        mealNames: mealNames,
        dictionaryController: dictionaryController,
        createMealController: createMealController,
        idToken: 'token-123',
        day: '2026-07-18',
        signOut: SignOut(authRepository ?? FakeAuthRepository()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return resolvedMealRepository;
}

void main() {
  group('FoodSearchScreen', () {
    testWidgets('shows a pinned search field and the meal in the title', (
      tester,
    ) async {
      await _pumpScreen(tester, meal: 'lunch');
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(find.byKey(const Key('food-search-field')), findsOneWidget);
      expect(find.text(loc.dietAddToMealButton(loc.dietMealLunch)), findsOneWidget);
    });

    testWidgets('shows favorites by default (before any search) as full-page results', (
      tester,
    ) async {
      await _pumpScreen(tester);

      expect(find.text('飯/1碗'), findsOneWidget);
    });

    testWidgets('tapping a result adds it to the tray, not the backend', (
      tester,
    ) async {
      final mealRepository = await _pumpScreen(tester);

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      // Now shown twice: once in the results list, once in the tray row.
      expect(find.text('飯/1碗'), findsNWidgets(2));
      expect(mealRepository.receivedItems, isNull);
    });

    testWidgets('the amount stepper edits the amount and updates the preview + running total', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      // Default quantity 1 previews 4 staple; bump the stepper's + once ->
      // quantity 2 -> 8 staple in both the row preview and the running total.
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text('${loc.dietCategoryStaple} 8'), findsWidgets);
    });

    testWidgets('a gram-enabled item offers the portion/gram toggle and converts via base grams', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        dictionaryRepository: FakeFoodDictionaryRepository(
          favorites: [_riceItem(baseAmount: 50, measureUnit: 'g')],
        ),
      );

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<bool>), findsOneWidget);

      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(loc.dietGramsLabel));
      await tester.pumpAndSettle();

      // The search field is the first TextField; the tray row's amount
      // stepper field is the last.
      await tester.enterText(find.byType(TextField).last, '33');
      await tester.pump();

      // 33g / 50g base = 0.66 quantity * 4 staple/unit ≈ 2.64 staple.
      expect(find.textContaining('${loc.dietCategoryStaple} 2.6'), findsWidgets);
    });

    testWidgets('an item with no base grams offers no gram toggle', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<bool>), findsNothing);
    });

    testWidgets('a household-unit tray item labels its after-field unit 份 and its measure segment 顆', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        dictionaryRepository: FakeFoodDictionaryRepository(
          favorites: [_riceItem(baseAmount: 9, measureUnit: '顆')],
        ),
      );

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      final loc = lookupAppLocalizations(const Locale('en'));

      // A household food carries a base measure, so the toggle is offered.
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      // After-field unit label is the generic 份, not a name-scraped 碗.
      expect(find.text(loc.dietPortionUnit), findsWidgets);
      // The measure segment reads the item's own unit 顆.
      expect(find.text('顆'), findsOneWidget);
    });

    testWidgets('the running total sums every tray item\'s preview', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('飯/1碗').first);
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      // Two rows at default quantity 1 (4 staple each) = 8 staple total.
      expect(find.text('${loc.dietCategoryStaple} 8'), findsOneWidget);
    });

    testWidgets('a tray item is removable', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      expect(find.text('飯/1碗'), findsNWidgets(2));

      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.byTooltip(loc.dietRemoveItemTooltip));
      await tester.pumpAndSettle();

      expect(find.text('飯/1碗'), findsOneWidget);
    });

    testWidgets('Done submits the tray via the meals API and pops with a result', (
      tester,
    ) async {
      bool? poppedResult;
      final dictionaryRepository = FakeFoodDictionaryRepository();
      final mealRepository = FakeMealRepository();
      final dictionaryController = _dictionaryController(dictionaryRepository);
      await dictionaryController.load('token-123');
      final createMealController = CreateMealController(CreateMeal(mealRepository))
        ..start('lunch');

      await tester.pumpWidget(
        l10nRouterTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    poppedResult = await context.push<bool>(
                      '/health/diet/food-search',
                      extra: FoodSearchScreen(
                        meal: 'lunch',
                        dictionaryController: dictionaryController,
                        createMealController: createMealController,
                        idToken: 'token-123',
                        day: '2026-07-18',
                        signOut: SignOut(FakeAuthRepository()),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-done-button')));
      await tester.pumpAndSettle();

      expect(mealRepository.receivedDay, '2026-07-18');
      expect(mealRepository.receivedMeal, 'lunch');
      expect(mealRepository.receivedItems, hasLength(1));
      expect(mealRepository.receivedItems!.single.quantity, 1);
      expect(find.byType(FoodSearchScreen), findsNothing);
      expect(poppedResult, isTrue);
    });

    testWidgets('backing out without completing discards the tray (no network call)', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final dictionaryRepository = FakeFoodDictionaryRepository();
      final mealRepository = FakeMealRepository();
      final dictionaryController = _dictionaryController(dictionaryRepository);
      await dictionaryController.load('token-123');
      final createMealController = CreateMealController(CreateMeal(mealRepository))
        ..start('lunch');

      await tester.pumpWidget(
        l10nTestApp(
          home: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FoodSearchScreen(
                          meal: 'lunch',
                          dictionaryController: dictionaryController,
                          createMealController: createMealController,
                          idToken: 'token-123',
                          day: '2026-07-18',
                          signOut: SignOut(FakeAuthRepository()),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(FoodSearchScreen), findsNothing);
      expect(mealRepository.receivedItems, isNull);
    });

    testWidgets(
      'a reauth failure shows a sign-in-again control that signs out, without losing the tray',
      (tester) async {
        final authRepository = FakeAuthRepository();
        await _pumpScreen(
          tester,
          mealRepository: FakeMealRepository()
            ..errorToThrow = const DietReauthenticationRequired(),
          authRepository: authRepository,
        );

        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
        // Tray still shown (not popped, not lost).
        expect(find.byType(FoodSearchScreen), findsOneWidget);
        expect(find.text('飯/1碗'), findsNWidgets(2));

        await tester.tap(find.byKey(const Key('food-search-sign-in-again-button')));
        await tester.pumpAndSettle();

        expect(authRepository.signOutCalled, isTrue);
      },
    );

    testWidgets('a save failure shows a localized error without losing the tray', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        mealRepository: FakeMealRepository()
          ..errorToThrow = const DietFetchFailure('boom'),
      );

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-done-button')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietSaveMealFailed), findsOneWidget);
      expect(find.byType(FoodSearchScreen), findsOneWidget);
      expect(find.text('飯/1碗'), findsNWidgets(2));
    });

    testWidgets('at a narrow width with the search field focused, results stay reachable with no viewInsets workaround', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpScreen(tester);
      await tester.tap(find.byKey(const Key('food-search-field')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('food-search-field')), findsOneWidget);
      expect(find.text('飯/1碗'), findsOneWidget);
    });

    // A gram tray row must not overflow across the full narrow-width axis:
    // {320dp, 360dp} × {en, zh-Hant} × {portion, measure} mode. The tray gives
    // the AmountStepper less width than the isolated widget (row padding +
    // the row's other columns), so this is where plan A''s trio-tightening
    // earns its keep. zh-Hant switches the segment's 份量 label (real CJK
    // coverage); the after-field label follows the item's own measure unit.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final measureMode in [false, true]) {
          testWidgets(
            'a gram tray row does not overflow at ${width.toInt()}dp, '
            'locale=$locale, measureMode=$measureMode',
            (tester) async {
              await tester.binding.setSurfaceSize(Size(width, 640));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              await _pumpScreen(
                tester,
                locale: locale,
                dictionaryRepository: FakeFoodDictionaryRepository(
                  favorites: [_riceItem(baseAmount: 50, measureUnit: 'g')],
                ),
              );

              await tester.tap(find.text('飯/1碗'));
              await tester.pumpAndSettle();

              if (measureMode) {
                final loc = lookupAppLocalizations(locale);
                await tester.tap(find.text(loc.dietGramsLabel));
                await tester.pumpAndSettle();
              }

              expect(tester.takeException(), isNull);
              expect(find.byKey(const Key('food-search-tray')), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('FoodSearchScreen as the dictionary (no target meal)', () {
    testWidgets('identifies itself as the dictionary, not as adding to a meal', (
      tester,
    ) async {
      await _pumpScreen(tester, meal: null);
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(find.text(loc.dietDictionaryTitle), findsOneWidget);
      expect(
        find.text(loc.dietAddToMealButton(loc.dietMealLunch)),
        findsNothing,
      );
      // Still a real search page: field + favorites.
      expect(find.byKey(const Key('food-search-field')), findsOneWidget);
      expect(find.text('飯/1碗'), findsOneWidget);
    });

    testWidgets('with an empty tray shows no recording controls at all', (
      tester,
    ) async {
      await _pumpScreen(tester, meal: null);

      expect(find.byKey(const Key('food-search-tray')), findsNothing);
      // Hidden, not merely disabled — a disabled complete button would still
      // say "this page is for recording".
      expect(find.byKey(const Key('food-search-done-button')), findsNothing);
      expect(find.byKey(const Key('manual-entry-link')), findsNothing);
    });

    testWidgets('opened for a target meal, an empty tray still shows the complete action (unchanged)', (
      tester,
    ) async {
      await _pumpScreen(tester, meal: 'lunch');

      expect(find.byKey(const Key('food-search-done-button')), findsOneWidget);
      expect(find.byKey(const Key('manual-entry-link')), findsOneWidget);
    });

    testWidgets('adding a food reveals the tray and the recording controls', (
      tester,
    ) async {
      await _pumpScreen(tester, meal: null);

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('food-search-tray')), findsOneWidget);
      expect(find.byKey(const Key('food-search-done-button')), findsOneWidget);
      expect(find.byKey(const Key('manual-entry-link')), findsOneWidget);
    });

    testWidgets('completing asks which meal, then saves the whole tray to the chosen one', (
      tester,
    ) async {
      final mealRepository = await _pumpScreen(tester, meal: null);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-done-button')));
      await tester.pumpAndSettle();

      // Nothing saved yet — the sheet is asking.
      expect(find.text(loc.dietChooseMealSheetTitle), findsOneWidget);
      expect(mealRepository.receivedItems, isNull);

      await tester.tap(find.byKey(const Key('choose-meal-dinner')));
      await tester.pumpAndSettle();

      expect(mealRepository.receivedMeal, 'dinner');
      expect(mealRepository.receivedDay, '2026-07-18');
      expect(mealRepository.receivedItems, hasLength(1));
    });

    testWidgets('the meal choices are the three standard meals plus the day\'s next snack', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        meal: null,
        mealNames: const ['breakfast', 'Snack', 'Snack2'],
      );
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-done-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('choose-meal-breakfast')), findsOneWidget);
      expect(find.byKey(const Key('choose-meal-lunch')), findsOneWidget);
      expect(find.byKey(const Key('choose-meal-dinner')), findsOneWidget);
      // Snack + Snack2 already exist for the day, so the next one is Snack3.
      expect(
        find.text(nextSnackName(const ['breakfast', 'Snack', 'Snack2'], loc.dietSnackBaseName)),
        findsOneWidget,
      );
    });

    testWidgets('choosing the snack option saves to the day\'s next snack name', (
      tester,
    ) async {
      final mealRepository = await _pumpScreen(
        tester,
        meal: null,
        mealNames: const ['Snack'],
      );
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-done-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('choose-meal-snack')));
      await tester.pumpAndSettle();

      expect(mealRepository.receivedMeal, '${loc.dietSnackBaseName}2');
    });

    testWidgets('dismissing the meal choice saves nothing and keeps the tray', (
      tester,
    ) async {
      final mealRepository = await _pumpScreen(tester, meal: null);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-done-button')));
      await tester.pumpAndSettle();
      expect(find.text(loc.dietChooseMealSheetTitle), findsOneWidget);

      // Dismiss by tapping the sheet's scrim rather than picking a meal.
      await tester.tap(find.byType(ModalBarrier).last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text(loc.dietChooseMealSheetTitle), findsNothing);
      expect(mealRepository.receivedItems, isNull);
      // The tray survived, and nothing reads as an error.
      expect(find.byKey(const Key('food-search-tray')), findsOneWidget);
      expect(find.byKey(const Key('food-search-error-message')), findsNothing);
      expect(find.text('飯/1碗'), findsNWidgets(2));
    });

    testWidgets(
      'retrying after a failed save and then dismissing the meal choice still '
      'saves nothing',
      (tester) async {
        // The first round already bound a meal to the shared controller, so
        // from here on the controller's own "no meal bound" guard no longer
        // catches a dismissal — only the screen's does. Without it the retry
        // would silently save to the meal chosen in the first round.
        final mealRepository = FakeMealRepository()
          ..errorToThrow = const DietFetchFailure('boom');
        await _pumpScreen(tester, meal: null, mealRepository: mealRepository);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('choose-meal-dinner')));
        await tester.pumpAndSettle();
        // The save failed: the tray is kept and 'dinner' is now bound.
        expect(find.byKey(const Key('food-search-error-message')), findsOneWidget);
        expect(mealRepository.receivedMeal, isNull);

        // The backend recovers, the user retries — then changes their mind.
        mealRepository.errorToThrow = null;
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();
        expect(find.text(loc.dietChooseMealSheetTitle), findsOneWidget);
        await tester.tap(find.byType(ModalBarrier).last, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(mealRepository.receivedMeal, isNull);
        expect(mealRepository.receivedItems, isNull);
        // Still on the page with the tray intact — nothing was saved or popped.
        expect(find.byType(FoodSearchScreen), findsOneWidget);
        expect(find.byKey(const Key('food-search-tray')), findsOneWidget);
      },
    );

    testWidgets(
      'the screen being torn down while the meal sheet is open saves nothing',
      (tester) async {
        // Sign-out flips the whole app to the login screen while the sheet is
        // still up; the choice that comes back must not still be saved.
        final mealRepository = FakeMealRepository();
        final dictionaryController = _dictionaryController(
          FakeFoodDictionaryRepository(),
        );
        await dictionaryController.load('token-123');
        final createMealController =
            CreateMealController(CreateMeal(mealRepository))..start(null);
        final showScreen = ValueNotifier(true);
        addTearDown(showScreen.dispose);

        await tester.pumpWidget(
          l10nTestApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: showScreen,
              builder: (context, show, _) => show
                  ? FoodSearchScreen(
                      meal: null,
                      dictionaryController: dictionaryController,
                      createMealController: createMealController,
                      idToken: 'token-123',
                      day: '2026-07-18',
                      signOut: SignOut(FakeAuthRepository()),
                    )
                  : const Scaffold(body: Text('signed out')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();

        // The page goes away underneath the still-open sheet.
        showScreen.value = false;
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('choose-meal-dinner')));
        await tester.pumpAndSettle();

        expect(mealRepository.receivedMeal, isNull);
        expect(mealRepository.receivedItems, isNull);
      },
    );

    testWidgets(
      'every meal option stays reachable when the sheet is taller than its cap',
      (tester) async {
        // A modal bottom sheet is capped at 9/16 of the screen; on a short
        // screen (or at a large text scale) the four options do not fit, and
        // what gets cut off is the last one — the snack.
        await tester.binding.setSurfaceSize(const Size(360, 430));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mealRepository = FakeMealRepository();
        final dictionaryController = _dictionaryController(
          FakeFoodDictionaryRepository(),
        );
        await dictionaryController.load('token-123');
        final createMealController =
            CreateMealController(CreateMeal(mealRepository))..start(null);
        // Seeded directly so the tray stays short enough that the page itself
        // fits this deliberately short screen — the sheet is what's on trial.
        createMealController.addManual(
          '自製便當',
          const Portions(staple: 1, meat: 0, fruit: 0, veg: 0),
        );

        await tester.pumpWidget(
          l10nRouterTestApp(
            home: FoodSearchScreen(
              meal: null,
              dictionaryController: dictionaryController,
              createMealController: createMealController,
              idToken: 'token-123',
              day: '2026-07-18',
              signOut: SignOut(FakeAuthRepository()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('food-search-done-button')));
        await tester.pumpAndSettle();

        final snack = find.byKey(const Key('choose-meal-snack'));
        await tester.ensureVisible(snack);
        await tester.pumpAndSettle();
        await tester.tap(snack);
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(mealRepository.receivedMeal, loc.dietSnackBaseName);
      },
    );

    testWidgets('opened for a target meal, completing does not ask which meal', (
      tester,
    ) async {
      final mealRepository = await _pumpScreen(tester, meal: 'lunch');
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-done-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.dietChooseMealSheetTitle), findsNothing);
      expect(mealRepository.receivedMeal, 'lunch');
    });
  });

  group('FoodSearchScreen results area', () {
    /// Types [query] and lets the controller's search debounce elapse, so the
    /// results the screen renders are the ones this query produced.
    Future<void> searchFor(WidgetTester tester, String query) async {
      await tester.enterText(find.byKey(const Key('food-search-field')), query);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('with no favorites and nothing searched, says so instead of going blank', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        meal: null,
        dictionaryRepository: FakeFoodDictionaryRepository(favorites: []),
      );
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(find.byKey(const Key('food-search-empty-favorites')), findsOneWidget);
      expect(find.text(loc.dietDictionaryFavoritesEmptyTitle), findsOneWidget);
      // Not the search-found-nothing state: nothing has been searched.
      expect(find.byKey(const Key('food-search-empty-no-results')), findsNothing);
    });

    testWidgets('a search that finds nothing names the query and offers manual entry', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        meal: null,
        dictionaryRepository: FakeFoodDictionaryRepository(searchResults: []),
      );
      final loc = lookupAppLocalizations(const Locale('en'));

      await searchFor(tester, '酪梨');

      expect(find.byKey(const Key('food-search-empty-no-results')), findsOneWidget);
      expect(find.text(loc.dietDictionaryNoResultsTitle('酪梨')), findsOneWidget);
      // Not the no-favorites state: this is the user's own search coming back
      // empty, and the way out is offered right here.
      expect(find.byKey(const Key('food-search-empty-favorites')), findsNothing);

      await tester.tap(find.byKey(const Key('food-search-empty-manual-entry-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual-entry-name-field')), findsOneWidget);
    });

    testWidgets('opened for a target meal, a fruitless search does not add a second manual-entry entrance', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        meal: 'lunch',
        dictionaryRepository: FakeFoodDictionaryRepository(searchResults: []),
      );

      await searchFor(tester, '酪梨');

      expect(find.byKey(const Key('food-search-empty-no-results')), findsOneWidget);
      // The persistent link is already there for this mode, so the empty state
      // must not duplicate it.
      expect(find.byKey(const Key('manual-entry-link')), findsOneWidget);
      expect(
        find.byKey(const Key('food-search-empty-manual-entry-button')),
        findsNothing,
      );
    });

    testWidgets('in the dictionary with a tray already started, a fruitless search does not duplicate the link either', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        meal: null,
        dictionaryRepository: FakeFoodDictionaryRepository(searchResults: []),
      );

      // Adding a food reveals the persistent manual-entry link…
      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual-entry-link')), findsOneWidget);

      await searchFor(tester, '酪梨');

      expect(find.byKey(const Key('food-search-empty-no-results')), findsOneWidget);
      expect(
        find.byKey(const Key('food-search-empty-manual-entry-button')),
        findsNothing,
      );
    });

    testWidgets('a failure to load is distinguishable from having no foods', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        meal: null,
        dictionaryRepository: FakeFoodDictionaryRepository(
          listFavoritesError: const DietFetchFailure('boom'),
        ),
      );
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(find.byKey(const Key('food-search-dictionary-error')), findsOneWidget);
      expect(find.text(loc.dietDictionaryLoadFailed), findsOneWidget);
      // Emphatically NOT "you have no usual foods yet".
      expect(find.byKey(const Key('food-search-empty-favorites')), findsNothing);
    });

    testWidgets('a failed favorite toggle does not wipe the list being browsed', (
      tester,
    ) async {
      // The results area reads dictionary.status, and toggleFavorite used to
      // write its failures into that same field — so one tap on a heart could
      // replace the list with "couldn't load foods", on the per-meal path too,
      // with no way back from the screen (clearing the search box does not
      // reset the status). The toggle now leaves the list-loading status alone.
      await _pumpScreen(
        tester,
        meal: 'lunch',
        dictionaryRepository: FakeFoodDictionaryRepository(
          toggleError: const DietFetchFailure('boom'),
        ),
      );
      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text('飯/1碗'), findsOneWidget);

      // The seeded item is already a favorite, so this is the un-favorite path.
      await tester.tap(find.byIcon(Icons.favorite).first);
      await tester.pumpAndSettle();

      expect(find.text('飯/1碗'), findsOneWidget);
      expect(find.byKey(const Key('food-search-dictionary-error')), findsNothing);
      expect(find.text(loc.dietDictionaryLoadFailed), findsNothing);
    });

    testWidgets('an auth failure loading the dictionary offers a way out, not a blank page', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
      await _pumpScreen(
        tester,
        meal: null,
        authRepository: authRepository,
        dictionaryRepository: FakeFoodDictionaryRepository(
          listFavoritesError: const DietReauthenticationRequired(),
        ),
      );
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      // In dictionary mode there is no bottom bar at all, so this is the only
      // recovery exit on the page.
      await tester.tap(
        find.byKey(const Key('food-search-dictionary-sign-in-again-button')),
      );
      await tester.pumpAndSettle();

      expect(authRepository.signOutCalled, isTrue);
    });

    testWidgets('while the dictionary is still loading, shows a loading indicator rather than an empty state', (
      tester,
    ) async {
      final gate = Completer<List<FoodItem>>();
      addTearDown(() => gate.complete(const <FoodItem>[]));
      final dictionaryController = _dictionaryController(
        FakeFoodDictionaryRepository(favoritesGate: gate),
      );
      unawaited(dictionaryController.load('token-123'));
      final createMealController =
          CreateMealController(CreateMeal(FakeMealRepository()))..start(null);

      await tester.pumpWidget(
        l10nRouterTestApp(
          home: FoodSearchScreen(
            meal: null,
            dictionaryController: dictionaryController,
            createMealController: createMealController,
            idToken: 'token-123',
            day: '2026-07-18',
            signOut: SignOut(FakeAuthRepository()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('food-search-dictionary-loading')), findsOneWidget);
      expect(find.byKey(const Key('food-search-empty-favorites')), findsNothing);
    });
  });

  group('FoodSearchScreen add feedback', () {
    Future<CreateMealController> pumpForFeedback(WidgetTester tester) async {
      final dictionaryController = _dictionaryController(
        FakeFoodDictionaryRepository(),
      );
      await dictionaryController.load('token-123');
      final createMealController =
          CreateMealController(CreateMeal(FakeMealRepository()))..start('lunch');
      await tester.pumpWidget(
        l10nRouterTestApp(
          home: FoodSearchScreen(
            meal: 'lunch',
            dictionaryController: dictionaryController,
            createMealController: createMealController,
            idToken: 'token-123',
            day: '2026-07-18',
            signOut: SignOut(FakeAuthRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return createMealController;
    }

    ScrollController trayScrollController(WidgetTester tester) => tester
        .widget<ListView>(find.byKey(const Key('food-search-tray-list')))
        .controller!;

    testWidgets('adding a food scrolls the overflowing tray to reveal the newest item', (
      tester,
    ) async {
      await pumpForFeedback(tester);

      // Add enough rows to overflow the 260px-capped tray.
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
      }

      final scroll = trayScrollController(tester);
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 1.0));
    });

    testWidgets('removing an item or changing an amount does not scroll the tray to the end', (
      tester,
    ) async {
      await pumpForFeedback(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
      }

      final scroll = trayScrollController(tester);
      scroll.jumpTo(0);
      await tester.pump();

      // Change the top row's amount: must not jump to the end.
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(scroll.offset, lessThan(scroll.position.maxScrollExtent));

      // Remove the top row: must not jump to the end.
      await tester.tap(find.byTooltip(loc.dietRemoveItemTooltip).first);
      await tester.pumpAndSettle();
      expect(scroll.offset, lessThan(scroll.position.maxScrollExtent));
    });

    testWidgets('the newly added row briefly highlights then fades to transparent', (
      tester,
    ) async {
      await pumpForFeedback(tester);

      await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
      await tester.pump();

      BoxDecoration highlightDecoration() =>
          tester.widget<DecoratedBox>(
            find.byKey(const Key('tray-item-highlight-0')),
          ).decoration as BoxDecoration;

      // Non-transparent right after the add.
      expect(highlightDecoration().color!.a, greaterThan(0));

      // Fully faded back to transparent once the animation settles.
      await tester.pumpAndSettle();
      expect(highlightDecoration().color!.a, 0);
    });

    testWidgets('removing a row above the just-added one does not replay the add highlight', (
      tester,
    ) async {
      await pumpForFeedback(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      // Add two rows; the last-added is the bottom row (index 1).
      // pumpAndSettle lets its highlight fully fade before the removal.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
      }

      // Scroll to the top so the first row's remove button is on-screen and
      // hittable (the tray overflows its 260px cap after two tall rows).
      trayScrollController(tester).jumpTo(0);
      await tester.pump();

      // Remove the row ABOVE the last-added one. This shifts the last-added
      // entry from index 1 into index 0; its (already-faded) highlight must
      // NOT replay from the start.
      await tester.tap(find.byTooltip(loc.dietRemoveItemTooltip).first);
      await tester.pump();

      // One row remains — the last-added, now at index 0 — and it must stay
      // transparent, not flash the add highlight on this delete.
      final decoration =
          tester.widget<DecoratedBox>(
            find.byKey(const Key('tray-item-highlight-0')),
          ).decoration as BoxDecoration;
      expect(decoration.color!.a, 0);
    });

    testWidgets('removing a row above the just-added one MID-FADE does not restart the add highlight', (
      tester,
    ) async {
      await pumpForFeedback(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      double highlightAlpha(int index) =>
          (tester
                      .widget<DecoratedBox>(
                        find.byKey(Key('tray-item-highlight-$index')),
                      )
                      .decoration
                  as BoxDecoration)
              .color!
              .a;

      // Add two rows; the last-added is the bottom row (index 1). Let the
      // FIRST add settle, but only pump the SECOND add PART-WAY into its
      // ~900ms fade (never pumpAndSettle) so its highlight is mid-flight.
      await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to the top so the first row's remove button is hittable.
      trayScrollController(tester).jumpTo(0);
      await tester.pump();

      // The just-added row (index 1) is mid-fade: partially transparent.
      final alphaBefore = highlightAlpha(1);
      expect(alphaBefore, greaterThan(0));

      // Remove the row ABOVE the still-fading just-added row. This shifts the
      // last-added entry from index 1 into index 0, remounting its row.
      await tester.tap(find.byTooltip(loc.dietRemoveItemTooltip).first);
      await tester.pump();

      // The fade must have CONTINUED from where it was, never restarted to
      // full alpha on this delete. A remount that restarts the tween jumps
      // the alpha back UP toward the initial 0.18; a panel-driven fade only
      // ever progresses downward.
      final alphaAfter = highlightAlpha(0);
      expect(alphaAfter, lessThanOrEqualTo(alphaBefore + 0.001));
    });

    testWidgets('only the just-added row highlights, not the older rows', (
      tester,
    ) async {
      await pumpForFeedback(tester);

      await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
      await tester.pump();

      // The second add highlights only its own (index 1) row.
      expect(find.byKey(const Key('tray-item-highlight-1')), findsOneWidget);
      expect(find.byKey(const Key('tray-item-highlight-0')), findsNothing);
    });

    Future<CreateMealController> pumpReduceMotion(WidgetTester tester) async {
      final dictionaryController = _dictionaryController(
        FakeFoodDictionaryRepository(),
      );
      await dictionaryController.load('token-123');
      final createMealController =
          CreateMealController(CreateMeal(FakeMealRepository()))..start('lunch');
      await tester.pumpWidget(
        l10nTestApp(
          home: Builder(
            // Simulate the OS "reduce motion" accessibility setting.
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: FoodSearchScreen(
                meal: 'lunch',
                dictionaryController: dictionaryController,
                createMealController: createMealController,
                idToken: 'token-123',
                day: '2026-07-18',
                signOut: SignOut(FakeAuthRepository()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return createMealController;
    }

    testWidgets('reduced motion: adding a food jumps (not animates) the tray to the newest item', (
      tester,
    ) async {
      await pumpReduceMotion(tester);

      // Fill the tray so it overflows its 260px cap.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
        await tester.pumpAndSettle();
      }
      final scroll = trayScrollController(tester);
      expect(scroll.position.maxScrollExtent, greaterThan(0));

      // The final add reaches the newest item within a couple of zero-duration
      // frames, because under reduced motion the tray JUMPS to it. A 300ms
      // animateTo would not have progressed at all without advancing the clock,
      // leaving the offset near its previous (smaller) value.
      await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
      await tester.pump();
      await tester.pump();
      expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 0.5));
    });

    testWidgets('reduced motion: the newly added row shows no highlight fade', (
      tester,
    ) async {
      await pumpReduceMotion(tester);

      await tester.tap(find.byKey(const Key('food-search-result-rice-1')));
      await tester.pump();

      final decoration = tester.widget<DecoratedBox>(
        find.byKey(const Key('tray-item-highlight-0')),
      ).decoration as BoxDecoration;
      // The fade is skipped under reduced motion: transparent immediately, no
      // animation to play. (The normal path shows alpha > 0 at this point.)
      expect(decoration.color!.a, 0);
    });
  });

  group('FoodSearchScreen manual entry', () {
    testWidgets('the manual-entry link opens a form with a name field and four portion inputs', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('manual-entry-link')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('manual-entry-name-field')), findsOneWidget);
      expect(find.byKey(const Key('manual-entry-staple-field')), findsOneWidget);
      expect(find.byKey(const Key('manual-entry-meat-field')), findsOneWidget);
      expect(find.byKey(const Key('manual-entry-fruit-field')), findsOneWidget);
      expect(find.byKey(const Key('manual-entry-veg-field')), findsOneWidget);
    });

    testWidgets('zero portions show an empty field with a "0" hint (empty-zero convention)', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('manual-entry-link')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byKey(const Key('manual-entry-staple-field')));
      expect(field.controller?.text, '');
      expect(field.decoration?.hintText, '0');
    });

    testWidgets('naming a food and setting portions adds a manual tray item previewing exactly those portions', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('manual-entry-link')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('manual-entry-name-field')), '自製便當');
      await tester.enterText(find.byKey(const Key('manual-entry-staple-field')), '1');
      await tester.enterText(find.byKey(const Key('manual-entry-meat-field')), '1');
      await tester.tap(find.byKey(const Key('manual-entry-add-button')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text('自製便當'), findsOneWidget);
      expect(find.text('${loc.dietCategoryStaple} 1'), findsWidgets);
      expect(find.text('${loc.dietCategoryMeat} 1'), findsWidgets);
      // No dictionary reference: no AmountStepper for a manual row.
      expect(find.byType(SegmentedButton<bool>), findsNothing);
    });

    testWidgets('completing the tray posts the manual item with name+portions and no food_item_id', (
      tester,
    ) async {
      final mealRepository = await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('manual-entry-link')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('manual-entry-name-field')), '自製便當');
      await tester.enterText(find.byKey(const Key('manual-entry-staple-field')), '1');
      await tester.tap(find.byKey(const Key('manual-entry-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-search-done-button')));
      await tester.pumpAndSettle();

      expect(mealRepository.receivedItems, hasLength(1));
      final item = mealRepository.receivedItems!.single;
      expect(item.name, '自製便當');
      expect(item.portions?.staple, 1);
      expect(item.foodItemId, isNull);
    });

    testWidgets('a blank name does not add a tray item', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('manual-entry-link')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual-entry-add-button')));
      await tester.pumpAndSettle();

      expect(find.byType(FoodSearchScreen), findsOneWidget);
      expect(find.byKey(const Key('food-search-tray')), findsNothing);
    });
  });
}
