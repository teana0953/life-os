import '../domain/exercise_day.dart';
import '../domain/exercise_repository.dart';

/// Use case: append an exercise entry to a day.
class AddExerciseEntry {
  final ExerciseRepository _repository;

  AddExerciseEntry(this._repository);

  Future<ExerciseEntry> call(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  }) {
    return _repository.addEntry(
      idToken,
      day: day,
      activityId: activityId,
      durationMinutes: durationMinutes,
      note: note,
    );
  }
}
