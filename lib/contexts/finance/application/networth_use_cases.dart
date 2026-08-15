import '../domain/finance_repository.dart';
import '../domain/networth_account.dart';
import '../domain/networth_snapshot.dart';

/// Use case: list every net worth account (archived included); the first
/// call seeds the backend defaults.
class ListNetWorthAccounts {
  final FinanceRepository _repository;

  ListNetWorthAccounts(this._repository);

  Future<List<NetWorthAccount>> call(String idToken) =>
      _repository.listNetWorthAccounts(idToken);
}

/// Use case: create a net worth account ([kind] fixed at creation).
class CreateNetWorthAccount {
  final FinanceRepository _repository;

  CreateNetWorthAccount(this._repository);

  Future<NetWorthAccount> call(
    String idToken, {
    required NetWorthKind kind,
    required String name,
    int? sortOrder,
  }) => _repository.createNetWorthAccount(
    idToken,
    kind: kind,
    name: name,
    sortOrder: sortOrder,
  );
}

/// Use case: rename, reorder, or archive/restore an account.
class UpdateNetWorthAccount {
  final FinanceRepository _repository;

  UpdateNetWorthAccount(this._repository);

  Future<NetWorthAccount> call(
    String idToken,
    String id, {
    String? name,
    int? sortOrder,
    bool? archived,
  }) => _repository.updateNetWorthAccount(
    idToken,
    id,
    name: name,
    sortOrder: sortOrder,
    archived: archived,
  );
}

class ReorderNetWorthAccounts {
  final FinanceRepository _repository;

  const ReorderNetWorthAccounts(this._repository);

  Future<void> call(String idToken, NetWorthKind kind, List<String> orderedIds) =>
      _repository.reorderNetWorthAccounts(idToken, kind, orderedIds);
}

class UpsertSnapshot {
  final FinanceRepository _repository;

  UpsertSnapshot(this._repository);

  Future<NetWorthSnapshot> call(
    String idToken, {
    required String accountId,
    required String month,
    required int value,
  }) => _repository.upsertNetWorthSnapshot(
    idToken,
    accountId: accountId,
    month: month,
    value: value,
  );
}

/// Use case: a month's account values, totals, net worth, and growth rate.
class GetMonthlyNetWorth {
  final FinanceRepository _repository;

  GetMonthlyNetWorth(this._repository);

  Future<MonthlyNetWorth> call(String idToken, String month) =>
      _repository.getMonthlyNetWorth(idToken, month);
}

/// Use case: the per-month net worth series over an inclusive month range.
class GetNetWorthTrend {
  final FinanceRepository _repository;

  GetNetWorthTrend(this._repository);

  Future<List<NetWorthTrendPoint>> call(
    String idToken, {
    required String from,
    required String to,
  }) => _repository.getNetWorthTrend(idToken, from: from, to: to);
}
