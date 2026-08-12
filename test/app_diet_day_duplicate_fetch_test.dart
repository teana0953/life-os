import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/diet_day_screen.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/shared/data_revision.dart';

import 'app_test.dart';

/// Issue #171: on a URL-driven entry under `/health/diet` (a PWA shortcut, a
/// deep link, a browser refresh) go_router rebuilds the whole page stack, so
/// `HealthScaffold` and `DietDayScreen` both mount — and both used to fetch
/// the same day.
///
/// The mount order is the ground this fix stands on, it was MEASURED, and it
/// is not what one would guess — it is not even the same across entry points:
///
///  * `/health/diet`: the CHILD goes first. `DietDayScreen` mounts, resolves
///    its token and COMPLETES its `_reloadCurrentDay()` before the
///    `HealthScaffold` widget is constructed. So by the time the shell
///    decides, there is no in-flight load left to observe — an "is a load in
///    flight?" check alone would see nothing and fetch again.
///  * `/health/diet/dictionary` (and the `target` / `food-search` URLs that
///    redirect down to the diet day): the SHELL goes first. Its `_load` body
///    reaches the decision while the diet day has only just mounted and has
///    claimed nothing yet — so the shell yields one event-loop turn before
///    reading the claim registry.
///
/// Either way the shell is the side that can observe the other, so the fix
/// lives in `health_scaffold.dart` and `diet_day_screen.dart` is untouched:
/// its mount-time reload is what pulls a re-entered diet day back to today
/// from a past day the day-nav browsed to, and deleting it brings that bug
/// back (guarded separately below).
///
/// Everything here counts requests with exact `==`, and every fake answers
/// with data that IDENTIFIES the day it was asked for: with a fake that
/// returns an empty log for every day, "never fetched" is indistinguishable
/// from "fetched, and that day is empty".
void main() {
  final testProfile = UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'user@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
    isAdmin: false,
  );

  // A fixed wall-clock "now", so the day strings below are the same under
  // TZ=UTC (CI) and UTC+8 (local): every day these tests assert on is derived
  // from this, never from the real clock.
  final fixedNow = DateTime(2026, 3, 10, 9, 30);
  const today = '2026-03-10';
  const yesterday = '2026-03-09';

  Future<GoRouter> pumpSignedIn(
    WidgetTester tester, {
    required MealRepository mealRepository,
    required DailyTargetRepository dailyTargetRepository,
    WaterRepository? waterRepository,
    AuthRepository? authRepository,
    DataRevision? dataRevision,
    DateTime Function()? clock,
  }) async {
    final auth =
        authRepository ?? FakeAuthRepository(initiallyAuthenticated: true);
    await pumpApp(
      tester,
      authRepository: auth,
      mealRepository: mealRepository,
      dailyTargetRepository: dailyTargetRepository,
      waterRepository: waterRepository,
      dataRevision: dataRevision,
      clock: clock ?? () => fixedNow,
      loginController: LoginController(SignIn(auth)),
      homeController: HomeController(
        GetProfile(FakeProfileRepository(testProfile)),
        SignOut(auth),
      ),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byKey(const Key('health-tile'))));
  }

  group('cold start: URL-driven entry fetches the day exactly once', () {
    testWidgets(
      'FOUNDATION: on /health/diet the diet day completes its own day load '
      'before the shell batch issues a single request',
      (tester) async {
        final trace = <String>[];
        final router = await pumpSignedIn(
          tester,
          mealRepository: TracingMealRepository(trace),
          dailyTargetRepository: TracingDailyTargetRepository(trace),
          waterRepository: TracingWaterRepository(trace),
        );
        trace.clear();

        router.go('/health/diet');
        await tester.pumpAndSettle();

        // The diet day's mount load is three reads, in this order: the meals
        // log, the target `TodayController.load` fetches after it, and then
        // `DailyTargetController.load`. The water day is the health shell's
        // OWN batch, and nothing else in the app reads it — so its position is
        // where the shell's `_load` body ran.
        //
        // This is an ORDER guard, deliberately independent of the de-duplication
        // itself: it stays green with the shell's stand-down reverted (that
        // only appends reads later in the trace). If the mount order ever
        // flips and the shell goes first, its batch issues the meals read and
        // the water read in the SAME synchronous pass — `water:` lands inside
        // the first three and this goes red, instead of the fix silently
        // becoming a no-op.
        expect(trace.take(3).toList(), [
          'meals:$today',
          'target:$today',
          'target:$today',
        ]);
        expect(
          trace.contains('water:$today'),
          isTrue,
          reason: 'the shell did run its own batch',
        );
      },
    );

    for (final entry in const [
      '/health/diet',
      '/health/diet/dictionary',
      // Both of these rebuild the diet day beneath them; reached by URL they
      // carry no `extra`, so they redirect back down to it.
      '/health/diet/target',
      '/health/diet/food-search',
    ]) {
      testWidgets('$entry sends one meals read and two target reads', (
        tester,
      ) async {
        final trace = <String>[];
        final meals = TracingMealRepository(trace);
        final target = TracingDailyTargetRepository(trace);
        final router = await pumpSignedIn(
          tester,
          mealRepository: meals,
          dailyTargetRepository: target,
        );
        trace.clear();

        router.go(entry);
        await tester.pumpAndSettle();

        expect(
          meals.reads,
          [today],
          reason:
              'the shell and the diet day below it must not both fetch the '
              'same day (issue #171)',
        );
        // 2, not 1, and it is NOT this change's duplicate: `TodayController.load`
        // fetches the daily target itself (today_controller.dart, right after
        // the meals log) ON TOP OF `DailyTargetController.load`. That is a
        // different duplication one layer down — two controllers each own a
        // copy of the target — and collapsing it means moving target ownership,
        // which is tracked separately (issue #175). If that lands, this number
        // becomes 1: change the number, do not restore a duplicate to keep it
        // green.
        expect(target.reads, [today, today]);
      });
    }

    testWidgets(
      'the shell stands down while the diet day fetch is still IN FLIGHT',
      (tester) async {
        final trace = <String>[];
        final gate = Completer<void>();
        final meals = TracingMealRepository(trace, holdFirstReadUntil: gate);
        final target = TracingDailyTargetRepository(trace);
        final router = await pumpSignedIn(
          tester,
          mealRepository: meals,
          dailyTargetRepository: target,
          waterRepository: TracingWaterRepository(trace),
        );
        trace.clear();

        router.go('/health/diet');
        // Frames, but no settle: the diet day's meals request is parked, so
        // the shell mounts and reaches its decision while that request is
        // unanswered. This is the shape production has (a network round trip
        // is far longer than a frame) and the one the in-flight half of the
        // check exists for — every other test here reaches the shell with the
        // diet day's load already settled.
        //
        // Pumped WITH a duration, and this is load-bearing: the shell's
        // stand-down yields one event-loop turn (a zero-duration timer), and a
        // zero-duration `pump()` does not necessarily run it. Without the
        // elapsed time the shell had not decided anything yet by the time the
        // gate opened below, and this test passed while proving nothing —
        // measured, by deleting the in-flight clause and watching it stay
        // green.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(gate.isCompleted, isFalse);
        expect(
          trace,
          contains('water:$today'),
          reason:
              'the water day is fetched only by the shell batch, in the same '
              '`Future.wait` as the two diet loads — seeing it proves the '
              'shell took its stand-down decision while the diet day request '
              'was still parked, which is the whole point of this test',
        );

        gate.complete();
        await tester.pumpAndSettle();

        expect(meals.reads, [today]);
      },
    );

    testWidgets('the diet day shows the day it fetched, not an empty day', (
      tester,
    ) async {
      final trace = <String>[];
      final router = await pumpSignedIn(
        tester,
        mealRepository: TracingMealRepository(trace),
        dailyTargetRepository: TracingDailyTargetRepository(trace),
      );

      router.go('/health/diet');
      await tester.pumpAndSettle();

      // The de-duplication must leave the data ON the screen: the one read
      // that survives is the diet day's, and its answer is what renders.
      expect(find.byType(DietDayScreen), findsOneWidget);
      expect(find.text('item-$today'), findsOneWidget);
    });
  });

  group('push from the record hub', () {
    testWidgets('tapping 飲食 in the record hub fetches the day exactly once', (
      tester,
    ) async {
      final trace = <String>[];
      final meals = TracingMealRepository(trace);
      final target = TracingDailyTargetRepository(trace);
      final router = await pumpSignedIn(
        tester,
        mealRepository: meals,
        dailyTargetRepository: target,
      );

      // Into the shell first (it loads the day itself — nobody else is in the
      // stack), then across to the record hub and into the diet day.
      router.go('/health');
      await tester.pumpAndSettle();
      expect(meals.reads, [today], reason: 'the shell alone loads the day');
      trace.clear();

      await tester.tap(find.byIcon(Icons.edit_note));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hub-tile-diet')));
      await tester.pumpAndSettle();

      // Exactly one: not 2 (the shell is already mounted and must not reload),
      // and not 0 — the diet day is the only thing that pulls the shared
      // controllers back to today, so its own fetch has to go out.
      expect(meals.reads, [today]);
      expect(find.text('item-$today'), findsOneWidget);
    });
  });

  group('re-entering the diet day pulls the shared controllers back to today', () {
    testWidgets('after browsing to a past day, leaving and returning shows '
        'today again', (tester) async {
      final trace = <String>[];
      final meals = TracingMealRepository(trace);
      final target = TracingDailyTargetRepository(trace);
      final router = await pumpSignedIn(
        tester,
        mealRepository: meals,
        dailyTargetRepository: target,
      );

      router.go('/health/diet');
      await tester.pumpAndSettle();
      expect(find.text('item-$today'), findsOneWidget);

      // Browse one day back: the day-nav mutates the SHARED controllers.
      await tester.tap(find.byKey(const Key('day-nav-previous')));
      await tester.pumpAndSettle();
      expect(find.text('item-$yesterday'), findsOneWidget);
      expect(find.text('item-$today'), findsNothing);

      // Leave the diet day (the shell stays mounted below), then come back.
      router.go('/health');
      await tester.pumpAndSettle();
      trace.clear();
      router.go('/health/diet');
      await tester.pumpAndSettle();

      // The shared controllers were left holding YESTERDAY, so the diet day's
      // own mount reload is the only thing that can put today back — with it
      // gone this shows `item-$yesterday`, the "screen says A, data is B" bug
      // this module keeps producing.
      expect(find.text('item-$today'), findsOneWidget);
      expect(find.text('item-$yesterday'), findsNothing);
      // And it costs exactly one meals read: the shell does not remount here,
      // so nothing else fetched.
      expect(meals.reads, [today]);
      expect(target.reads, [today, today]);
    });
  });

  group('forced refreshes still re-issue every request', () {
    testWidgets('a DataRevision bump refetches the day every time', (
      tester,
    ) async {
      final trace = <String>[];
      final meals = TracingMealRepository(trace);
      final revision = DataRevision();
      final router = await pumpSignedIn(
        tester,
        mealRepository: meals,
        dailyTargetRepository: TracingDailyTargetRepository(trace),
        dataRevision: revision,
      );
      trace.clear();

      router.go('/health/diet');
      await tester.pumpAndSettle();
      expect(meals.reads, [today], reason: 'the mount round stands down');

      // Bumped WITHOUT leaving `/health/diet`, and that placement is the
      // point: the diet day is still in the stack and the controllers still
      // hold today, so every ingredient of the mount-time stand-down is
      // present and only "first round only" stops it applying. A bump means
      // "the data behind you changed" (a chaodays import writes meals) —
      // standing down here would show the user pre-import data with no way to
      // refresh short of restarting the app.
      revision.bump();
      await tester.pumpAndSettle();
      expect(meals.reads, [today, today]);

      revision.bump();
      await tester.pumpAndSettle();
      expect(meals.reads, [today, today, today]);
    });

    testWidgets('pull-to-refresh on the overview refetches the day', (
      tester,
    ) async {
      final trace = <String>[];
      final meals = TracingMealRepository(trace);
      final router = await pumpSignedIn(
        tester,
        mealRepository: meals,
        dailyTargetRepository: TracingDailyTargetRepository(trace),
      );
      trace.clear();

      router.go('/health/diet');
      await tester.pumpAndSettle();
      expect(meals.reads, [today]);

      // Back onto the shell's overview and pull down: an explicit user request
      // for fresh data, which "we already have this day" must never swallow.
      // Note the diet day is necessarily OUT of the stack here (the overview
      // is what it covers), so it is the sibling `DataRevision` test above —
      // bumped while the diet day is still below — that pins the "first round
      // only" half of the condition.
      router.go('/health');
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(meals.reads, [today, today]);
    });
  });

  group('entering the shell fresh still refetches', () {
    testWidgets('re-entering /health with no diet day in the stack reloads the '
        'day it already holds', (tester) async {
      final trace = <String>[];
      final meals = TracingMealRepository(trace);
      final router = await pumpSignedIn(
        tester,
        mealRepository: meals,
        dailyTargetRepository: TracingDailyTargetRepository(trace),
      );
      trace.clear();

      router.go('/health');
      await tester.pumpAndSettle();
      expect(meals.reads, [today]);

      // Out of the health module entirely and back in. The shared controllers
      // still HOLD today from the visit above — which must not be mistaken for
      // "somebody in this stack is fetching it". Nobody is: there is no diet
      // day below this time, so a shell that stood down here would show data
      // of unbounded age (and, on a long-lived PWA, from a previous day).
      router.go('/');
      await tester.pumpAndSettle();
      router.go('/health');
      await tester.pumpAndSettle();

      expect(meals.reads, [today, today]);
    });
  });

  group('cold start across midnight', () {
    testWidgets('the shell fetches its own day when the diet day was built on '
        'the previous one', (tester) async {
      final trace = <String>[];
      final meals = TracingMealRepository(trace);
      final target = TracingDailyTargetRepository(trace);
      final water = TracingWaterRepository(trace);
      final auth = GatedAuthRepository();
      var now = DateTime(2026, 3, 10, 23, 59, 30);
      final router = await pumpSignedIn(
        tester,
        mealRepository: meals,
        dailyTargetRepository: target,
        waterRepository: water,
        authRepository: auth,
        clock: () => now,
      );
      trace.clear();

      // Hold every token request: both screens ask for one as the first
      // statement of their load, so nothing gets past that point until this is
      // released — which is where the clock rolls over.
      auth.hold = true;
      router.go('/health/diet');
      await tester.pump();
      await tester.pump();

      // `DietDayScreen` froze its day when it was built (its header already
      // says 3/10); the shell resolves "today" only after its token lands.
      now = DateTime(2026, 3, 11, 0, 0, 30);
      auth.releaseAll();
      await tester.pumpAndSettle();

      // Two DIFFERENT days, not one day twice: nobody else is fetching the
      // 11th, so a shell that stood down here would leave a day nobody loaded
      // — the day-keyed half of the check is what prevents that.
      // The water read is the shell's own batch: it proves the shell did run
      // — and that it ran on the NEW day — so the meals expectation below is
      // about a shell that decided, not one that never got there.
      expect(trace.where((e) => e.startsWith('water:')).toList(), [
        'water:2026-03-11',
      ]);
      expect(meals.reads, ['2026-03-10', '2026-03-11']);
      expect(target.reads, [
        '2026-03-10',
        '2026-03-10',
        '2026-03-11',
        '2026-03-11',
      ]);
    });
  });
}

/// Records every `GET /api/meals` with the day it asked for, and answers with
/// data that IDENTIFIES that day — an item named `item-<day>`. A fake that
/// returns an empty log for every day lets "never fetched" masquerade as
/// "fetched, and that day happens to be empty".
class TracingMealRepository implements MealRepository {
  final List<String> trace;

  /// When set, the FIRST read parks on this before answering — the shape a
  /// real network round trip has, and the only way to reach the shell's
  /// decision with the diet day's load still in flight.
  final Completer<void>? holdFirstReadUntil;
  bool _held = false;

  TracingMealRepository(this.trace, {this.holdFirstReadUntil});

  List<String> get reads => trace
      .where((e) => e.startsWith('meals:'))
      .map((e) => e.substring('meals:'.length))
      .toList();

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    trace.add('meals:$day');
    if (holdFirstReadUntil != null && !_held) {
      _held = true;
      await holdFirstReadUntil!.future;
    }
    return DayMealsLog.fromJson({
      'day': day,
      'meals': [
        {
          'id': 'meal-$day',
          'meal': 'lunch',
          'time': '2026-01-01T12:00:00.000Z',
          'items': [
            {
              'id': 'item-id-$day',
              'food_item_id': 'food-1',
              'name': 'item-$day',
              'source': 'dictionary',
              'quantity': 1,
              'staple': 1,
              'meat': 0,
              'fruit': 0,
              'veg': 0,
              'base_amount': null,
              'measure_unit': null,
              'consumed': {'staple': 1, 'meat': 0, 'fruit': 0, 'veg': 0},
            },
          ],
        },
      ],
      'totals': const {
        'carb_g': 0,
        'protein_g': 0,
        'fat_g': 0,
        'sugar_g': 0,
        'fiber_g': 0,
        'kcal': 0,
        'staple': 1,
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

/// Records every `GET /api/daily-target` and answers with a target whose day
/// (and, derived from it, base staple) identifies the day asked for — same
/// reason as [TracingMealRepository].
class TracingDailyTargetRepository implements DailyTargetRepository {
  final List<String> trace;
  TracingDailyTargetRepository(this.trace);

  List<String> get reads => trace
      .where((e) => e.startsWith('target:'))
      .map((e) => e.substring('target:'.length))
      .toList();

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    trace.add('target:$day');
    final marker = double.parse(day.substring(8));
    return DailyTargetWithRemaining(
      day: day,
      base: Portions(staple: marker, meat: 0, fruit: 0, veg: 0),
      bonus: const Portions(staple: 0, meat: 0, fruit: 0, veg: 0),
      effective: Portions(staple: marker, meat: 0, fruit: 0, veg: 0),
      logged: const Portions(staple: 1, meat: 0, fruit: 0, veg: 0),
      remaining: Portions(staple: marker - 1, meat: 0, fruit: 0, veg: 0),
    );
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
  }) async => throw UnimplementedError();
}

/// The health shell's own batch, observed: nothing but `HealthScaffold._load`
/// reads the water day on these routes, so where this lands in the shared
/// trace is where the shell's load body ran.
class TracingWaterRepository implements WaterRepository {
  final List<String> trace;
  TracingWaterRepository(this.trace);

  @override
  Future<WaterDay> getDay(String idToken, String day) async {
    trace.add('water:$day');
    return WaterDay(day: day, totalMl: 0, targetMl: 2000, remainingMl: 2000);
  }

  @override
  Future<int> addWater(
    String idToken, {
    required String day,
    required int addMl,
  }) async => throw UnimplementedError();

  @override
  Future<int> setTarget(
    String idToken, {
    required String day,
    required int targetMl,
  }) async => throw UnimplementedError();
}

/// A signed-in auth repository whose ID-token resolution can be parked. Every
/// day-keyed load in the app starts with `await idToken()`, so holding it is
/// how a test suspends both screens at the same point and moves the clock
/// between the diet day being built and the shell resolving "today".
class GatedAuthRepository implements AuthRepository {
  bool hold = false;
  final _waiting = <Completer<void>>[];

  /// Releases everything parked so far AND stops parking: a request that
  /// arrives after this (the shell's, if it mounts a frame later) must
  /// resolve on its own, or the shell would never run its batch at all and
  /// the test would "pass" having proved nothing.
  void releaseAll() {
    hold = false;
    for (final c in _waiting) {
      if (!c.isCompleted) c.complete();
    }
    _waiting.clear();
  }

  @override
  Future<String?> idToken() async {
    if (hold) {
      final completer = Completer<void>();
      _waiting.add(completer);
      await completer.future;
    }
    return 'fake-token';
  }

  @override
  Stream<bool> get authStateChanges async* {
    yield true;
  }

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}
}
