import '../domain/finance_repository.dart';
import '../domain/split_spending.dart';

/// Use case: the caller's own split-expense spending for a month, per
/// currency (design D6).
class GetSplitSpending {
  final FinanceRepository _repository;

  GetSplitSpending(this._repository);

  Future<List<SplitSpending>> call(String idToken, String month) =>
      _repository.getSplitSpending(idToken, month);
}
