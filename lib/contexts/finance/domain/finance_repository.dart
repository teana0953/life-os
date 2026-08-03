import 'finance_budget.dart';
import 'finance_category.dart';
import 'finance_transaction.dart';
import 'finance_type.dart';
import 'monthly_summary.dart';
import 'networth_account.dart';
import 'networth_snapshot.dart';
import 'split_spending.dart';

/// Port covering transactions, categories, and the monthly summary — a
/// single port for the whole finance ledger slice (design.md: YAGNI, no
/// per-aggregate split until a context needs it).
abstract class FinanceRepository {
  Future<List<FinanceCategory>> getCategories(String idToken);

  /// [from]/[to] are `YYYY-MM-DD` strings (inclusive range).
  Future<List<FinanceTransaction>> getTransactions(
    String idToken, {
    required String from,
    required String to,
  });

  Future<MonthlySummary> getSummary(String idToken, String month);

  Future<FinanceTransaction> addTransaction(
    String idToken, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  });

  /// Full-replace update (the backend requires every field, including
  /// [currency]).
  Future<FinanceTransaction> updateTransaction(
    String idToken,
    String id, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  });

  Future<void> deleteTransaction(String idToken, String id);

  /// [month] is `YYYY-MM`. Returns every budget with that month's progress.
  Future<List<FinanceBudget>> listBudgets(String idToken, String month);

  /// Upserts the overall budget ([categoryId] `null`) or a category budget.
  Future<void> upsertBudget(String idToken, {String? categoryId, required int amount});

  Future<void> deleteBudget(String idToken, String id);

  /// Every net worth account, archived included. The first call for a user
  /// with none seeds the backend defaults.
  Future<List<NetWorthAccount>> listNetWorthAccounts(String idToken);

  /// [kind] is fixed at creation (the backend rejects later changes).
  Future<NetWorthAccount> createNetWorthAccount(
    String idToken, {
    required NetWorthKind kind,
    required String name,
    int? sortOrder,
  });

  /// Partial update — only the non-null fields are sent.
  Future<NetWorthAccount> updateNetWorthAccount(
    String idToken,
    String id, {
    String? name,
    int? sortOrder,
    bool? archived,
  });

  /// Upserts one (account, [month] `YYYY-MM`) snapshot; [value] is a
  /// non-negative TWD integer.
  Future<NetWorthSnapshot> upsertNetWorthSnapshot(
    String idToken, {
    required String accountId,
    required String month,
    required int value,
  });

  /// [month] is `YYYY-MM`.
  Future<MonthlyNetWorth> getMonthlyNetWorth(String idToken, String month);

  /// [from]/[to] are `YYYY-MM` strings (inclusive range), ascending result.
  Future<List<NetWorthTrendPoint>> getNetWorthTrend(
    String idToken, {
    required String from,
    required String to,
  });

  /// [month] is `YYYY-MM`. The caller's own split-expense spending that
  /// month, per currency (design D6) — a month with no split shares returns
  /// an empty list, not a zero row per currency.
  Future<List<SplitSpending>> getSplitSpending(String idToken, String month);
}
