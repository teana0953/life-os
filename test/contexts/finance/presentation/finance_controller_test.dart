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

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async {
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
