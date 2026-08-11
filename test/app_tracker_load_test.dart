import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/bowel/domain/bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_exceptions.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';
import 'package:life_os/contexts/exercise/domain/exercise_day.dart';
import 'package:life_os/contexts/exercise/domain/exercise_exceptions.dart';
import 'package:life_os/contexts/exercise/domain/exercise_repository.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_exceptions.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_exceptions.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_exceptions.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import 'app_test.dart';

/// A tracker pushed straight from the home grid has NO health shell in the
/// stack — and the shell is what used to load every tracker's day. The
/// controller therefore sat in its initial `loading` state with nobody left to
/// leave it: a spinner that never stopped. `_TrackerLoadGate` is the fix, and
/// these are the four things it owes each of the five trackers:
///
///  1. pushed from home, the day loads (exactly once) and the screen is usable;
///  2. entered by URL — where the shell IS in the stack and loads the same
///     day — the gate stands down, because a second answer landing later
///     OVERWRITES the screen's state (that is how `?add=glucose` lost the
///     reading its shortcut had just opened);
///  3. re-entering from home reuses what is already on the controller;
///  4. a failed load reaches the screen's own error copy, not a stuck spinner;
///  5. arriving while the shell's own load is still in flight waits for it
///     rather than firing a second one.
///
/// There is no midnight-rollover case: a route's `builder` runs once per page
/// and is not re-run when `App` rebuilds (measured), so the day these screens
/// were built with never changes underneath them — a pre-existing property of
/// the health routes that the gate neither introduces nor can repair.
void main() {
  final testProfile = UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'user@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
    isAdmin: false,
  );
  final en = lookupAppLocalizations(const Locale('en'));

  /// One tracker's wiring: how to build a call-counting repository for it,
  /// where it lives, and what its own failure copy says.
  ///
  /// Kept as a table so all five get identical treatment — the trackers are
  /// five copies of one problem, and a hand-written case per tracker is how
  /// one of them quietly ends up with a weaker assertion than the rest.
  final trackers =
      <
        ({
          String name,
          String path,
          _CountingRepository Function() repository,
          String errorText,
        })
      >[
        (
          name: 'water',
          path: '/health/water',
          repository: _CountingWaterRepository.new,
          errorText: en.errorWaterLoadFailed,
        ),
        (
          name: 'vitals',
          path: '/health/vitals',
          repository: _CountingVitalsRepository.new,
          errorText: en.errorVitalsLoadFailed,
        ),
        (
          name: 'bowel',
          path: '/health/bowel',
          repository: _CountingBowelRepository.new,
          errorText: en.errorBowelLoadFailed,
        ),
        (
          name: 'exercise',
          path: '/health/exercise',
          repository: _CountingExerciseRepository.new,
          errorText: en.errorExerciseLoadFailed,
        ),
        (
          name: 'menstrual',
          path: '/health/menstrual',
          // Not day-keyed: `getOverview` takes no day, so its recorded "day" is
          // a fixed sentinel.
          repository: _CountingMenstrualRepository.new,
          errorText: en.errorMenstrualLoadFailed,
        ),
      ];

  Future<GoRouter> pumpSignedIn(
    WidgetTester tester, {
    required _CountingRepository repository,
    DateTime Function()? clock,
  }) async {
    final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
    await pumpApp(
      tester,
      authRepository: authRepository,
      loginController: LoginController(SignIn(authRepository)),
      homeController: HomeController(
        GetProfile(FakeProfileRepository(testProfile)),
        SignOut(authRepository),
      ),
      waterRepository: repository is WaterRepository
          ? repository as WaterRepository
          : null,
      vitalsRepository: repository is VitalsRepository
          ? repository as VitalsRepository
          : null,
      bowelRepository: repository is BowelRepository
          ? repository as BowelRepository
          : null,
      exerciseRepository: repository is ExerciseRepository
          ? repository as ExerciseRepository
          : null,
      menstrualRepository: repository is MenstrualRepository
          ? repository as MenstrualRepository
          : null,
      clock: clock,
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byKey(const Key('health-tile'))));
  }

  for (final tracker in trackers) {
    group('${tracker.name} loads itself when nothing else will', () {
      testWidgets('pushed from home, it loads its day exactly once', (
        tester,
      ) async {
        final repository = tracker.repository();
        final router = await pumpSignedIn(tester, repository: repository);
        // The home grid's own tiles push (never `go`), so nothing above this
        // route is in the stack — including the health shell that used to be
        // the only caller of `load`.
        expect(
          repository.reads,
          isEmpty,
          reason: 'nothing should have read this tracker from the home screen',
        );

        router.push(tracker.path);
        // `pumpAndSettle` is itself half the assertion: an unloaded tracker
        // shows a `CircularProgressIndicator`, which animates forever, so
        // before the gate existed this call TIMED OUT rather than failing an
        // expectation.
        await tester.pumpAndSettle();

        expect(
          repository.reads.length,
          1,
          reason: 'the gate must load the day, and load it once',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets(
        'entered by URL, where the health shell IS in the stack, it stands '
        'down and lets the shell load',
        (tester) async {
          final repository = tracker.repository();
          final router = await pumpSignedIn(tester, repository: repository);

          // `go`: the stack is rebuilt as [home, health shell, tracker], and
          // the shell loads every tracker on mount. A second read here is not
          // merely wasteful — whichever answer lands last overwrites the
          // screen's state, and on `/health/vitals?add=glucose` that wipes
          // out the empty reading the launcher shortcut just opened.
          router.go(tracker.path);
          await tester.pumpAndSettle();

          expect(
            repository.reads.length,
            1,
            reason: 'the shell loads this; the gate must not load it again',
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );

      testWidgets('re-entering from home reuses what the first visit loaded', (
        tester,
      ) async {
        final repository = tracker.repository();
        final router = await pumpSignedIn(tester, repository: repository);

        router.push(tracker.path);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        router.push(tracker.path);
        await tester.pumpAndSettle();

        // The controllers are app-lifetime, so the day is still on them.
        // Refetching would put a spinner over data already on screen.
        expect(
          repository.reads.length,
          1,
          reason: 'the controller already holds this day',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets(
        'opened from a health shell that already finished loading, it reuses '
        'that data instead of fetching again',
        (tester) async {
          final repository = tracker.repository();
          final router = await pumpSignedIn(tester, repository: repository);

          router.go('/health');
          await tester.pumpAndSettle();
          expect(repository.reads.length, 1);

          // The ordinary path from inside the health shell: its own tracker
          // tile. The data is already on the shared controller — refetching
          // it would put a spinner over data the user can already see.
          router.push(tracker.path);
          await tester.pumpAndSettle();

          expect(
            repository.reads.length,
            1,
            reason: 'the controller already holds this day',
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );

      testWidgets(
        'opened from a shell whose load already FAILED, the gate still '
        'stands down and the screen shows that failure',
        (tester) async {
          final repository = tracker.repository()..failing = true;
          final router = await pumpSignedIn(tester, repository: repository);

          // The shell loads every tracker on mount, and this one's read
          // fails — leaving the controller in `error`, where the screen has
          // its own copy and its own exit.
          router.go('/health');
          await tester.pumpAndSettle();
          expect(repository.reads.length, 1);

          router.push(tracker.path);
          await tester.pumpAndSettle();

          expect(find.text(tracker.errorText), findsOneWidget);
          // What actually stops the second read is [_healthShellInStack] —
          // `/health` is still in the match list under this push, so the gate
          // returns before it ever looks at the controller. Spelled out
          // because the gate has NO "already failed" branch of its own: read
          // as one, this test would promise a behaviour nothing implements.
          // It is worth pinning all the same — a gate that keyed off "the
          // controller has no data" instead would re-request here, turning
          // every visit after a failed shell load into a second hit on a
          // backend that just failed.
          expect(
            repository.reads.length,
            1,
            reason: 'the shell is in the stack — the gate must not re-request',
          );
        },
      );

      testWidgets(
        'opened from a health shell whose load is still in flight, it waits '
        'for that load instead of firing its own',
        (tester) async {
          final repository = tracker.repository();
          final router = await pumpSignedIn(tester, repository: repository);

          // Hold the shell's read open so the tracker is opened DURING it —
          // the timing that would race two answers for the same day.
          //
          // Note what does the work: `_healthShellInStack`, not an in-flight
          // flag. The gate deliberately has none, because its decision runs
          // BEFORE `HealthScaffold.initState` has awaited its ID token, so
          // at decision time nothing is in flight to observe. (The
          // controller's `status` is no help either: `loading` is also its
          // initial value, so it cannot tell "the shell is fetching" from
          // "nobody has fetched at all".)
          repository.inFlight = Completer<void>();
          router.go('/health');
          await tester.pump();
          await tester.pump();
          expect(
            repository.reads.length,
            1,
            reason: 'the shell should have started its read by now',
          );

          router.push(tracker.path);
          await tester.pump();
          await tester.pump();
          expect(
            repository.reads.length,
            1,
            reason: 'the shell is in the stack — the gate must stand down',
          );

          repository.inFlight!.complete();
          await tester.pumpAndSettle();

          expect(repository.reads.length, 1);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );
    });
  }
}

/// The shared shape of the five counting fakes: which days were actually
/// fetched, and a switch to make the fetch fail. Named `failing`, not `fail`:
/// the test package exports a top-level `fail()` that would shadow it.
abstract class _CountingRepository {
  final List<String> reads = [];

  /// When set, every read records itself and then BLOCKS on this future —
  /// letting a test hold a load in flight and act while it is.
  Completer<void>? inFlight;
  bool failing = false;
}

class _CountingWaterRepository extends _CountingRepository
    implements WaterRepository {
  @override
  Future<WaterDay> getDay(String idToken, String day) async {
    reads.add(day);
    if (inFlight != null) await inFlight!.future;
    if (failing) throw const WaterFetchFailure('boom');
    return WaterDay(day: day, totalMl: 0, targetMl: 2000, remainingMl: 2000);
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

class _CountingVitalsRepository extends _CountingRepository
    implements VitalsRepository {
  @override
  Future<VitalsDay> getDay(String idToken, String day) async {
    reads.add(day);
    if (inFlight != null) await inFlight!.future;
    if (failing) throw const VitalsFetchFailure('boom');
    return VitalsDay(
      day: day,
      weightKg: null,
      bodyFatPct: null,
      waistCm: null,
      bpReadings: const [],
      glucoseReadings: const [],
      spo2Readings: const [],
    );
  }

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) async => day;

  @override
  Future<VitalsRange> getRange(
    String idToken,
    DateTime from,
    DateTime to,
  ) async => VitalsRange(
    from: from,
    to: to,
    series: const VitalsSeries(
      weight: [],
      bodyFat: [],
      waist: [],
      systolic: [],
      diastolic: [],
      pulse: [],
      glucose: [],
      spo2: [],
    ),
  );
}

class _CountingBowelRepository extends _CountingRepository
    implements BowelRepository {
  @override
  Future<BowelDay> getDay(String idToken, String day) async {
    reads.add(day);
    if (inFlight != null) await inFlight!.future;
    if (failing) throw const BowelFetchFailure('boom');
    return BowelDay(day: day, count: 0, isNormal: null, note: '');
  }

  @override
  Future<BowelDay> save(
    String idToken, {
    required String day,
    required int count,
    required bool? isNormal,
    required String note,
  }) async => BowelDay(day: day, count: count, isNormal: isNormal, note: note);
}

class _CountingExerciseRepository extends _CountingRepository
    implements ExerciseRepository {
  @override
  Future<List<ExerciseActivity>> listActivities(String idToken) async =>
      const [];

  @override
  Future<ExerciseDay> getDay(String idToken, String day) async {
    reads.add(day);
    if (inFlight != null) await inFlight!.future;
    if (failing) throw const ExerciseFetchFailure();
    return ExerciseDay(day: day, entries: const [], totalMinutes: 0);
  }

  @override
  Future<ExerciseEntry> addEntry(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  }) async => throw UnimplementedError();

  @override
  Future<bool> deleteEntry(String idToken, String entryId) async => true;
}

class _CountingMenstrualRepository extends _CountingRepository
    implements MenstrualRepository {
  /// `getOverview` takes no day, so reads are recorded under a fixed marker —
  /// the count is what matters for this tracker.
  static const overviewMarker = 'overview';

  @override
  Future<MenstrualOverview> getOverview(String idToken) async {
    reads.add(overviewMarker);
    if (inFlight != null) await inFlight!.future;
    if (failing) throw const MenstrualFetchFailure();
    return const MenstrualOverview(periods: [], stats: MenstrualStats());
  }

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) async => throw UnimplementedError();

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async => throw UnimplementedError();

  @override
  Future<bool> deletePeriod(String idToken, String id) async => true;
}
