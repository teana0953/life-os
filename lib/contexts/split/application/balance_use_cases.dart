import '../domain/balance.dart';
import '../domain/split_repository.dart';

/// Use case: the caller's signed two-person net against everyone they
/// share an expense with.
class GetBalances {
  final SplitRepository _repository;

  GetBalances(this._repository);

  Future<List<Balance>> call(String idToken) => _repository.getBalances(idToken);
}
