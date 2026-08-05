import '../domain/split_activity.dart';
import '../domain/split_repository.dart';

/// Use case: one page of the split change log, newest first.
class ListActivity {
  final SplitRepository _repository;

  ListActivity(this._repository);

  Future<SplitActivityPage> call(
    String idToken, {
    required int limit,
    String? cursor,
  }) => _repository.listActivity(idToken, limit: limit, cursor: cursor);
}
