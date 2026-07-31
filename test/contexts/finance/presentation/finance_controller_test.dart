import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/delete_transaction.dart';
import 'package:life_os/contexts/finance/application/get_finance_month.dart';
import 'package:life_os/contexts/finance/application/update_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_category.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_repository.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/monthly_summary.dart';
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
}

FinanceController _controller(FakeFinanceRepository repo) => FinanceController(
  GetFinanceMonth(repo),
  AddTransaction(repo),
  UpdateTransaction(repo),
  DeleteTransaction(repo),
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
        expect(notifyCount, 2);
      },
    );
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
