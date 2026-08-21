import 'package:life_os/shared/screen_batch/section_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/exercise/application/add_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/delete_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/get_exercise_day.dart';
import 'package:life_os/contexts/exercise/application/list_exercise_activities.dart';
import 'package:life_os/contexts/exercise/domain/exercise_day.dart';
import 'package:life_os/contexts/exercise/domain/exercise_exceptions.dart';
import 'package:life_os/contexts/exercise/domain/exercise_repository.dart';
import 'package:life_os/contexts/exercise/presentation/exercise_controller.dart';

/// A stateful in-memory fake: append/remove mutate a per-day entry list so a
/// re-read after a mutation reflects the change (the controller re-reads, never
/// computes the total itself).
class FakeExerciseRepository implements ExerciseRepository {
  final Map<String, List<ExerciseEntry>> _byDay = {};
  int _nextId = 1;
  int listActivitiesCallCount = 0;
  Object? failListActivities;
  Object? failGetDay;
  Object? failAddEntry;
  Object? failDeleteEntry;

  @override
  Future<List<ExerciseActivity>> listActivities(String idToken) async {
    listActivitiesCallCount++;
    if (failListActivities != null) throw failListActivities!;
    return const [
      ExerciseActivity(
        id: 'jogging',
        name: '慢跑',
        category: 'aerobic',
        intensity: '8km/hr',
      ),
      ExerciseActivity(
        id: 'squats',
        name: '深蹲',
        category: 'anaerobic',
        intensity: '',
      ),
    ];
  }

  @override
  Future<ExerciseDay> getDay(String idToken, String day) async {
    if (failGetDay != null) throw failGetDay!;
    final entries = _byDay[day] ?? const [];
    return ExerciseDay(
      day: day,
      entries: List.of(entries),
      totalMinutes: entries.fold(0, (sum, e) => sum + e.durationMinutes),
    );
  }

  @override
  Future<ExerciseEntry> addEntry(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  }) async {
    if (failAddEntry != null) throw failAddEntry!;
    final entry = ExerciseEntry(
      id: 'e${_nextId++}',
      activityId: activityId,
      activityName: activityId,
      category: 'aerobic',
      durationMinutes: durationMinutes,
      note: note,
      createdAt: DateTime.utc(2026, 7, 18, 9),
    );
    (_byDay[day] ??= []).add(entry);
    return entry;
  }

  @override
  Future<bool> deleteEntry(String idToken, String entryId) async {
    if (failDeleteEntry != null) throw failDeleteEntry!;
    for (final entries in _byDay.values) {
      entries.removeWhere((e) => e.id == entryId);
    }
    return true;
  }
}

void main() {
  group('ExerciseController.applyBatchSection', () {
    const activities = [
      ExerciseActivity(
        id: 'jogging',
        name: '慢跑',
        category: 'aerobic',
        intensity: '8km/hr',
      ),
      ExerciseActivity(
        id: 'squats',
        name: '深蹲',
        category: 'anaerobic',
        intensity: '',
      ),
    ];

    test(
      'ok lands the identical state load() lands for the same payloads',
      () async {
        final at = DateTime(2026, 7, 18, 9, 30);
        final viaLoad = ExerciseController(
          ListExerciseActivities(FakeExerciseRepository()),
          GetExerciseDay(FakeExerciseRepository()),
          AddExerciseEntry(FakeExerciseRepository()),
          DeleteExerciseEntry(FakeExerciseRepository()),
          clock: () => at,
        );
        await viaLoad.load('token', '2026-07-18');

        final viaBatch = ExerciseController(
          ListExerciseActivities(FakeExerciseRepository()),
          GetExerciseDay(FakeExerciseRepository()),
          AddExerciseEntry(FakeExerciseRepository()),
          DeleteExerciseEntry(FakeExerciseRepository()),
          clock: () => at,
        );
        viaBatch.claimBatchRound();
        viaBatch.applyBatchSection(
          activities: const SectionOk(activities),
          exercise: SectionOk(viaLoad.day!),
        );

        expect(viaBatch.status, viaLoad.status);
        expect(viaBatch.error, viaLoad.error);
        expect(viaBatch.lastLoadedAt, viaLoad.lastLoadedAt);
        expect(
          viaBatch.activities.map((a) => a.id),
          viaLoad.activities.map((a) => a.id),
        );
        expect(viaBatch.day!.totalMinutes, viaLoad.day!.totalMinutes);
      },
    );

    test('an unavailable exercise section reaches the fetch-failed state', () {
      final controller = _controller(FakeExerciseRepository());

      controller.claimBatchRound();
      controller.applyBatchSection(
        activities: const SectionOk(activities),
        exercise: const SectionUnavailable<ExerciseDay>(),
      );

      expect(controller.status, ExerciseStatus.error);
      expect(controller.error, ExerciseError.fetchFailed);
      expect(controller.day, isNull);
      expect(controller.lastLoadedAt, isNull);
    });

    test('reauth on either section reaches needsReauth', () {
      final controller = _controller(FakeExerciseRepository());

      controller.claimBatchRound();
      controller.applyBatchSection(
        activities: const SectionOk(activities),
        exercise: const SectionReauth<ExerciseDay>(),
      );

      expect(controller.status, ExerciseStatus.needsReauth);
    });

    // load() only reads the library when it has none — so a failed library
    // section is only a failure when the library was going to be read.
    test(
      'a failed activities section is ignored once the library is held',
      () async {
        final controller = _controller(FakeExerciseRepository());
        await controller.load('token', '2026-07-18');
        final day = controller.day!;

        controller.claimBatchRound();
        controller.applyBatchSection(
          activities: const SectionUnavailable<List<ExerciseActivity>>(),
          exercise: SectionOk(day),
        );

        expect(controller.status, ExerciseStatus.loaded);
        expect(controller.activities, isNotEmpty);
      },
    );

    test('a failed activities section fails the card when none is held', () {
      final controller = _controller(FakeExerciseRepository());

      controller.claimBatchRound();
      controller.applyBatchSection(
        activities: const SectionUnavailable<List<ExerciseActivity>>(),
        exercise: SectionOk(
          const ExerciseDay(day: '2026-07-18', entries: [], totalMinutes: 0),
        ),
      );

      expect(controller.status, ExerciseStatus.error);
      expect(controller.error, ExerciseError.fetchFailed);
      expect(controller.day, isNull);
    });

    // A section with no claim at all (nobody called `claimBatchRound`) must
    // never apply by accident.
    test('a section nobody claimed a round for is dropped', () {
      final controller = _controller(FakeExerciseRepository());

      controller.applyBatchSection(
        activities: const SectionOk(activities),
        exercise: SectionOk(
          const ExerciseDay(day: '2026-07-18', entries: [], totalMinutes: 0),
        ),
      );

      expect(controller.day, isNull);
    });

    test(
      'a section is dropped when a load starts after the round was claimed',
      () async {
        final controller = _controller(FakeExerciseRepository());
        controller.claimBatchRound();
        final other = controller.load('token', '2026-07-19');

        controller.applyBatchSection(
          activities: const SectionOk(activities),
          exercise: SectionOk(
            const ExerciseDay(day: '2026-07-18', entries: [], totalMinutes: 0),
          ),
        );
        expect(controller.day, isNull);

        await other;
        expect(controller.day!.day, '2026-07-19');
      },
    );

    test(
      'a section is dropped when a load already landed after the round was claimed',
      () async {
        final controller = _controller(FakeExerciseRepository());
        controller.claimBatchRound();
        await controller.load('token', '2026-07-19');
        expect(controller.day!.day, '2026-07-19');

        controller.applyBatchSection(
          activities: const SectionOk(activities),
          exercise: SectionOk(
            const ExerciseDay(day: '2026-07-18', entries: [], totalMinutes: 0),
          ),
        );

        expect(controller.day!.day, '2026-07-19');
      },
    );

    // The over-correction a day comparison would cause: a round whose day
    // simply differs from whatever day the controller already holds must
    // still apply, as long as nothing navigated since the round was claimed.
    test(
      'a section applies even when its day differs from the day already held, '
      'as long as nothing navigated since the round was claimed',
      () async {
        final controller = _controller(FakeExerciseRepository());
        await controller.load('token', '2026-07-17');
        expect(controller.day!.day, '2026-07-17');

        controller.claimBatchRound();
        const freshDay = ExerciseDay(
          day: '2026-07-18',
          entries: [],
          totalMinutes: 0,
        );
        controller.applyBatchSection(
          activities: const SectionOk(activities),
          exercise: const SectionOk(freshDay),
        );

        expect(controller.day!.day, '2026-07-18');
      },
    );
  });

  const day = '2026-07-18';

  test('load fetches the day and the activity library', () async {
    final controller = _controller(FakeExerciseRepository());

    await controller.load('tok', day);

    expect(controller.status, ExerciseStatus.loaded);
    expect(controller.day!.totalMinutes, 0);
    expect(controller.activities, hasLength(2));
  });

  test('load caches the activity library across days', () async {
    final repo = FakeExerciseRepository();
    final controller = _controller(repo);

    await controller.load('tok', day);
    await controller.load('tok', '2026-07-17');

    expect(repo.listActivitiesCallCount, 1);
  });

  test('addEntry re-reads the day so the total grows', () async {
    final controller = _controller(FakeExerciseRepository());
    await controller.load('tok', day);

    await controller.addEntry(
      'tok',
      day,
      activityId: 'jogging',
      durationMinutes: 30,
      note: '',
    );

    expect(controller.status, ExerciseStatus.loaded);
    expect(controller.day!.entries, hasLength(1));
    expect(controller.day!.totalMinutes, 30);
  });

  test('deleteEntry re-reads the day so the total drops', () async {
    final controller = _controller(FakeExerciseRepository());
    await controller.load('tok', day);
    await controller.addEntry(
      'tok',
      day,
      activityId: 'jogging',
      durationMinutes: 30,
      note: '',
    );
    final id = controller.day!.entries.single.id;

    await controller.deleteEntry('tok', day, id);

    expect(controller.day!.entries, isEmpty);
    expect(controller.day!.totalMinutes, 0);
  });

  test('a 401 on load surfaces needsReauth', () async {
    final repo = FakeExerciseRepository()
      ..failGetDay = const ExerciseReauthenticationRequired();
    final controller = _controller(repo);

    await controller.load('tok', day);

    expect(controller.status, ExerciseStatus.needsReauth);
  });

  test('a fetch failure on load surfaces an error state', () async {
    final repo = FakeExerciseRepository()
      ..failGetDay = const ExerciseFetchFailure();
    final controller = _controller(repo);

    await controller.load('tok', day);

    expect(controller.status, ExerciseStatus.error);
    expect(controller.error, ExerciseError.fetchFailed);
  });

  group('ExerciseController.lastLoadedAt', () {
    final at = DateTime(2026, 7, 18, 9, 41);

    ExerciseController controllerWithClock(FakeExerciseRepository repo) =>
        ExerciseController(
          ListExerciseActivities(repo),
          GetExerciseDay(repo),
          AddExerciseEntry(repo),
          DeleteExerciseEntry(repo),
          clock: () => at,
        );

    test('is null before the first successful load', () {
      final controller = controllerWithClock(FakeExerciseRepository());
      expect(controller.lastLoadedAt, isNull);
    });

    test('is set to the clock value on a successful load', () async {
      final controller = controllerWithClock(FakeExerciseRepository());

      await controller.load('tok', day);

      expect(controller.lastLoadedAt, at);
    });

    test('is left unchanged when a load fails (needsReauth)', () async {
      final repo = FakeExerciseRepository();
      final controller = controllerWithClock(repo);
      await controller.load('tok', day);
      final firstLoad = controller.lastLoadedAt;

      repo.failGetDay = const ExerciseReauthenticationRequired();
      await controller.load('tok', day);

      expect(controller.status, ExerciseStatus.needsReauth);
      expect(controller.lastLoadedAt, firstLoad);
    });

    test('stays null after a failed load with no prior success', () async {
      final repo = FakeExerciseRepository()
        ..failGetDay = const ExerciseFetchFailure();
      final controller = controllerWithClock(repo);

      await controller.load('tok', day);

      expect(controller.status, ExerciseStatus.error);
      expect(controller.lastLoadedAt, isNull);
    });
  });
}

ExerciseController _controller(FakeExerciseRepository repo) =>
    ExerciseController(
      ListExerciseActivities(repo),
      GetExerciseDay(repo),
      AddExerciseEntry(repo),
      DeleteExerciseEntry(repo),
    );
