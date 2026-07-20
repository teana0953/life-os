import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/food_search_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

FoodItem _riceItem({double? baseGrams}) => FoodItem.fromJson({
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
  'base_grams': baseGrams,
});

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  List<FoodItem> favorites;

  FakeFoodDictionaryRepository({List<FoodItem>? favorites})
    : favorites = favorites ?? [_riceItem()];

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => favorites;

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => favorites;

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}
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
  String meal = 'lunch',
}) async {
  final resolvedDictionaryRepository =
      dictionaryRepository ?? FakeFoodDictionaryRepository();
  final resolvedMealRepository = mealRepository ?? FakeMealRepository();
  final dictionaryController = _dictionaryController(resolvedDictionaryRepository);
  await dictionaryController.load('token-123');
  final createMealController = CreateMealController(CreateMeal(resolvedMealRepository))
    ..start(meal);

  await tester.pumpWidget(
    l10nTestApp(
      home: FoodSearchScreen(
        meal: meal,
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
          favorites: [_riceItem(baseGrams: 50)],
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
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      final result = await navigatorKey.currentState!.push(
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
                      );
                      poppedResult = result as bool?;
                    },
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

    testWidgets('a tray row for a gram-enabled item does not overflow at 360dp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpScreen(
        tester,
        dictionaryRepository: FakeFoodDictionaryRepository(
          favorites: [_riceItem(baseGrams: 50)],
        ),
      );

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('food-search-tray')), findsOneWidget);
    });

    testWidgets('a tray row for a gram-enabled item does not overflow at 320dp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpScreen(
        tester,
        dictionaryRepository: FakeFoodDictionaryRepository(
          favorites: [_riceItem(baseGrams: 50)],
        ),
      );

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('food-search-tray')), findsOneWidget);
    });
  });
}
