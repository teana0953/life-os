import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/exercise/application/add_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/delete_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/get_exercise_day.dart';
import 'package:life_os/contexts/exercise/application/list_exercise_activities.dart';
import 'package:life_os/contexts/exercise/domain/exercise_day.dart';
import 'package:life_os/contexts/exercise/domain/exercise_repository.dart';

class _RecordingExerciseRepository implements ExerciseRepository {
  String? listActivitiesToken;
  String? getDayToken;
  String? getDayDay;
  Map<String, Object?>? addArgs;
  String? deleteToken;
  String? deleteEntryId;

  @override
  Future<List<ExerciseActivity>> listActivities(String idToken) async {
    listActivitiesToken = idToken;
    return const [
      ExerciseActivity(
        id: 'jogging',
        name: '慢跑',
        category: 'aerobic',
        intensity: '8km/hr',
      ),
    ];
  }

  @override
  Future<ExerciseDay> getDay(String idToken, String day) async {
    getDayToken = idToken;
    getDayDay = day;
    return ExerciseDay(day: day, entries: const [], totalMinutes: 0);
  }

  @override
  Future<ExerciseEntry> addEntry(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  }) async {
    addArgs = {
      'idToken': idToken,
      'day': day,
      'activityId': activityId,
      'durationMinutes': durationMinutes,
      'note': note,
    };
    return ExerciseEntry(
      id: 'e1',
      activityId: activityId,
      activityName: '慢跑',
      category: 'aerobic',
      durationMinutes: durationMinutes,
      note: note,
      createdAt: DateTime.utc(2026, 7, 18, 9),
    );
  }

  @override
  Future<bool> deleteEntry(String idToken, String entryId) async {
    deleteToken = idToken;
    deleteEntryId = entryId;
    return true;
  }
}

void main() {
  test('ListExerciseActivities delegates to the port', () async {
    final repo = _RecordingExerciseRepository();
    final result = await ListExerciseActivities(repo)('tok');

    expect(repo.listActivitiesToken, 'tok');
    expect(result.single.id, 'jogging');
  });

  test('GetExerciseDay delegates to the port', () async {
    final repo = _RecordingExerciseRepository();
    final result = await GetExerciseDay(repo)('tok', '2026-07-18');

    expect(repo.getDayToken, 'tok');
    expect(repo.getDayDay, '2026-07-18');
    expect(result.day, '2026-07-18');
  });

  test('AddExerciseEntry delegates to the port', () async {
    final repo = _RecordingExerciseRepository();
    final entry = await AddExerciseEntry(repo)(
      'tok',
      day: '2026-07-18',
      activityId: 'jogging',
      durationMinutes: 30,
      note: 'run',
    );

    expect(repo.addArgs, {
      'idToken': 'tok',
      'day': '2026-07-18',
      'activityId': 'jogging',
      'durationMinutes': 30,
      'note': 'run',
    });
    expect(entry.durationMinutes, 30);
  });

  test('DeleteExerciseEntry delegates to the port', () async {
    final repo = _RecordingExerciseRepository();
    final deleted = await DeleteExerciseEntry(repo)('tok', 'e1');

    expect(repo.deleteToken, 'tok');
    expect(repo.deleteEntryId, 'e1');
    expect(deleted, isTrue);
  });
}
