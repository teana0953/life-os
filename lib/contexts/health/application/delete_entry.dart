import '../domain/diet_log_repository.dart';

/// Use case: delete one of the caller's own diet entries.
class DeleteEntry {
  final DietLogRepository _repository;

  DeleteEntry(this._repository);

  Future<void> call(String idToken, String entryId) {
    return _repository.deleteEntry(idToken, entryId);
  }
}
