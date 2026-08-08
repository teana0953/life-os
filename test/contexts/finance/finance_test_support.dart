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
import 'package:life_os/contexts/finance/domain/installment_plan.dart';
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
    // against a fake that cannot represent one. `planId`/`installmentNo` are
    // carried for the identical reason: the server owns the plan link, and a
    // fake that drops it on save turns every instalment-marker-survives-edit
    // guard into a test of nothing.
    String? splitExpenseId;
    String? planId;
    int? installmentNo;
    for (final list in byMonth.values) {
      for (final t in list) {
        if (t.id == id) {
          splitExpenseId = t.splitExpenseId;
          planId = t.planId;
          installmentNo = t.installmentNo;
        }
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
      planId: planId,
      installmentNo: installmentNo,
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

  /// Held by `reorderNetWorthAccounts` before it does anything, so a test can
  /// look at the screen while the write is still in flight — which is the
  /// only way to tell "the row moved immediately" from "the row moved once
  /// the server answered".
  Future<void>? reorderGate;

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
    if (reorderGate != null) await reorderGate;
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

  // ------------------------------------------------------------ installments

  /// Plans the viewer owns. `getInstallmentPlan` for an id not in here
  /// throws [FinanceNotFound] — the backend's answer for somebody else's
  /// plan, and the only ownership signal a client gets. Widget fixtures for
  /// "a period of somebody else's plan" therefore simply do not seed it.
  final Map<String, InstallmentPlan> plansById = {};

  /// Every `createInstallmentPlan` call, verbatim. What `mode`/`amount`
  /// were actually sent is the point (tasks 3.3): in per-instalment mode
  /// `amount` must be the per-period figure, not the total.
  final List<
    ({
      InstallmentMode mode,
      int amount,
      int periods,
      String currency,
      String categoryId,
      String startDay,
      String? note,
    })
  >
  installmentPlanCreates = [];

  /// Every `updateInstallmentPlan` call, verbatim.
  final List<({String planId, int amount, int periods})>
  installmentPlanUpdates = [];

  /// Every `settleInstallmentPlan` call, verbatim. `amount` null = the
  /// caller sent none (the total-mode contract); non-null = the bank's
  /// payoff figure (the per-instalment contract) — tasks 5.3/5.4.
  final List<({String planId, int? amount})> installmentSettleCalls = [];

  int _nextPlanId = 1;

  @override
  Future<InstallmentPlan> createInstallmentPlan(
    String idToken, {
    required InstallmentMode mode,
    required int amount,
    required int periods,
    required String currency,
    required String categoryId,
    required String startDay,
    String? note,
  }) async {
    installmentPlanCreates.add((
      mode: mode,
      amount: amount,
      periods: periods,
      currency: currency,
      categoryId: categoryId,
      startDay: startDay,
      note: note,
    ));
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final plan = InstallmentPlan(
      id: 'plan${_nextPlanId++}',
      mode: mode,
      periods: periods,
      startDay: startDay,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      note: note,
    );
    plansById[plan.id] = plan;
    return plan;
  }

  @override
  Future<InstallmentPlan> getInstallmentPlan(String idToken, String id) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final plan = plansById[id];
    if (plan == null) throw const FinanceNotFound();
    return plan;
  }

  @override
  Future<InstallmentPlan> updateInstallmentPlan(
    String idToken,
    String id, {
    required int amount,
    required int periods,
  }) async {
    installmentPlanUpdates.add((planId: id, amount: amount, periods: periods));
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final current = plansById[id];
    if (current == null) throw const FinanceNotFound();
    final updated = InstallmentPlan(
      id: current.id,
      mode: current.mode,
      periods: periods,
      startDay: current.startDay,
      amount: amount,
      currency: current.currency,
      categoryId: current.categoryId,
      note: current.note,
    );
    plansById[id] = updated;
    return updated;
  }

  @override
  Future<void> settleInstallmentPlan(
    String idToken,
    String id, {
    int? amount,
  }) async {
    installmentSettleCalls.add((planId: id, amount: amount));
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    if (!plansById.containsKey(id)) throw const FinanceNotFound();
  }

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

/// Two thin subclasses rather than wrappers: `FinanceRepository` has a wide
/// surface and forwarding it by hand (or via `noSuchMethod`, which the fake
/// does not implement) is a lot of ceremony to override one method.

/// Makes every `getInstallmentPlan` throw [failure] — the only way to reach
/// `GetFinanceMonth`'s plan-fetch failure path, since the fake's own
/// `failNext` fires once and is consumed by whichever call gets there first.
class FinanceRepositoryFailingPlans extends FakeFinanceRepository {
  final Object failure;

  FinanceRepositoryFailingPlans(this.failure);

  @override
  Future<InstallmentPlan> getInstallmentPlan(String idToken, String id) async {
    throw failure;
  }
}

/// Counts `getInstallmentPlan` calls and the maximum number in flight at once,
/// which is what tells a concurrent fetch from a serial loop — a serial loop
/// never exceeds one.
class FinanceRepositoryCountingPlans extends FakeFinanceRepository {
  int calls = 0;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<InstallmentPlan> getInstallmentPlan(String idToken, String id) async {
    calls++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    // A real await, so a serial loop drains this one before starting the next.
    await Future<void>.delayed(Duration.zero);
    inFlight--;
    throw const FinanceNotFound();
  }
}
