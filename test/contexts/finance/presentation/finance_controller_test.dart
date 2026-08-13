import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/delete_budget.dart';
import 'package:life_os/contexts/finance/application/delete_transaction.dart';
import 'package:life_os/contexts/finance/application/get_finance_month.dart';
import 'package:life_os/contexts/finance/application/get_split_spending.dart';
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

/// A controllable in-memory fake: `getSummary` (used as the load's "slow"
/// leg in the race test) can be gated behind a per-month [Completer] so a
/// test can control exactly when a given month's response lands.
class FakeFinanceRepository implements FinanceRepository {
  final Map<String, List<FinanceTransaction>> _byMonth = {};
  int _nextId = 1;
  Object? failNext;

  /// When set for a month, `getSummary` for that month awaits the completer
  /// instead of resolving immediately.
  final Map<String, Completer<void>> gates = {};

  /// When set for a month, `listBudgets` for that month awaits the completer
  /// instead of resolving immediately (the budgets race test's slow leg).
  final Map<String, Completer<void>> budgetGates = {};

  /// When set for a month, `getSplitSpending` for that month awaits the
  /// completer instead of resolving immediately — the split-spending race
  /// test's slow leg (design D9/finance-ledger-ui "Month switching is
  /// race-safe" applied to the split-spending line, task 6.1b).
  final Map<String, Completer<void>> splitSpendingGates = {};

  /// `month -> totals` this fake returns from `getSplitSpending`. Empty
  /// (the default) for any month not seeded here.
  final Map<String, List<SplitSpending>> splitSpendingByMonth = {};

  /// Makes the next `getSplitSpending` call throw once. Deliberately
  /// **separate** from [failNext] above: `getSplitSpending` now runs
  /// concurrently with the main `getFinanceMonth` fetch (design D9), so
  /// sharing one flag between them would make whichever call happens to run
  /// first consume it — silently breaking every existing test that sets
  /// [failNext] expecting it to fail the *main* fetch.
  Object? splitSpendingFailNext;

  final List<_BudgetDef> _budgetDefs = [];
  int _nextBudgetId = 1;
  final List<String> budgetCalls = [];

  /// Throws [failNext] the [n]th time `upsertBudget`/`deleteBudget` is
  /// called (1-indexed), instead of on the very next call — lets a test make
  /// a later step of a batch fail while an earlier one succeeds.
  int? failOnBudgetCallNumber;
  int _budgetCallCount = 0;

  @override
  Future<List<FinanceCategory>> getCategories(String idToken) async {
    return const [
      FinanceCategory(
        id: 'cat-food',
        name: '餐飲',
        type: FinanceType.expense,
        icon: 'other',
        sortOrder: 0,
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
  }

  @override
  Future<List<FinanceTransaction>> getTransactions(
    String idToken, {
    required String from,
    required String to,
  }) async {
    final month = from.substring(0, 7);
    return List.of(_byMonth[month] ?? const []);
  }

  /// How many times [getSummary] has been called — lets a test assert that
  /// a guarded path never issued a `load` at all, not just that its result
  /// didn't land.
  int getSummaryCallCount = 0;

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async {
    getSummaryCallCount++;
    final gate = gates[month];
    if (gate != null) await gate.future;
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    final txns = _byMonth[month] ?? const [];
    final expense = txns
        .where((t) => t.type == FinanceType.expense)
        .fold(0, (sum, t) => sum + t.amount);
    final income = txns
        .where((t) => t.type == FinanceType.income)
        .fold(0, (sum, t) => sum + t.amount);
    return MonthlySummary(
      month: month,
      totals: [
        CurrencyTotal(
          currency: 'TWD',
          expense: expense,
          income: income,
          net: income - expense,
        ),
      ],
      byCategory: const [],
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
      id: 't${_nextId++}',
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    (_byMonth[date.substring(0, 7)] ??= []).add(txn);
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
    for (final list in _byMonth.values) {
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
    (_byMonth[date.substring(0, 7)] ??= []).add(txn);
    return txn;
  }

  @override
  Future<void> deleteTransaction(String idToken, String id) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    for (final list in _byMonth.values) {
      list.removeWhere((t) => t.id == id);
    }
  }

  int _spentFor(String month, String? categoryId) {
    final txns = _byMonth[month] ?? const [];
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
    final gate = budgetGates[month];
    if (gate != null) await gate.future;
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

  // The ledger controller under test never touches the networth port; these
  // satisfy the shared FinanceRepository interface only.
  @override
  Future<List<NetWorthAccount>> listNetWorthAccounts(String idToken) =>
      throw UnimplementedError();

  @override
  Future<NetWorthAccount> createNetWorthAccount(
    String idToken, {
    required NetWorthKind kind,
    required String name,
    int? sortOrder,
  }) => throw UnimplementedError();

  @override
  Future<NetWorthAccount> updateNetWorthAccount(
    String idToken,
    String id, {
    String? name,
    int? sortOrder,
    bool? archived,
  }) => throw UnimplementedError();

  @override
  Future<void> reorderNetWorthAccounts(
    String idToken,
    NetWorthKind kind,
    List<String> orderedIds,
  ) async => throw UnimplementedError();

  @override
  Future<NetWorthSnapshot> upsertNetWorthSnapshot(
    String idToken, {
    required String accountId,
    required String month,
    required int value,
  }) => throw UnimplementedError();

  @override
  Future<MonthlyNetWorth> getMonthlyNetWorth(String idToken, String month) =>
      throw UnimplementedError();

  @override
  Future<List<NetWorthTrendPoint>> getNetWorthTrend(
    String idToken, {
    required String from,
    required String to,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<InstallmentPlan> getInstallmentPlan(String idToken, String id) =>
      throw UnimplementedError();

  @override
  Future<InstallmentPlan> updateInstallmentPlan(
    String idToken,
    String id, {
    required int amount,
    required int periods,
  }) => throw UnimplementedError();

  @override
  Future<void> settleInstallmentPlan(String idToken, String id, {int? amount}) =>
      throw UnimplementedError();
}

/// An overall (`categoryId` `null`) or category budget definition — recurring
/// across months, mirroring the real backend.
class _BudgetDef {
  final String id;
  final String? categoryId;
  final int amount;

  const _BudgetDef({required this.id, required this.categoryId, required this.amount});
}

FinanceController _controller(FakeFinanceRepository repo) => FinanceController(
  GetFinanceMonth(repo),
  AddTransaction(repo),
  UpdateTransaction(repo),
  DeleteTransaction(repo),
  UpsertBudget(repo),
  DeleteBudget(repo),
  GetSplitSpending(repo),
);

void main() {
  group('load', () {
    test('populates categories/summary/transactions and sets loaded', () async {
      final controller = _controller(FakeFinanceRepository());

      await controller.load('tok', '2026-07');

      expect(controller.status, FinanceStatus.loaded);
      expect(controller.selectedMonth, '2026-07');
      expect(controller.categories, hasLength(2));
      expect(controller.summary!.month, '2026-07');
      expect(controller.transactions, isEmpty);
    });

    test('a 401 surfaces needsReauth', () async {
      final repo = FakeFinanceRepository()
        ..failNext = const FinanceReauthenticationRequired();
      final controller = _controller(repo);

      await controller.load('tok', '2026-07');

      expect(controller.status, FinanceStatus.needsReauth);
    });

    test('a fetch failure surfaces an error with the typed cause', () async {
      final repo = FakeFinanceRepository()
        ..failNext = const FinanceFetchFailure('boom');
      final controller = _controller(repo);

      await controller.load('tok', '2026-07');

      expect(controller.status, FinanceStatus.error);
      expect(controller.error, FinanceError.fetchFailed);
      expect(controller.reloadFailed, isTrue);
    });

    test('does not call notifyListeners before the first await', () async {
      final controller = _controller(FakeFinanceRepository());
      var notifiedSync = false;
      controller.addListener(() => notifiedSync = true);

      final future = controller.load('tok', '2026-07');
      // Nothing should have notified yet — only after the awaited fetch.
      expect(notifiedSync, isFalse);
      await future;
      expect(notifiedSync, isTrue);
    });

    test(
      'same-month race: a slow earlier same-month load never overwrites a '
      'fast later same-month load (e.g. two quick split writes each '
      'triggering a background reload)',
      () async {
        final repo = FakeFinanceRepository();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        expect(controller.summary!.totals.single.expense, 0);

        // Call A: gated, so it will sit mid-flight.
        final gateA = Completer<void>();
        repo.gates['2026-07'] = gateA;
        final callA = controller.load('tok', '2026-07');

        // Before A's response lands, the underlying data changes and a
        // second, faster same-month reload starts and completes — the
        // `selectedMonth != month` guard alone cannot tell these two calls
        // apart, since both target '2026-07'.
        repo.gates.remove('2026-07');
        repo._byMonth['2026-07'] = [
          const FinanceTransaction(
            id: 't-b',
            type: FinanceType.expense,
            amount: 999,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-05',
          ),
        ];
        final callB = controller.load('tok', '2026-07');
        await callB;
        expect(controller.summary!.totals.single.expense, 999);
        expect(controller.transactions.single.id, 't-b');

        // Now let A's stale response land late.
        gateA.complete();
        await callA;

        // B — the newer call — must still be showing; A must not have
        // clobbered it just because its response arrived later.
        expect(controller.summary!.totals.single.expense, 999);
        expect(controller.transactions, hasLength(1));
        expect(controller.transactions.single.id, 't-b');
      },
    );

    test(
      'same-month race, the split-spending leg: a slow earlier same-month '
      "call's split-spending response never overwrites a fast later "
      'same-month call\'s — identical hazard to the summary/transactions '
      'leg above, guarded separately in `_loadSplitSpending`',
      () async {
        final repo = FakeFinanceRepository()
          ..splitSpendingByMonth['2026-07'] = const [
            SplitSpending(currency: 'TWD', amount: 111, countedInTransactions: true),
          ];
        final controller = _controller(repo);

        // Call A: gated on the split-spending leg specifically, so it sits
        // mid-flight there while the rest of the load has already finished.
        final gateA = Completer<void>();
        repo.splitSpendingGates['2026-07'] = gateA;
        final callA = controller.load('tok', '2026-07');

        // Before A's split-spending response lands, a second, faster
        // same-month reload starts and completes with a different value.
        repo.splitSpendingGates.remove('2026-07');
        repo.splitSpendingByMonth['2026-07'] = const [
          SplitSpending(currency: 'TWD', amount: 222, countedInTransactions: true),
        ];
        final callB = controller.load('tok', '2026-07');
        await callB;
        expect(controller.splitSpending, [
          const SplitSpending(currency: 'TWD', amount: 222, countedInTransactions: true),
        ]);
        expect(controller.splitSpendingStatus, SplitSpendingStatus.loaded);

        // The fake reads its backing store at the moment a gated call is
        // released, not at the moment it was issued — so without restoring
        // the pre-B value here, A's response would happen to carry B's own
        // 222 and the guard's correctness would be untestable by value
        // alone. Restoring it models what a real backend would have handed
        // back to A's request in the first place: whatever was true before
        // B's write landed.
        repo.splitSpendingByMonth['2026-07'] = const [
          SplitSpending(currency: 'TWD', amount: 111, countedInTransactions: true),
        ];
        gateA.complete();
        await callA;

        // B — the newer call — must still be showing.
        expect(controller.splitSpending, [
          const SplitSpending(currency: 'TWD', amount: 222, countedInTransactions: true),
        ]);
        expect(controller.splitSpendingStatus, SplitSpendingStatus.loaded);
      },
    );

    test(
      'rapid month switching: a stale slow response never overwrites the '
      'currently selected month',
      () async {
        final repo = FakeFinanceRepository();
        repo.gates['2026-07'] = Completer<void>();
        final controller = _controller(repo);

        // Start loading July (slow — gated) then switch to August (fast).
        final julyFuture = controller.load('tok', '2026-07');
        final augustFuture = controller.load('tok', '2026-08');
        await augustFuture;
        expect(controller.selectedMonth, '2026-08');
        expect(controller.summary!.month, '2026-08');

        // Now let July's stale response land.
        repo.gates['2026-07']!.complete();
        await julyFuture;

        // August must still be showing — the stale July response was
        // discarded.
        expect(controller.selectedMonth, '2026-08');
        expect(controller.summary!.month, '2026-08');
        expect(controller.status, FinanceStatus.loaded);
      },
    );

    test(
      'a failed month switch sets error status and discards the old '
      'month\'s data — never label August while showing July\'s summary',
      () async {
        final repo = FakeFinanceRepository();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        expect(controller.summary!.month, '2026-07');

        repo.failNext = const FinanceFetchFailure('boom');
        await controller.load('tok', '2026-08');

        expect(controller.selectedMonth, '2026-08');
        expect(controller.status, FinanceStatus.error);
        expect(controller.error, FinanceError.fetchFailed);
        // July's stale summary/transactions must not linger under the
        // August label.
        expect(controller.summary, isNull);
        expect(controller.transactions, isEmpty);
      },
    );

    test(
      'switching months clears the old summary synchronously, before the '
      'fetch resolves',
      () async {
        final repo = FakeFinanceRepository();
        repo.gates['2026-08'] = Completer<void>();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        expect(controller.summary!.month, '2026-07');

        final future = controller.load('tok', '2026-08');
        // Synchronously after calling load (before the gated fetch
        // resolves): the label has already moved to August, and July's
        // summary must already be gone.
        expect(controller.selectedMonth, '2026-08');
        expect(controller.summary, isNull);
        expect(controller.status, FinanceStatus.loading);

        repo.gates['2026-08']!.complete();
        await future;
        expect(controller.summary!.month, '2026-08');
      },
    );

    test(
      'notifyOnStart notifies immediately (before the fetch resolves) so a '
      'user-gesture month switch shows loading feedback right away',
      () async {
        final repo = FakeFinanceRepository();
        repo.gates['2026-08'] = Completer<void>();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        final future = controller.load('tok', '2026-08', notifyOnStart: true);
        expect(notifyCount, 1);

        repo.gates['2026-08']!.complete();
        await future;
        // 3, not 2: the split-spending line now loads independently (design
        // D9, task 6) and notifies on its own resolution — in addition to
        // the `notifyOnStart` notify and `load`'s own final notify — since
        // it must never be silently folded into the main fetch's single
        // notification.
        expect(notifyCount, 3);
      },
    );

    test('populates budgets alongside categories/summary/transactions', () async {
      final repo = FakeFinanceRepository();
      await repo.upsertBudget('tok', amount: 10000);
      await repo.upsertBudget('tok', categoryId: 'cat-food', amount: 3000);
      repo.budgetCalls.clear();
      final controller = _controller(repo);

      await controller.load('tok', '2026-07');

      expect(controller.budgets, hasLength(2));
      expect(controller.budgets.map((b) => b.categoryId), containsAll([null, 'cat-food']));
    });

    test('switching months clears the old month\'s budgets synchronously', () async {
      final repo = FakeFinanceRepository();
      await repo.upsertBudget('tok', amount: 10000);
      repo.gates['2026-08'] = Completer<void>();
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');
      expect(controller.budgets, hasLength(1));

      final future = controller.load('tok', '2026-08');
      // Synchronously: July's budgets must already be gone before August's
      // (gated) response resolves.
      expect(controller.budgets, isEmpty);

      repo.gates['2026-08']!.complete();
      await future;
      expect(controller.budgets, hasLength(1));
    });

    test(
      'a slow budgets response for a previously selected month never lands '
      'under the currently selected month',
      () async {
        final repo = FakeFinanceRepository();
        await repo.upsertBudget('tok', amount: 10000);
        repo.budgetGates['2026-07'] = Completer<void>();
        final controller = _controller(repo);

        final julyFuture = controller.load('tok', '2026-07');
        final augustFuture = controller.load('tok', '2026-08');
        await augustFuture;
        expect(controller.selectedMonth, '2026-08');
        expect(controller.budgets, hasLength(1));

        repo.budgetGates['2026-07']!.complete();
        await julyFuture;

        expect(controller.selectedMonth, '2026-08');
        expect(controller.budgets, hasLength(1));
      },
    );
  });

  group('split spending (design D6/D9, task 6)', () {
    test('a month with split shares loads them', () async {
      final repo = FakeFinanceRepository()
        ..splitSpendingByMonth['2026-08'] = const [SplitSpending(currency: 'TWD', amount: 900, countedInTransactions: true)];
      final controller = _controller(repo);

      await controller.load('tok', '2026-08');

      expect(controller.splitSpendingStatus, SplitSpendingStatus.loaded);
      expect(controller.splitSpending, [const SplitSpending(currency: 'TWD', amount: 900, countedInTransactions: true)]);
    });

    test('a month with no split shares loads an empty list, not a zero row', () async {
      final repo = FakeFinanceRepository();
      final controller = _controller(repo);

      await controller.load('tok', '2026-08');

      expect(controller.splitSpendingStatus, SplitSpendingStatus.loaded);
      expect(controller.splitSpending, isEmpty);
    });

    test(
      'a split-spending failure does not blank the rest of the month — status stays loaded',
      () async {
        final repo = FakeFinanceRepository()..splitSpendingFailNext = const FinanceFetchFailure('boom');
        final controller = _controller(repo);

        await controller.load('tok', '2026-08');

        // The month's own recorded data loaded fine.
        expect(controller.status, FinanceStatus.loaded);
        expect(controller.error, isNull);
        // Only the split-spending line reports its own failure.
        expect(controller.splitSpendingStatus, SplitSpendingStatus.error);
      },
    );

    test(
      'a main-fetch failure does not stop the split-spending line from loading successfully',
      () async {
        final repo = FakeFinanceRepository()
          ..failNext = const FinanceFetchFailure('boom')
          ..splitSpendingByMonth['2026-08'] = const [SplitSpending(currency: 'TWD', amount: 900, countedInTransactions: true)];
        final controller = _controller(repo);

        await controller.load('tok', '2026-08');

        expect(controller.status, FinanceStatus.error);
        expect(controller.splitSpendingStatus, SplitSpendingStatus.loaded);
        expect(controller.splitSpending, [const SplitSpending(currency: 'TWD', amount: 900, countedInTransactions: true)]);
      },
    );

    test('switching months clears the previous month\'s split-spending value', () async {
      final repo = FakeFinanceRepository()
        ..splitSpendingByMonth['2026-07'] = const [SplitSpending(currency: 'TWD', amount: 900, countedInTransactions: true)];
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');
      expect(controller.splitSpending, isNotEmpty);

      repo.splitSpendingGates['2026-08'] = Completer<void>();
      final future = controller.load('tok', '2026-08');

      // Cleared synchronously on the month switch, before the new month's
      // response has even arrived — the same guard `summary`/`transactions`
      // get.
      expect(controller.splitSpending, isEmpty);

      repo.splitSpendingGates['2026-08']!.complete();
      await future;
    });

    test(
      "reloading the SAME month clears the previous load's split-spending value too, so a "
      "second account never sees the first one's figures",
      () async {
        final repo = FakeFinanceRepository()
          ..splitSpendingByMonth['2026-07'] = const [SplitSpending(currency: 'TWD', amount: 987654, countedInTransactions: true)];
        final controller = _controller(repo);
        await controller.load('tokA', '2026-07');
        expect(controller.splitSpending, isNotEmpty);

        // The second account signs in within the same calendar month, so
        // `isMonthChange` is false. Its split leg is still in flight while
        // the (independent) main fetch resolves and flips `status` to
        // `loaded` — the window in which the overview paints whatever is on
        // this field.
        repo.splitSpendingByMonth['2026-07'] = const [];
        repo.splitSpendingGates['2026-07'] = Completer<void>();
        final future = controller.load('tokB', '2026-07');

        expect(controller.splitSpending, isEmpty);
        expect(controller.splitSpendingStatus, SplitSpendingStatus.loading);

        repo.splitSpendingGates['2026-07']!.complete();
        await future;

        expect(controller.splitSpending, isEmpty);
      },
    );

    test(
      'a slow response for a month the user has since switched away from is discarded '
      '(month-switching race guard, task 6.1b)',
      () async {
        final repo = FakeFinanceRepository()
          ..splitSpendingByMonth['2026-07'] = const [SplitSpending(currency: 'TWD', amount: 111, countedInTransactions: true)]
          ..splitSpendingByMonth['2026-08'] = const [SplitSpending(currency: 'TWD', amount: 222, countedInTransactions: true)];
        final controller = _controller(repo);

        repo.splitSpendingGates['2026-07'] = Completer<void>();
        final julyFuture = controller.load('tok', '2026-07');
        final augustFuture = controller.load('tok', '2026-08');
        await augustFuture;

        expect(controller.selectedMonth, '2026-08');
        expect(controller.splitSpending, [const SplitSpending(currency: 'TWD', amount: 222, countedInTransactions: true)]);

        // The stale July response now lands late — it must not clobber
        // August's already-shown value.
        repo.splitSpendingGates['2026-07']!.complete();
        await julyFuture;

        expect(controller.selectedMonth, '2026-08');
        expect(controller.splitSpending, [const SplitSpending(currency: 'TWD', amount: 222, countedInTransactions: true)]);
      },
    );
  });

  group('saveBudgets', () {
    test(
      'a successful save whose reload is superseded still returns saved',
      () async {
        // The named case behind invariant I6 in
        // `finance_controller_race_invariants_test.dart`. Kept as its own
        // test so the failure message says *saveBudgets*: `budget_sheet.dart`
        // closes on what this call returns, and the budgets were stored
        // before the reload behind them was even issued. `status` is
        // deliberately NOT part of the answer — here it is still `loading`,
        // because the newer background reload that superseded this call's own
        // reload has not landed yet, and the screen is its business.
        final repo = FakeFinanceRepository();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');

        // The save's own reload stalls...
        final saveReload = Completer<void>();
        repo.gates['2026-07'] = saveReload;
        final save = controller.saveBudgets('tok', {null: 20000});
        await pumpEventQueue();

        // ...while a newer background reload starts and is still in flight,
        // which is what leaves `status` on `loading` rather than resolving
        // it. Gated too: released, it would settle the status itself and the
        // test would pass without the save resolving anything.
        final backgroundReload = Completer<void>();
        repo.gates['2026-07'] = backgroundReload;
        final background = controller.load(
          'tok',
          '2026-07',
          background: true,
        );
        await pumpEventQueue();

        saveReload.complete();

        expect(
          await save,
          FinanceWriteResult.saved,
          reason:
              'the budgets were written server-side before the reload was '
              'ever issued, so the sheet must not be told the save failed',
        );
        expect(
          controller.status,
          FinanceStatus.loading,
          reason:
              'the screen belongs to the newer reload, which is still in '
              'flight — the save reports itself through its return value '
              'instead of pretending to know what the screen should show',
        );

        backgroundReload.complete();
        await background;
        expect(controller.status, FinanceStatus.loaded);
        expect(controller.error, isNull);
      },
    );

    test('sends only the diff: one upsert, one delete, unchanged skipped', () async {
      final repo = FakeFinanceRepository();
      await repo.upsertBudget('tok', amount: 10000);
      await repo.upsertBudget('tok', categoryId: 'cat-food', amount: 3000);
      repo.budgetCalls.clear();
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');
      final existingId = controller.budgets.firstWhere((b) => b.categoryId == 'cat-food').id;

      await controller.saveBudgets('tok', {
        null: 25000, // changed
        'cat-food': null, // cleared -> delete
        // 'cat-transport' is intentionally absent — untouched fields send
        // nothing, so it's simply never included in the desired map.
      });

      expect(repo.budgetCalls, ['upsert:null:25000', 'delete:$existingId']);
      expect(controller.status, FinanceStatus.loaded);
      expect(controller.budgets, hasLength(1));
      expect(controller.budgets.single.categoryId, isNull);
      expect(controller.budgets.single.amount, 25000);
    });

    test('an unchanged amount sends nothing', () async {
      final repo = FakeFinanceRepository();
      await repo.upsertBudget('tok', amount: 10000);
      repo.budgetCalls.clear();
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');

      await controller.saveBudgets('tok', {null: 10000});

      expect(repo.budgetCalls, isEmpty);
      expect(controller.status, FinanceStatus.loaded);
    });

    test('amount 0 is treated the same as clearing (delete)', () async {
      final repo = FakeFinanceRepository();
      await repo.upsertBudget('tok', amount: 10000);
      repo.budgetCalls.clear();
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');
      final id = controller.budgets.single.id;

      await controller.saveBudgets('tok', {null: 0});

      expect(repo.budgetCalls, ['delete:$id']);
      expect(controller.budgets, isEmpty);
    });

    test(
      'partial failure: reloads immediately showing the applied step, keeps '
      'the failed step reflected as an error, and a retry does not re-send '
      'the already-applied delete',
      () async {
        final repo = FakeFinanceRepository();
        await repo.upsertBudget('tok', amount: 10000);
        await repo.upsertBudget('tok', categoryId: 'cat-food', amount: 3000);
        repo.budgetCalls.clear();
        repo._budgetCallCount = 0;
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        final foodId = controller.budgets.firstWhere((b) => b.categoryId == 'cat-food').id;

        // Batch: delete cat-food (succeeds, call #1), then upsert the
        // overall budget (fails, call #2).
        repo.failOnBudgetCallNumber = 2;
        await controller.saveBudgets('tok', {'cat-food': null, null: 25000});

        expect(repo.budgetCalls, ['delete:$foodId', 'upsert:null:25000']);
        // The reload reflects the delete that did apply.
        expect(controller.budgets, hasLength(1));
        expect(controller.budgets.single.categoryId, isNull);
        expect(controller.budgets.single.amount, 10000); // upsert never landed
        expect(controller.status, FinanceStatus.error);
        expect(controller.error, FinanceError.validation);

        // Retry with the same desired map: the diff is recomputed against
        // the reloaded state, so the already-applied delete isn't resent —
        // only the still-pending upsert goes out.
        repo.budgetCalls.clear();
        await controller.saveBudgets('tok', {'cat-food': null, null: 25000});

        expect(repo.budgetCalls, ['upsert:null:25000']);
        expect(controller.status, FinanceStatus.loaded);
        expect(controller.budgets.single.amount, 25000);
      },
    );

    test('a 401 during a batch surfaces needsReauth after reloading', () async {
      final repo = FakeFinanceRepository();
      await repo.upsertBudget('tok', amount: 10000);
      repo.budgetCalls.clear();
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');

      repo.failNext = const FinanceReauthenticationRequired();
      await controller.saveBudgets('tok', {null: 25000});

      expect(controller.status, FinanceStatus.needsReauth);
    });
  });

  group('addTransaction', () {
    test('reloads the transaction\'s own month, jumping selectedMonth there', () async {
      final controller = _controller(FakeFinanceRepository());
      await controller.load('tok', '2026-07');

      await controller.addTransaction(
        'tok',
        type: FinanceType.expense,
        amount: 500,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-08-15',
      );

      expect(controller.selectedMonth, '2026-08');
      expect(controller.status, FinanceStatus.loaded);
      expect(controller.transactions, hasLength(1));
      expect(controller.transactions.single.date, '2026-08-15');
    });

    test('reloads the same month when the date stays within it', () async {
      final controller = _controller(FakeFinanceRepository());
      await controller.load('tok', '2026-07');

      await controller.addTransaction(
        'tok',
        type: FinanceType.expense,
        amount: 500,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-07-20',
      );

      expect(controller.selectedMonth, '2026-07');
      expect(controller.transactions, hasLength(1));
    });

    test('a validation failure leaves prior data intact', () async {
      final repo = FakeFinanceRepository();
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');
      final categoriesBefore = controller.categories;

      repo.failNext = const FinanceValidationFailure();
      await controller.addTransaction(
        'tok',
        type: FinanceType.expense,
        amount: 0,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-07-20',
      );

      expect(controller.status, FinanceStatus.error);
      expect(controller.error, FinanceError.validation);
      expect(controller.categories, same(categoriesBefore));
      expect(controller.transactions, isEmpty);
      // `_mutate` never called `load` for a validation failure (the write
      // itself was rejected, nothing was ever re-fetched) — `reloadFailed`
      // must stay false, or the ledger tabs would permanently show a
      // "couldn't refresh" notice about data that was never stale, on top
      // of the sheet's own validation error.
      expect(controller.reloadFailed, isFalse);
    });

    test('a 401 surfaces needsReauth', () async {
      final repo = FakeFinanceRepository();
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');
      repo.failNext = const FinanceReauthenticationRequired();

      await controller.addTransaction(
        'tok',
        type: FinanceType.expense,
        amount: 500,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-07-20',
      );

      expect(controller.status, FinanceStatus.needsReauth);
    });

    test(
      "a write's own reload superseded by a concurrent background reload "
      '(e.g. FinanceScaffold._reloadLedger firing from a split write while '
      'this write is also landing) must not leave status stuck on `loading` '
      "— every caller that reads `status` right after awaiting addTransaction "
      'treats anything but `loaded` as the write having failed',
      () async {
        final repo = FakeFinanceRepository();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');

        // Call 2 (the write's own reload): gated, so its `getSummary`
        // response sits mid-flight once addTransaction's internal `load`
        // reaches it.
        final gate = Completer<void>();
        repo.gates['2026-07'] = gate;
        final write = controller.addTransaction(
          'tok',
          type: FinanceType.expense,
          amount: 500,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-20',
        );
        // Let the write's own reload actually start and capture its
        // (earlier) sequence number before call 3 below starts and captures
        // a later one — otherwise the two would race the other way.
        await pumpEventQueue();

        // Call 3 (the background reload a concurrent split write would
        // fire): a fresh, later `load` for the same month, gated on the
        // same completer so it too sits mid-flight — matching the review's
        // probe ("gate call 2 and call 3, release call 2 first").
        final background = controller.load('tok', '2026-07', background: true);
        await pumpEventQueue();

        // Release call 2 first: its response is now stale (call 3 moved
        // `_loadSeq` on), so `load` discards it — but the write itself
        // already succeeded, and `status` must say so, not sit on
        // `loading` until call 3 also lands.
        gate.complete();
        await write;
        expect(controller.status, FinanceStatus.loaded);

        await background;
        expect(controller.status, FinanceStatus.loaded);
      },
    );
  });

  group('updateTransaction', () {
    test('reloads the (possibly changed) month of the edited transaction', () async {
      final controller = _controller(_FakeWithSeed());
      await controller.load('tok', '2026-07');
      final id = controller.transactions.single.id;

      await controller.updateTransaction(
        'tok',
        id,
        type: FinanceType.expense,
        amount: 900,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-09-01',
      );

      expect(controller.selectedMonth, '2026-09');
      expect(controller.transactions.single.amount, 900);
    });
  });

  group('deleteTransaction', () {
    test('reloads the currently selected month, not the deleted date', () async {
      final controller = _controller(_FakeWithSeed());
      await controller.load('tok', '2026-07');
      final id = controller.transactions.single.id;

      await controller.deleteTransaction('tok', id);

      expect(controller.selectedMonth, '2026-07');
      expect(controller.status, FinanceStatus.loaded);
      expect(controller.transactions, isEmpty);
    });

    test('a not-found failure leaves prior data intact', () async {
      final repo = _FakeWithSeed();
      final controller = _controller(repo);
      await controller.load('tok', '2026-07');

      repo.failNext = const FinanceNotFound();
      await controller.deleteTransaction('tok', 'missing');

      expect(controller.status, FinanceStatus.error);
      expect(controller.error, FinanceError.notFound);
      expect(controller.transactions, hasLength(1));
    });
  });

  group('markReloadFailed', () {
    test('notifies listeners — a screen already on the tab, not one that '
        'rebuilds by switching to it, has no other way to learn the marking '
        'just appeared', () async {
      final controller = _controller(_FakeWithSeed());
      await controller.load('tok', '2026-07');
      var notified = false;
      controller.addListener(() => notified = true);

      controller.markReloadFailed();

      expect(notified, isTrue);
      expect(controller.reloadFailed, isTrue);
    });

    test('a no-op before the first successful load — there is nothing on '
        'screen yet for a notice to be about', () async {
      final controller = _controller(_FakeWithSeed());
      var notified = false;
      controller.addListener(() => notified = true);

      controller.markReloadFailed();

      expect(notified, isFalse);
      expect(controller.reloadFailed, isFalse);
    });
  });

  group('reset', () {
    test('clears the loaded month back to its pre-load state', () async {
      final controller = _controller(_FakeWithSeed());
      await controller.load('tok', '2026-07');
      expect(controller.summary, isNotNull);
      // Left `true` on purpose before `reset()`: without this,
      // `reloadFailed` starts (and stays) `false` regardless of whether
      // `reset()` clears it, so the assertion below would pass even with
      // the clear removed — the #156 shape in miniature (a per-user flag
      // `reset()`'s field-by-field list has to remember on its own): the
      // previous account's own reload failure otherwise survives sign-out
      // and greets the *next* signed-in account with a stale "couldn't
      // refresh" notice the moment their own `summary` is non-null.
      controller.markReloadFailed();
      expect(controller.reloadFailed, isTrue);

      controller.reset();

      expect(controller.selectedMonth, '');
      expect(controller.status, FinanceStatus.loading);
      expect(controller.summary, isNull);
      expect(controller.transactions, isEmpty);
      expect(controller.categories, isEmpty);
      expect(controller.splitSpending, isEmpty);
      expect(controller.reloadFailed, isFalse);
    });

    test(
      'a load already in flight when reset() is called must not repopulate the '
      "controller once it lands — this app-lifetime singleton would otherwise "
      'hand the next signed-in account the previous one\'s figures on '
      'sign-out (the #156/#157 shape)',
      () async {
        final repo = FakeFinanceRepository()
          ..splitSpendingByMonth['2026-07'] = const [
            SplitSpending(currency: 'TWD', amount: 500, countedInTransactions: true),
          ];
        final controller = _controller(repo);

        // The old guard (`selectedMonth != month`) caught this because
        // `reset()` cleared `selectedMonth` to `''`, which happened to make
        // every in-flight response's own captured month mismatch. The
        // sequence-number guard that replaced it has no equivalent side
        // effect unless `reset()` also bumps the sequence.
        final gate = Completer<void>();
        repo.gates['2026-07'] = gate;
        final inFlight = controller.load('tok', '2026-07');

        controller.reset();
        gate.complete();
        await inFlight;

        expect(controller.selectedMonth, '');
        expect(controller.status, FinanceStatus.loading);
        expect(controller.summary, isNull);
        expect(controller.transactions, isEmpty);
        expect(controller.splitSpending, isEmpty);
      },
    );

    test(
      "reset() called while a write's own network call is still in flight "
      "must stick even once that write later succeeds and reloads — the "
      "write's post-success reload starts *after* reset() with the "
      "signed-out session's own token, mints its own fresh, perfectly "
      "current sequence number, and so would otherwise repaint the "
      'previous account\'s figures over a screen `reset()` already '
      'cleared (the #156/#157 leak shape, this time reached through a '
      'write rather than a plain `load`)',
      () async {
        final repo = _GatedAddFake();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        expect(controller.summary, isNotNull);

        final write = controller.addTransaction(
          'tok',
          type: FinanceType.expense,
          amount: 500,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-20',
        );
        await repo.addStarted.future;

        controller.reset();
        expect(controller.summary, isNull);

        repo.addGate.complete();
        await write;

        expect(
          controller.summary,
          isNull,
          reason: "the write's own reload, started after reset(), must not repopulate the controller",
        );
        expect(controller.transactions, isEmpty);
        expect(controller.selectedMonth, '');
      },
    );
  });

  group('a stale write-failure arm racing a newer, already-settled call', () {
    test(
      "a write that fails without reloading (needsReauth/validation/"
      'fetchFailed/unknown) must not paint `status`/`error` once a newer '
      'call — a month switch, say — has already settled its own terminal '
      'status: only the 409/404 arms reload before they paint, but every '
      'arm must still defer to whichever call is current',
      () async {
        final repo = _GatedAddFake();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        expect(controller.status, FinanceStatus.loaded);

        // Hold the write's own network call while a newer, current call
        // (a month switch) settles first.
        repo.addFailNext = const FinanceValidationFailure();
        final write = controller.addTransaction(
          'tok',
          type: FinanceType.expense,
          amount: 10,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-05',
        );
        await repo.addStarted.future;

        repo.failNext = const FinanceReauthenticationRequired();
        await controller.load('tok', '2026-08');
        expect(controller.status, FinanceStatus.needsReauth);

        // Release the older write — its validation failure must not
        // overwrite the newer call's needsReauth exit.
        repo.addGate.complete();
        await write;

        expect(
          controller.status,
          FinanceStatus.needsReauth,
          reason: 'a stale write failure must not paint over a newer call\'s settled status',
        );
      },
    );
  });

  group('_reportRefusedWrite guards', () {
    test(
      "reset() while a refused write's own network call is still in flight "
      'must stop that write from reporting its refusal at all — its '
      "captured epoch is stale by the time the refusal reaches "
      '`_reportRefusedWrite`, so this must not call `load` with the '
      "signed-out session's token or repaint the screen `reset()` already "
      'cleared (the #156/#157 shape, reached through a *refused* write '
      'this time, mirroring the existing reset test for a write that '
      'succeeds)',
      () async {
        final repo = _GatedAddFake();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        expect(controller.status, FinanceStatus.loaded);

        repo.addFailNext = const FinanceConflict();
        final write = controller.addTransaction(
          'tok',
          type: FinanceType.expense,
          amount: 500,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-20',
        );
        await repo.addStarted.future;

        final loadCallsBeforeReset = repo.getSummaryCallCount;
        controller.reset();
        expect(controller.status, FinanceStatus.loading);
        expect(controller.selectedMonth, '');

        repo.addGate.complete();
        final result = await write;

        expect(result, FinanceWriteResult.conflict);
        expect(
          repo.getSummaryCallCount,
          loadCallsBeforeReset,
          reason: "a refused write whose session ended must not issue a load with the signed-out token",
        );
        expect(controller.status, FinanceStatus.loading);
        expect(controller.selectedMonth, '');
      },
    );

    test(
      "a refused write's own reload landing on a needsReauth exit must not "
      'be overwritten by the refusal it is reporting — the sign-in exit is '
      "the more important fact for the reader than the write's own 409, and "
      'painting the refusal over it would strand them on a retry that can '
      'never succeed',
      () async {
        final repo = _GatedAddFake();
        final controller = _controller(repo);
        await controller.load('tok', '2026-07');
        expect(controller.status, FinanceStatus.loaded);

        repo.addFailNext = const FinanceConflict();
        final write = controller.addTransaction(
          'tok',
          type: FinanceType.expense,
          amount: 500,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-20',
        );
        await repo.addStarted.future;

        // The refused write's own reload (issued by `_reportRefusedWrite`
        // once the conflict lands) hits a 401 instead of succeeding.
        repo.failNext = const FinanceReauthenticationRequired();
        repo.addGate.complete();
        final result = await write;

        expect(result, FinanceWriteResult.conflict);
        expect(
          controller.status,
          FinanceStatus.needsReauth,
          reason: "the write's own reload's 401 must win over the conflict it was reporting — "
              'painting `error`/conflict here would hide a real sign-in exit behind '
              'a retry that can never succeed',
        );
      },
    );
  });
}

/// A [FakeFinanceRepository] whose `addTransaction` holds until [addGate]
/// completes — lets a test control exactly when a write's own network call
/// lands, for interleavings [FakeFinanceRepository.gates] (which only gates
/// `getSummary`, i.e. `load`) cannot express. [addFailNext], separate from
/// [FakeFinanceRepository.failNext], throws once the gate releases instead
/// of before it — so a test can hold a write mid-flight *and* choose to fail
/// it, in either order relative to a concurrent `load`.
class _GatedAddFake extends FakeFinanceRepository {
  final addGate = Completer<void>();
  final addStarted = Completer<void>();
  Object? addFailNext;

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
    addStarted.complete();
    await addGate.future;
    if (addFailNext != null) {
      final failure = addFailNext!;
      addFailNext = null;
      throw failure;
    }
    return super.addTransaction(
      idToken,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
  }
}

/// A [FakeFinanceRepository] pre-seeded with one July transaction, for tests
/// that need an existing transaction to edit/delete.
class _FakeWithSeed extends FakeFinanceRepository {
  _FakeWithSeed() {
    _byMonth['2026-07'] = [
      const FinanceTransaction(
        id: 'seed-1',
        type: FinanceType.expense,
        amount: 300,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-07-10',
      ),
    ];
  }
}
