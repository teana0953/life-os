import 'finance_category.dart';
import 'finance_transaction.dart';
import 'finance_type.dart';
import 'monthly_summary.dart';

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
}
