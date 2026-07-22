import '../domain/exercise_day.dart';
import '../domain/exercise_repository.dart';

/// Use case: fetch the static exercise activity library.
class ListExerciseActivities {
  final ExerciseRepository _repository;

  ListExerciseActivities(this._repository);

  Future<List<ExerciseActivity>> call(String idToken) {
    return _repository.listActivities(idToken);
  }
}
