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
}

ExerciseController _controller(FakeExerciseRepository repo) => ExerciseController(
  ListExerciseActivities(repo),
  GetExerciseDay(repo),
  AddExerciseEntry(repo),
  DeleteExerciseEntry(repo),
);
