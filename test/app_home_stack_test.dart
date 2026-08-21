import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';
import 'package:life_os/contexts/health/presentation/food_search_screen.dart';
import 'package:life_os/contexts/health/presentation/health_scaffold.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_screen.dart';

import 'app_test.dart';
import 'contexts/user/presentation/home_screen_test.dart'
    show loadedDashboardFixture;

/// The two page-stack shapes a signed-in destination can be reached in, and
/// what each one owes the back button.
///
/// **URL-driven (`go`)** — a PWA launcher shortcut, a push-notification deep
/// link, a bookmark, a web refresh. go_router rebuilds the whole stack from
/// the URL hierarchy, so every signed-in route being a CHILD of `/` is what
/// puts home underneath: the back button walks down into the app instead of
/// closing it.
///
/// **In-app (`push`)** — a tap on a home tile. An imperative push adds exactly
/// ONE page on top of what is already there; nesting must not change that into
/// building the whole ancestor chain, or a tap on the home grid's 血壓 tile
/// would silently mount (and load) the health shell nobody asked for.
///
/// Both directions are asserted, because a fix aimed at one is exactly what
/// breaks the other.
void main() {
  final testProfile = UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'user@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
    isAdmin: false,
  );

  Future<GoRouter> pumpSignedIn(
    WidgetTester tester, {
    FoodDictionaryRepository? foodDictionaryRepository,
    MealRepository? mealRepository,
    // Home renders two different dashboards — a placeholder one when it has
    // no controller at all, and the loaded one — and each builds its own
    // copy of every tile. A tile guard that only ever sees the default
    // (placeholder) branch says nothing about the loaded branch: measured by
    // mutation, sending the loaded branch's search icon to `/health` leaves
    // the placeholder-branch test green.
    HomeDashboardController? homeDashboardController,
  }) async {
    final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
    await pumpApp(
      tester,
      authRepository: authRepository,
      foodDictionaryRepository: foodDictionaryRepository,
      mealRepository: mealRepository,
      homeDashboardController: homeDashboardController,
      loginController: LoginController(SignIn(authRepository)),
      homeController: HomeController(
        GetProfile(FakeProfileRepository(testProfile)),
        SignOut(authRepository),
      ),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byKey(const Key('health-tile'))));
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  /// Where the TOP page of the stack came from. Unlike [location], this
  /// tracks an imperative `push` too: `currentConfiguration.uri` is the
  /// declarative URL and a `push` deliberately leaves it alone.
  String topMatch(GoRouter router) =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;

  /// Advances past the route transition without waiting for the tree to go
  /// quiet. Deliberately not `pumpAndSettle`: a tracker pushed straight from
  /// home may legitimately be showing a (perpetually animating) spinner while
  /// its own load is in flight, and this file is about the shape of the page
  /// stack, not about loading.
  Future<void> settleNavigation(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('URL-driven entry keeps home in the stack', () {
    for (final destination in const [
      '/care-today',
      '/health',
      '/health/vitals',
      '/finance/groups/g1',
      '/assistant',
    ]) {
      testWidgets('$destination is built on top of home, not instead of it', (
        tester,
      ) async {
        final router = await pumpSignedIn(tester);

        router.go(destination);
        await tester.pumpAndSettle();
        expect(location(router), destination);

        // `skipOffstage: false`: home is below an opaque page for most of
        // these, so it is retained but not painted. What matters is that it
        // is IN the stack — flatten the routes again and it is gone
        // entirely, which is what this catches.
        expect(
          find.byType(HomeScreen, skipOffstage: false),
          findsOneWidget,
          reason: 'a URL-driven $destination must be built on top of home',
        );
      });
    }

    testWidgets('the system back button from /care-today lands on home', (
      tester,
    ) async {
      final router = await pumpSignedIn(tester);
      router.go('/care-today');
      await tester.pumpAndSettle();

      // The Android hardware / browser back button, not a widget tap.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(location(router), '/');
      // Onstage this time (no `skipOffstage: false`): home is the visible
      // page now, not merely retained.
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the system back button from /health/vitals walks down the URL '
        'hierarchy: vitals, then the health shell, then home', (tester) async {
      final router = await pumpSignedIn(tester);
      router.go('/health/vitals');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(location(router), '/health');
      expect(find.byType(VitalsScreen), findsNothing);
      expect(find.byType(HealthScaffold), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(location(router), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('home tiles reach the screen they name', () {
    testWidgets(
      'the food portion tile opens the portion tool, not the record hub',
      (tester) async {
        final router = await pumpSignedIn(tester);

        // This tile used to push `/health/dictionary`, which is not a route:
        // the `/health/:name` catch-all swallowed it, `_trackerFor` fell
        // through to its `default`, and the user landed on the record hub
        // having asked for the portion tool.
        await tester.tap(find.byKey(const Key('home-food-dictionary')));
        await tester.pumpAndSettle();

        expect(topMatch(router), '/health/diet/dictionary');
        expect(find.byType(FoodSearchScreen), findsOneWidget);
        // Usable, not merely present: with no health shell in the stack,
        // nobody else loads the day's meal names or the favourite foods, and
        // both used to sit on their initial spinner forever.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.byType(HealthScaffold, skipOffstage: false),
          findsNothing,
          reason: 'landing on the record hub is exactly the old bug',
        );
      },
    );

    testWidgets(
      'the food portion tile\'s search icon opens the portion tool too',
      (tester) async {
        // Two separate paths to the same screen since issue #196: the tile
        // body (above) now carries the day's target and the search icon is
        // what is left of the old "查詢份量對照表" caption. An `IconButton`
        // inside the tile's `InkWell` swallows the tap it handles, so the
        // tile's own `onTap` cannot stand in for this one.
        final router = await pumpSignedIn(tester);

        await tester.tap(find.byKey(const Key('home-food-portion-search')));
        await tester.pumpAndSettle();

        expect(topMatch(router), '/health/diet/dictionary');
        expect(find.byType(FoodSearchScreen), findsOneWidget);
      },
    );

    testWidgets(
      'the search icon on the LOADED dashboard opens the portion tool too',
      (tester) async {
        // The same icon, in the other of home's two dashboard branches — the
        // one a real signed-in user with data sees. Without this the loaded
        // branch's wiring is unguarded (mutation: pointing only that branch's
        // `onActionIcon` at `/health` left the placeholder test above green).
        final router = await pumpSignedIn(
          tester,
          homeDashboardController: loadedDashboardFixture(),
        );

        await tester.tap(find.byKey(const Key('home-food-portion-search')));
        await tester.pumpAndSettle();

        expect(topMatch(router), '/health/diet/dictionary');
        expect(find.byType(FoodSearchScreen), findsOneWidget);
      },
    );

    testWidgets(
      'reaching the portion tool by URL leaves the favourites fetch to the '
      'health shell below it',
      (tester) async {
        final dictionary = _CountingFoodDictionaryRepository();
        final router = await pumpSignedIn(
          tester,
          foodDictionaryRepository: dictionary,
        );

        // The launcher shortcut. `HealthScaffold` is in this stack and loads
        // the favourites on mount, so the screen must not also fetch them —
        // two answers to the same question race, and the loser's list is the
        // one left on screen.
        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(find.byType(FoodSearchScreen), findsOneWidget);
        expect(
          dictionary.favoriteReads,
          1,
          reason: 'the shell already fetches the favourites',
        );
      },
    );

    testWidgets(
      'reaching the portion tool by URL leaves the DAY fetch to the health '
      'shell below it too',
      (tester) async {
        final meals = _CountingMealRepository();
        final router = await pumpSignedIn(tester, mealRepository: meals);
        // The one the shell's own stack owes: the diet day it rebuilds
        // underneath fetches the day, and `HealthScaffold` stands down for it
        // (issue #171). Anything this screen adds on top of that is a
        // duplicate.
        meals.reads.clear();

        router.go('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(find.byType(FoodSearchScreen), findsOneWidget);
        // Counted, not merely "loaded": the screen's stand-down check reads
        // `TodayController.loadingDay`, and on this path the shell has NOT
        // set it yet — it is still awaiting its ID token when this screen's
        // post-frame callback runs, so the flag reads `null` and the screen
        // used to fire a third identical `GET /api/meals` of its own.
        // `findsOneWidget` above cannot see that; only the count can.
        expect(
          meals.reads.length,
          2,
          reason:
              'the diet day below already fetches this day — the portion tool '
              'must not fetch it again, so 2 rather than 3. The second read '
              'is the shell\'s ONE batch request computing its `meals` '
              'section, which the issue-#171 stand-down then refuses to write '
              'onto the controller (see '
              '`app_diet_day_duplicate_fetch_test.dart`).',
        );
      },
    );

    testWidgets(
      'reaching the portion tool from home fetches the day itself',
      (tester) async {
        final meals = _CountingMealRepository();
        final router = await pumpSignedIn(tester, mealRepository: meals);
        meals.reads.clear();

        // The mirror image, and the reason the guard above cannot simply be
        // "shell in the stack or not, never fetch": with no shell below,
        // nobody else loads the day and the screen sat on a spinner forever.
        router.push('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(find.byType(FoodSearchScreen), findsOneWidget);
        expect(meals.reads.length, 1);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'reaching the portion tool from home fetches the favourites itself',
      (tester) async {
        final dictionary = _CountingFoodDictionaryRepository();
        final router = await pumpSignedIn(
          tester,
          foodDictionaryRepository: dictionary,
        );

        // No shell in this stack, so nobody else will — and before this the
        // favourites list sat on its initial spinner forever.
        router.push('/health/diet/dictionary');
        await tester.pumpAndSettle();

        expect(find.byType(FoodSearchScreen), findsOneWidget);
        expect(dictionary.favoriteReads, 1);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });

  group('in-app push still adds exactly one page', () {
    testWidgets('tapping the health tile pushes, and back returns home', (
      tester,
    ) async {
      final router = await pumpSignedIn(tester);

      await tester.tap(find.byKey(const Key('health-tile')));
      await tester.pumpAndSettle();
      expect(topMatch(router), '/health');
      expect(find.byType(HealthScaffold), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(location(router), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
      'pushing /health/vitals from home does NOT mount the health shell '
      'underneath it',
      (tester) async {
        final router = await pumpSignedIn(tester);

        router.push('/health/vitals');
        await settleNavigation(tester);

        expect(topMatch(router), '/health/vitals');
        expect(find.byType(VitalsScreen), findsOneWidget);
        // `skipOffstage: false` is the strong form: an imperative push adds
        // one page, so the ancestor `/health` route must not be built at
        // all — not even offstage. If a future change turns this push into
        // a declarative `go`, the shell appears here and loads a screenful
        // of data the user never asked for.
        expect(
          find.byType(HealthScaffold, skipOffstage: false),
          findsNothing,
          reason: 'an imperative push must not build the /health ancestor',
        );
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

        await tester.binding.handlePopRoute();
        await settleNavigation(tester);
        expect(location(router), '/');
        expect(find.byType(VitalsScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );
  });
}

/// Counts day fetches, so a test can tell "the shell fetched the day" from
/// "the shell AND the portion tool both did".
class _CountingMealRepository implements MealRepository {
  final List<String> reads = [];

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    reads.add(day);
    return DayMealsLog.fromJson({
      'day': day,
      'meals': const <dynamic>[],
      'totals': const {
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
  }) async => throw UnimplementedError();

  @override
  Future<List<String>> loggedDays(String idToken, String month) async =>
      const [];

  @override
  Future<void> patchMealItem(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) async {}

  @override
  Future<void> deleteMealItem(String idToken, String id) async {}

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async {}

  @override
  Future<void> deleteMeal(String idToken, String id) async {}
}

/// Counts favourites fetches, so a test can tell "the shell fetched them" from
/// "the shell AND the screen both did".
class _CountingFoodDictionaryRepository implements FoodDictionaryRepository {
  int favoriteReads = 0;

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async {
    favoriteReads++;
    return const [];
  }

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => const [];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}

  @override
  Future<FoodItem> createSharedItem(
    String idToken,
    SharedFoodItemInput input,
  ) async => throw UnimplementedError();

  @override
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  ) async => throw UnimplementedError();
}
