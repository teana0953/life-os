import '../domain/exercise_day.dart';
import '../domain/exercise_repository.dart';

class GetExerciseDay {
  final ExerciseRepository _repository;

  GetExerciseDay(this._repository);

  Future<ExerciseDay> call(String idToken, String day) {
    return _repository.getDay(idToken, day);
  }
}
