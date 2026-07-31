import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/delete_budget.dart';
import 'package:life_os/contexts/finance/application/delete_transaction.dart';
import 'package:life_os/contexts/finance/application/get_finance_month.dart';
import 'package:life_os/contexts/finance/application/update_transaction.dart';
import 'package:life_os/contexts/finance/application/upsert_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_category.dart';
import 'package:life_os/contexts/finance/domain/finance_repository.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/monthly_summary.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';

/// An overall (`categoryId` `null`) or category budget definition — recurring
/// across months, mirroring the real backend (design.md: budgets apply to
/// every month, only [FinanceBudget.spent]/`remaining`/`percent` vary).
class _BudgetDef {
  final String id;
  final String? categoryId;
  final int amount;

  const _BudgetDef({required this.id, required this.categoryId, required this.amount});
}

/// A shared in-memory [FinanceRepository] fake for finance presentation/
/// widget tests: seeded categories, per-month transactions, and a summary
/// derived from them. [failNext] makes the next call throw once.
class FakeFinanceRepository implements FinanceRepository {
  final Map<String, List<FinanceTransaction>> byMonth = {};
  int nextId = 1;
  Object? failNext;

  final List<_BudgetDef> _budgetDefs = [];
  int _nextBudgetId = 1;
  final List<String> budgetCalls = [];

  List<FinanceCategory> categoriesToReturn = const [
    FinanceCategory(
      id: 'cat-food',
      name: '餐飲',
      type: FinanceType.expense,
      icon: 'other',
      sortOrder: 0,
      archived: false,
    ),
    FinanceCategory(
      id: 'cat-transport',
      name: '交通',
      type: FinanceType.expense,
      icon: 'other',
      sortOrder: 1,
      archived: false,
    ),
    FinanceCategory(
      id: 'cat-salary',
      name: '薪資',
      type: FinanceType.income,
      icon: 'other',
      sortOrder: 0,
      archived: false,
    ),
  ];

  @override
  Future<List<FinanceCategory>> getCategories(String idToken) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    return categoriesToReturn;
  }

  @override
  Future<List<FinanceTransaction>> getTransactions(
    String idToken, {
    required String from,
    required String to,
  }) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final month = from.substring(0, 7);
    return List.of(byMonth[month] ?? const []);
  }

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final txns = byMonth[month] ?? const [];
    final byCurrency = <String, List<FinanceTransaction>>{};
    for (final txn in txns) {
      (byCurrency[txn.currency] ??= []).add(txn);
    }
    final totals = [
      for (final entry in byCurrency.entries)
        CurrencyTotal(
          currency: entry.key,
          expense: entry.value
              .where((t) => t.type == FinanceType.expense)
              .fold(0, (sum, t) => sum + t.amount),
          income: entry.value
              .where((t) => t.type == FinanceType.income)
              .fold(0, (sum, t) => sum + t.amount),
          net:
              entry.value
                  .where((t) => t.type == FinanceType.income)
                  .fold(0, (sum, t) => sum + t.amount) -
              entry.value
                  .where((t) => t.type == FinanceType.expense)
                  .fold(0, (sum, t) => sum + t.amount),
        ),
    ];
    final byCategory = <String, int>{};
    for (final txn in txns.where((t) => t.type == FinanceType.expense)) {
      byCategory['${txn.categoryId}|${txn.currency}'] =
          (byCategory['${txn.categoryId}|${txn.currency}'] ?? 0) + txn.amount;
    }
    return MonthlySummary(
      month: month,
      totals: totals,
      byCategory: [
        for (final entry in byCategory.entries)
          CategoryAmount(
            categoryId: entry.key.split('|')[0],
            type: FinanceType.expense,
            currency: entry.key.split('|')[1],
            amount: entry.value,
          ),
      ],
    );
  }

  @override
  Future<FinanceTransaction> addTransaction(
    String idToken, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final txn = FinanceTransaction(
      id: 't${nextId++}',
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    (byMonth[date.substring(0, 7)] ??= []).add(txn);
    return txn;
  }

  @override
  Future<FinanceTransaction> updateTransaction(
    String idToken,
    String id, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    for (final list in byMonth.values) {
      list.removeWhere((t) => t.id == id);
    }
    final txn = FinanceTransaction(
      id: id,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    (byMonth[date.substring(0, 7)] ??= []).add(txn);
    return txn;
  }

  @override
  Future<void> deleteTransaction(String idToken, String id) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    for (final list in byMonth.values) {
      list.removeWhere((t) => t.id == id);
    }
  }

  int _spentFor(String month, String? categoryId) {
    final txns = byMonth[month] ?? const [];
    return txns
        .where(
          (t) =>
              t.type == FinanceType.expense &&
              t.currency == 'TWD' &&
              (categoryId == null || t.categoryId == categoryId),
        )
        .fold(0, (sum, t) => sum + t.amount);
  }

  @override
  Future<List<FinanceBudget>> listBudgets(String idToken, String month) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    return [
      for (final def in _budgetDefs)
        FinanceBudget(
          id: def.id,
          categoryId: def.categoryId,
          amount: def.amount,
          spent: _spentFor(month, def.categoryId),
          remaining: def.amount - _spentFor(month, def.categoryId),
          percent: def.amount == 0
              ? 0
              : ((_spentFor(month, def.categoryId) * 100) / def.amount).round(),
        ),
    ];
  }

  @override
  Future<void> upsertBudget(
    String idToken, {
    String? categoryId,
    required int amount,
  }) async {
    budgetCalls.add('upsert:$categoryId:$amount');
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final index = _budgetDefs.indexWhere((d) => d.categoryId == categoryId);
    final def = _BudgetDef(
      id: index >= 0 ? _budgetDefs[index].id : 'budget${_nextBudgetId++}',
      categoryId: categoryId,
      amount: amount,
    );
    if (index >= 0) {
      _budgetDefs[index] = def;
    } else {
      _budgetDefs.add(def);
    }
  }

  @override
  Future<void> deleteBudget(String idToken, String id) async {
    budgetCalls.add('delete:$id');
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    _budgetDefs.removeWhere((d) => d.id == id);
  }
}

FinanceController testFinanceController(FakeFinanceRepository repo) =>
    FinanceController(
      GetFinanceMonth(repo),
      AddTransaction(repo),
      UpdateTransaction(repo),
      DeleteTransaction(repo),
      UpsertBudget(repo),
      DeleteBudget(repo),
    );
