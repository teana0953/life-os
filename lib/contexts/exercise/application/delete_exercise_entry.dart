import '../domain/exercise_repository.dart';

class DeleteExerciseEntry {
  final ExerciseRepository _repository;

  DeleteExerciseEntry(this._repository);

  Future<bool> call(String idToken, String entryId) {
    return _repository.deleteEntry(idToken, entryId);
  }
}
