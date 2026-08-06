import '../domain/finance_category.dart';
import '../domain/finance_repository.dart';

/// Use case: the caller's own finance categories, on their own.
///
/// Separate from [GetFinanceMonth], which fetches them as part of a
/// four-request month bundle keyed by a month — the split expense form needs
/// the list and has no month to ask about, and pulling a summary, a
/// transaction range and a budget list along with it would be three requests
/// nobody reads.
class ListFinanceCategories {
  final FinanceRepository _repository;

  ListFinanceCategories(this._repository);

  Future<List<FinanceCategory>> call(String idToken) =>
      _repository.getCategories(idToken);
}
