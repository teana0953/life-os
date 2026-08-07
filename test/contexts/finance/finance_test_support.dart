import 'dart:async';

import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/delete_budget.dart';
import 'package:life_os/contexts/finance/application/delete_transaction.dart';
import 'package:life_os/contexts/finance/application/get_finance_month.dart';
import 'package:life_os/contexts/finance/application/get_split_spending.dart';
import 'package:life_os/contexts/finance/application/networth_use_cases.dart';
import 'package:life_os/contexts/finance/application/update_transaction.dart';
import 'package:life_os/contexts/finance/application/upsert_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_category.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_repository.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/monthly_summary.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/finance/domain/split_spending.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';

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

  /// Throws [FinanceValidationFailure] the [failOnBudgetCallNumber]th time
  /// `upsertBudget`/`deleteBudget` is called — the batch partial-failure case.
  int? failOnBudgetCallNumber;
  int _budgetCallCount = 0;

  /// Seeds an existing budget directly, without recording a [budgetCalls]
  /// entry or advancing [failOnBudgetCallNumber]'s counter — for setting up a
  /// widget test's starting state.
  void seedBudget({String? categoryId, required int amount}) {
    _budgetDefs.add(
      _BudgetDef(id: 'budget${_nextBudgetId++}', categoryId: categoryId, amount: amount),
    );
  }

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

  /// Every id token [getSummary] was called with, in order — the *value that
  /// was sent*, which is what the token-freshness tests assert on.
  final List<String> summaryTokens = [];

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async {
    summaryTokens.add(idToken);
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
    // `splitExpenseId` is carried over from the stored row, not taken from
    // the caller: it is not one of the update endpoint's parameters (the
    // server owns the link), so rebuilding the row without it would have this
    // fake silently turn a mirror into a self-recorded transaction on every
    // save — and any guard about a mirror surviving an edit would pass
    // against a fake that cannot represent one.
    String? splitExpenseId;
    for (final list in byMonth.values) {
      for (final t in list) {
        if (t.id == id) splitExpenseId = t.splitExpenseId;
      }
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
      splitExpenseId: splitExpenseId,
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
    _budgetCallCount++;
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    if (failOnBudgetCallNumber == _budgetCallCount) {
      failOnBudgetCallNumber = null;
      throw const FinanceValidationFailure();
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
    _budgetCallCount++;
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    if (failOnBudgetCallNumber == _budgetCallCount) {
      failOnBudgetCallNumber = null;
      throw const FinanceValidationFailure();
    }
    _budgetDefs.removeWhere((d) => d.id == id);
  }

  // ---------------------------------------------------------------- networth

  /// The net worth accounts this fake returns, mutated by create/update.
  List<NetWorthAccount> accounts = [
    const NetWorthAccount(
      id: 'acc-cash',
      kind: NetWorthKind.asset,
      name: '台幣活存',
      sortOrder: 0,
      archived: false,
    ),
    const NetWorthAccount(
      id: 'acc-card',
      kind: NetWorthKind.liability,
      name: '信用卡',
      sortOrder: 0,
      archived: false,
    ),
  ];

  /// `accountId -> month -> value`.
  final Map<String, Map<String, int>> snapshots = {};

  /// Every networth write, in order (`upsert:<accountId>:<month>:<value>`,
  /// `create:<kind>:<name>`, `update:<id>:<field>=<value>`).
  final List<String> networthCalls = [];

  /// Every trend range requested, as `<from>..<to>`.
  final List<String> trendCalls = [];

  /// Holds `getMonthlyNetWorth` for a month until its completer completes —
  /// the hook the controller's stale-response race test uses.
  final Map<String, Completer<void>> monthlyGates = {};

  int _nextAccountId = 1;

  void seedSnapshot(String accountId, String month, int value) {
    (snapshots[accountId] ??= {})[month] = value;
  }

  int _netWorthFor(String month) {
    var total = 0;
    for (final account in accounts) {
      final value = snapshots[account.id]?[month];
      if (value == null) continue;
      total += account.kind == NetWorthKind.asset ? value : -value;
    }
    return total;
  }

  bool _hasAnySnapshot(String month) =>
      snapshots.values.any((byMonth) => byMonth.containsKey(month));

  @override
  Future<List<NetWorthAccount>> listNetWorthAccounts(String idToken) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    return List.of(accounts);
  }

  @override
  Future<NetWorthAccount> createNetWorthAccount(
    String idToken, {
    required NetWorthKind kind,
    required String name,
    int? sortOrder,
  }) async {
    networthCalls.add('create:${netWorthKindToJson(kind)}:$name');
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final account = NetWorthAccount(
      id: 'acc-new${_nextAccountId++}',
      kind: kind,
      name: name,
      sortOrder: sortOrder ?? accounts.length,
      archived: false,
    );
    accounts = [...accounts, account];
    return account;
  }

  @override
  Future<NetWorthAccount> updateNetWorthAccount(
    String idToken,
    String id, {
    String? name,
    int? sortOrder,
    bool? archived,
  }) async {
    networthCalls.add(
      'update:$id:'
      '${name != null ? 'name=$name' : ''}'
      '${sortOrder != null ? 'sort=$sortOrder' : ''}'
      '${archived != null ? 'archived=$archived' : ''}',
    );
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final index = accounts.indexWhere((a) => a.id == id);
    if (index < 0) throw const FinanceNotFound();
    final current = accounts[index];
    final updated = NetWorthAccount(
      id: current.id,
      kind: current.kind,
      name: name ?? current.name,
      sortOrder: sortOrder ?? current.sortOrder,
      archived: archived ?? current.archived,
    );
    accounts = [...accounts]..[index] = updated;
    return updated;
  }

  @override
  Future<void> reorderNetWorthAccounts(
    String idToken,
    NetWorthKind kind,
    List<String> orderedIds,
  ) async {
    networthCalls.add('reorder:${netWorthKindToJson(kind)}:${orderedIds.join(",")}');
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    // Mirrors the server: the whole group lands or none of it does, so a
    // caller cannot observe a half-renumbered group through this fake either.
    final byId = {for (final a in accounts) a.id: a};
    final next = [...accounts];
    for (var i = 0; i < orderedIds.length; i++) {
      final current = byId[orderedIds[i]];
      if (current == null) throw const FinanceValidationFailure();
      next[next.indexWhere((a) => a.id == current.id)] = NetWorthAccount(
        id: current.id,
        kind: current.kind,
        name: current.name,
        sortOrder: i,
        archived: current.archived,
      );
    }
    accounts = next;
  }

  @override
  Future<NetWorthSnapshot> upsertNetWorthSnapshot(
    String idToken, {
    required String accountId,
    required String month,
    required int value,
  }) async {
    networthCalls.add('upsert:$accountId:$month:$value');
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    seedSnapshot(accountId, month, value);
    return NetWorthSnapshot(
      id: 'snap-$accountId-$month',
      accountId: accountId,
      month: month,
      value: value,
    );
  }

  @override
  Future<MonthlyNetWorth> getMonthlyNetWorth(String idToken, String month) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final gate = monthlyGates[month];
    if (gate != null) await gate.future;

    final values = [
      for (final account in accounts)
        if (snapshots[account.id]?[month] != null)
          NetWorthAccountValue(
            accountId: account.id,
            kind: account.kind,
            name: account.name,
            value: snapshots[account.id]![month]!,
          ),
    ];
    final totalAsset = values
        .where((v) => v.kind == NetWorthKind.asset)
        .fold(0, (sum, v) => sum + v.value);
    final totalLiability = values
        .where((v) => v.kind == NetWorthKind.liability)
        .fold(0, (sum, v) => sum + v.value);
    // "Prior month" = the most recent earlier month holding any snapshot.
    final earlier =
        snapshots.values.expand((byMonth) => byMonth.keys).where((m) => m.compareTo(month) < 0).toList()
          ..sort();
    final prev = earlier.isEmpty ? null : _netWorthFor(earlier.last);
    final net = totalAsset - totalLiability;
    return MonthlyNetWorth(
      month: month,
      accounts: values,
      totalAsset: totalAsset,
      totalLiability: totalLiability,
      netWorth: net,
      prevNetWorth: prev,
      growthRate: prev == null || prev <= 0 ? null : (net - prev) / prev,
    );
  }

  @override
  Future<List<NetWorthTrendPoint>> getNetWorthTrend(
    String idToken, {
    required String from,
    required String to,
  }) async {
    trendCalls.add('$from..$to');
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final months = snapshots.values.expand((byMonth) => byMonth.keys).toSet().toList()..sort();
    return [
      for (final month in months)
        if (month.compareTo(from) >= 0 && month.compareTo(to) <= 0 && _hasAnySnapshot(month))
          NetWorthTrendPoint(month: month, netWorth: _netWorthFor(month)),
    ];
  }

  // -------------------------------------------------------------- split spending

  /// `month -> totals`, for the overview's split-spending line. Empty for
  /// any month not seeded here.
  final Map<String, List<SplitSpending>> splitSpendingByMonth = {};

  /// When set for a month, `getSplitSpending` for that month awaits the
  /// completer instead of resolving immediately — the split-spending race
  /// test's slow leg (design D9, task 6.1b).
  final Map<String, Completer<void>> splitSpendingGates = {};

  /// Makes the next `getSplitSpending` call throw once. Deliberately
  /// **separate** from [failNext] above: `FinanceController.load` now runs
  /// `getSplitSpending` concurrently with the main `getFinanceMonth` fetch
  /// (design D9), so sharing one flag between them would make whichever call
  /// happens to run first consume it — silently breaking every existing
  /// test in this repo that sets [failNext] expecting it to fail the *main*
  /// fetch.
  Object? splitSpendingFailNext;

  @override
  Future<List<SplitSpending>> getSplitSpending(String idToken, String month) async {
    final gate = splitSpendingGates[month];
    if (gate != null) await gate.future;
    if (splitSpendingFailNext != null) {
      final failure = splitSpendingFailNext!;
      splitSpendingFailNext = null;
      throw failure;
    }
    return splitSpendingByMonth[month] ?? const [];
  }
}

NetWorthController testNetWorthController(FakeFinanceRepository repo) =>
    NetWorthController(
      ListNetWorthAccounts(repo),
      CreateNetWorthAccount(repo),
      UpdateNetWorthAccount(repo),
      ReorderNetWorthAccounts(repo),
      UpsertSnapshot(repo),
      GetMonthlyNetWorth(repo),
      GetNetWorthTrend(repo),
    );

FinanceController testFinanceController(FakeFinanceRepository repo) =>
    FinanceController(
      GetFinanceMonth(repo),
      AddTransaction(repo),
      UpdateTransaction(repo),
      DeleteTransaction(repo),
      UpsertBudget(repo),
      DeleteBudget(repo),
      GetSplitSpending(repo),
    );
