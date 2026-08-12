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

/// Invariant tests for [FinanceController]'s concurrency guards.
///
/// **Why this file exists separately from `finance_controller_test.dart`.**
/// Every race test already in that file is a hand-built *pairing*: gate call
/// A, run call B to completion, release A, assert. Such a test proves one
/// interleaving — the one the test itself constructed — and nothing about
/// the ones it did not. Mutating `if (seq != _loadSeq)` to `if (false)` turns
/// them red, but mutating it to `if (seq < _loadSeq - 1)`, dropping the guard
/// from one of the five `catch` arms, or adding a sixth call site that
/// forgets to reload through `_reloadAfterWrite` leaves every pairing green.
/// That is this repo's recorded lesson: mutation evidence cannot speak for an
/// interleaving nobody constructed, so the guard has to be stated as an
/// invariant instead of enumerated as pairs.
///
/// So: three concurrent operations, **all 3! = 6 release orders enumerated**,
/// crossed with every call path that reaches [FinanceController.load]
/// (background reload, month switch, add/update/delete transaction, save
/// budgets). The invariants below are checked on *every* `notifyListeners`,
/// not only on the settled end state, so an illegal state that exists for one
/// frame is caught even if the end state is legal.
///
/// The four invariants:
///
/// * **I1 — never goes backwards.** Every response this fake produces is
///   stamped with the generation number of the `load` call that asked for it
///   (a transaction whose `amount` is the generation, a summary whose expense
///   total is, a split-spending row whose amount is). Since generations are
///   handed out in call order, "the newest call wins" is exactly "the
///   generation visible on screen never decreases". This one statement
///   replaces every pairing.
/// * **I2 — never stuck loading.** (a) once everything has settled,
///   [FinanceController.status] is terminal; (b) the moment a *write's* own
///   future completes, its status is terminal — because that is precisely
///   what `AddTransactionSheet._save` / `budget_sheet.dart` read to decide
///   whether to tell the user the save failed. (b) covers all four write call
///   sites at once, and would cover a fifth the day one is added — the reason
///   it has to be an invariant and not four case tests.
/// * **I3 — never crosses accounts.** With a `reset()` (sign-out) injected
///   into the interleaving, no response that lands afterwards may move *any*
///   field off its cleared value. Compared field by field, not just
///   `summary`: #156/#157 was a checklist-style reset missing one field.
/// * **I4 — self-consistent.** `status == loaded` implies `summary != null`.
///   Both finance tabs guard on `status == error && summary == null` and then
///   dereference `controller.summary!`, so a `loaded`-with-null-summary is a
///   crash. No pairing test constructs it; only an always-on invariant finds
///   it.
///
/// Gating uses [Completer]s plus `pumpEventQueue()`, never
/// `Future.delayed(Duration.zero)`: a zero-delay fake closes the observation
/// window before the first pump, which this repo has already been burned by.

/// A repository fake that stamps every response with the generation number
/// of the `load` that requested it, and can hold each generation's responses
/// behind a gate until the test releases it.
///
/// Generations are counted **per method** rather than shared, so nothing here
/// depends on the order in which `load` happens to fire its five reads
/// internally. Every `load` calls each of the five exactly once, so the *n*th
/// call of each method belongs to the *n*th `load`, and [release] completes
/// index *n* across all five.
class _GenerationalFakeRepository implements FinanceRepository {
  static const _gatedMethods = [
    'getCategories',
    'getSummary',
    'getTransactions',
    'listBudgets',
    'getSplitSpending',
  ];

  /// While false every read resolves immediately (used for the setup load
  /// that puts a month on screen); while true each read waits for its own
  /// generation's gate.
  bool gating = false;

  final Map<String, List<Completer<void>>> _gates = {
    for (final method in _gatedMethods) method: <Completer<void>>[],
  };

  /// Thrown by the next write call, once.
  Object? failNextWrite;

  /// Generation numbers whose *main* fetch should fail with this error
  /// instead of resolving (the background-reload-failed path).
  final Map<int, Object> failGeneration = {};

  int count(String method) => _gates[method]!.length;

  /// Completes generation [generation]'s gate on all five reads.
  void release(int generation) {
    releaseMainFetch(generation);
    releaseSplitSpending(generation);
  }

  /// Completes only the four reads `GetFinanceMonth` batches, leaving the
  /// split-spending leg — which `load` starts *before* them and awaits after
  /// — still outstanding.
  void releaseMainFetch(int generation) {
    for (final method in _gatedMethods) {
      if (method == 'getSplitSpending') continue;
      _complete(method, generation);
    }
  }

  void releaseSplitSpending(int generation) =>
      _complete('getSplitSpending', generation);

  void _complete(String method, int generation) {
    final gates = _gates[method]!;
    if (gates.length < generation) {
      throw StateError(
        '$method was never called a ${generation}th time — the fake\'s '
        'per-method generation numbering has drifted from load()',
      );
    }
    final gate = gates[generation - 1];
    if (!gate.isCompleted) gate.complete();
  }

  /// Registers this call as the next generation of [method] and waits for its
  /// gate. Returns the generation number, which the caller stamps into its
  /// response.
  Future<int> _arrive(String method) async {
    final gates = _gates[method]!;
    final gate = Completer<void>();
    gates.add(gate);
    final generation = gates.length;
    if (!gating) gate.complete();
    await gate.future;
    final failure = failGeneration[generation];
    if (failure != null) throw failure;
    return generation;
  }

  @override
  Future<List<FinanceCategory>> getCategories(String idToken) async {
    await _arrive('getCategories');
    return const [
      FinanceCategory(
        id: 'cat-food',
        name: '餐飲',
        type: FinanceType.expense,
        icon: 'other',
        sortOrder: 0,
        archived: false,
      ),
    ];
  }

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async {
    final generation = await _arrive('getSummary');
    return MonthlySummary(
      month: month,
      totals: [
        CurrencyTotal(
          currency: 'TWD',
          expense: generation,
          income: 0,
          net: -generation,
        ),
      ],
      byCategory: const [],
    );
  }

  @override
  Future<List<FinanceTransaction>> getTransactions(
    String idToken, {
    required String from,
    required String to,
  }) async {
    final generation = await _arrive('getTransactions');
    return [
      FinanceTransaction(
        id: 'gen-$generation',
        type: FinanceType.expense,
        amount: generation,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '${from.substring(0, 7)}-15',
      ),
    ];
  }

  @override
  Future<List<FinanceBudget>> listBudgets(String idToken, String month) async {
    final generation = await _arrive('listBudgets');
    return [
      FinanceBudget(
        id: 'budget-1',
        categoryId: null,
        amount: 100000,
        spent: generation,
        remaining: 100000 - generation,
        percent: 0,
      ),
    ];
  }

  @override
  Future<List<SplitSpending>> getSplitSpending(
    String idToken,
    String month,
  ) async {
    final generation = await _arrive('getSplitSpending');
    return [
      SplitSpending(
        currency: 'TWD',
        amount: generation,
        countedInTransactions: true,
      ),
    ];
  }

  Object? _takeWriteFailure() {
    final failure = failNextWrite;
    failNextWrite = null;
    return failure;
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
    final failure = _takeWriteFailure();
    if (failure != null) throw failure;
    return FinanceTransaction(
      id: 'written',
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
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
    final failure = _takeWriteFailure();
    if (failure != null) throw failure;
    return FinanceTransaction(
      id: id,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
  }

  @override
  Future<void> deleteTransaction(String idToken, String id) async {
    final failure = _takeWriteFailure();
    if (failure != null) throw failure;
  }

  @override
  Future<void> upsertBudget(
    String idToken, {
    String? categoryId,
    required int amount,
  }) async {
    final failure = _takeWriteFailure();
    if (failure != null) throw failure;
  }

  @override
  Future<void> deleteBudget(String idToken, String id) async {
    final failure = _takeWriteFailure();
    if (failure != null) throw failure;
  }

  // The ledger controller never touches the networth or instalment ports;
  // these satisfy the shared FinanceRepository interface only.
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
  ) => throw UnimplementedError();

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
  Future<void> settleInstallmentPlan(
    String idToken,
    String id, {
    int? amount,
  }) => throw UnimplementedError();
}

FinanceController _controller(_GenerationalFakeRepository repo) =>
    FinanceController(
      GetFinanceMonth(repo),
      AddTransaction(repo),
      UpdateTransaction(repo),
      DeleteTransaction(repo),
      UpsertBudget(repo),
      DeleteBudget(repo),
      GetSplitSpending(repo),
    );

/// One concurrent operation under test: a name, whether its caller reads
/// [FinanceController.status] as its own verdict (I2b), and the call itself.
class _Op {
  final String name;

  /// True for the write paths whose caller (`AddTransactionSheet._save`,
  /// `budget_sheet.dart`) treats a non-`loaded` status as "your save failed".
  /// A plain `load` has no such caller and is legitimately allowed to be
  /// superseded without resolving.
  final bool readsOwnStatus;

  final Future<void> Function(FinanceController controller, int index) run;

  const _Op(this.name, {required this.readsOwnStatus, required this.run});
}

final _ops = <_Op>[
  _Op(
    'background reload',
    readsOwnStatus: false,
    run: (controller, index) =>
        controller.load('tok', '2026-07', background: true),
  ),
  _Op(
    'month switch',
    readsOwnStatus: false,
    // Distinct months, so the interleaving also exercises the month-change
    // clearing path rather than only same-month reloads.
    run: (controller, index) => controller.load(
      'tok',
      ['2026-08', '2026-09', '2026-10'][index],
      notifyOnStart: true,
    ),
  ),
  _Op(
    'addTransaction',
    readsOwnStatus: true,
    run: (controller, index) => controller.addTransaction(
      'tok',
      type: FinanceType.expense,
      amount: 100 + index,
      currency: 'TWD',
      categoryId: 'cat-food',
      date: '2026-07-15',
    ),
  ),
  _Op(
    'updateTransaction',
    readsOwnStatus: true,
    run: (controller, index) => controller.updateTransaction(
      'tok',
      'gen-1',
      type: FinanceType.expense,
      amount: 200 + index,
      currency: 'TWD',
      categoryId: 'cat-food',
      date: '2026-07-15',
    ),
  ),
  _Op(
    'deleteTransaction',
    readsOwnStatus: true,
    run: (controller, index) => controller.deleteTransaction('tok', 'gen-1'),
  ),
  _Op(
    'saveBudgets',
    readsOwnStatus: true,
    run: (controller, index) =>
        controller.saveBudgets('tok', {null: 50000 + index}),
  ),
];

/// All 3! orders in which three gated responses can land.
const _releaseOrders = [
  [0, 1, 2],
  [0, 2, 1],
  [1, 0, 2],
  [1, 2, 0],
  [2, 0, 1],
  [2, 1, 0],
];

/// Watches a controller and records every invariant violation it sees.
///
/// Records rather than throws: several of the notifications happen inside
/// `_mutate`'s and `load`'s `try` blocks, whose `catch (_)` would swallow a
/// `TestFailure` and turn a caught invariant breach into a green run — the
/// "guard that cannot fail" shape this repo keeps hitting.
class _InvariantWatcher {
  final FinanceController controller;
  final List<String> violations = [];

  int _lastTransactionGeneration = 0;
  int _lastSummaryGeneration = 0;
  int _lastSplitGeneration = 0;

  _InvariantWatcher(this.controller) {
    controller.addListener(check);
  }

  void dispose() => controller.removeListener(check);

  void check() {
    // I1. A cleared field (month change, sign-out, or a load that has not
    // landed yet) is *no* observation, not generation zero — so clearing is
    // never mistaken for going backwards, while a genuinely stale response
    // overwriting a fresher one always is.
    if (controller.transactions.isNotEmpty) {
      final generation = controller.transactions.first.amount;
      if (generation < _lastTransactionGeneration) {
        violations.add(
          'I1 transactions went backwards: generation '
          '$_lastTransactionGeneration then $generation',
        );
      }
      _lastTransactionGeneration = generation;
    }
    final summary = controller.summary;
    if (summary != null && summary.totals.isNotEmpty) {
      final generation = summary.totals.first.expense;
      if (generation < _lastSummaryGeneration) {
        violations.add(
          'I1 summary went backwards: generation $_lastSummaryGeneration '
          'then $generation',
        );
      }
      _lastSummaryGeneration = generation;
    }
    if (controller.splitSpending.isNotEmpty) {
      final generation = controller.splitSpending.first.amount;
      if (generation < _lastSplitGeneration) {
        violations.add(
          'I1 splitSpending went backwards: generation $_lastSplitGeneration '
          'then $generation',
        );
      }
      _lastSplitGeneration = generation;
    }

    // I4. Both finance tabs do `controller.summary!` once they are past the
    // `status == error && summary == null` guard, so this pair is a crash.
    if (controller.status == FinanceStatus.loaded &&
        controller.summary == null) {
      violations.add('I4 status == loaded while summary == null');
    }
  }

  /// Sign-out clears everything, so the generations seen before it must not
  /// constrain the ones seen after (a fresh sign-in legitimately starts over).
  void forgetGenerations() {
    _lastTransactionGeneration = 0;
    _lastSummaryGeneration = 0;
    _lastSplitGeneration = 0;
  }
}

/// The result of running one interleaving.
class _Run {
  final _InvariantWatcher watcher;
  final Map<int, FinanceStatus> statusWhenOpCompleted;

  _Run(this.watcher, this.statusWhenOpCompleted);
}

/// Starts [ops] concurrently (each blocked on its own gated `load`), then
/// releases their responses in [releaseOrder], optionally calling `reset()`
/// in between.
Future<_Run> _interleave(
  FinanceController controller,
  _GenerationalFakeRepository repo, {
  required List<_Op> ops,
  required List<int> releaseOrder,
  bool resetBeforeRelease = false,
}) async {
  final watcher = _InvariantWatcher(controller);
  final statusWhenOpCompleted = <int, FinanceStatus>{};
  final futures = <Future<void>>[];
  final generations = <int>[];

  for (var index = 0; index < ops.length; index++) {
    final before = repo.count('getSummary');
    futures.add(() async {
      await ops[index].run(controller, index);
      statusWhenOpCompleted[index] = controller.status;
    }());
    // The op has to reach its gated read before the next one starts, so that
    // generation numbers line up with the order the ops were issued in.
    await pumpEventQueue();
    final after = repo.count('getSummary');
    expect(
      after,
      before + 1,
      reason:
          'the harness assumes each op issues exactly one load; '
          '"${ops[index].name}" issued ${after - before}',
    );
    generations.add(after);
  }

  if (resetBeforeRelease) {
    controller.reset();
    watcher.forgetGenerations();
  }

  for (final index in releaseOrder) {
    repo.release(generations[index]);
    await pumpEventQueue();
  }

  await Future.wait(futures);
  await pumpEventQueue();
  watcher.dispose();
  return _Run(watcher, statusWhenOpCompleted);
}

/// Loads a month with every gate open, so the controller starts each scenario
/// with something on screen (`summary != null`) — the state the notice, the
/// tabs, and `_reloadAfterWrite`'s own guard all key off.
Future<void> _seed(
  FinanceController controller,
  _GenerationalFakeRepository repo,
) async {
  repo.gating = false;
  await controller.load('tok', '2026-07');
  repo.gating = true;
  expect(controller.status, FinanceStatus.loaded);
  expect(controller.summary, isNotNull);
}

const _terminalStatuses = {
  FinanceStatus.loaded,
  FinanceStatus.error,
  FinanceStatus.needsReauth,
};

void main() {
  group('three concurrent operations, every release order', () {
    for (final op in _ops) {
      for (final order in _releaseOrders) {
        test('${op.name} ×3, responses land in order $order', () async {
          final repo = _GenerationalFakeRepository();
          final controller = _controller(repo);
          await _seed(controller, repo);

          final run = await _interleave(
            controller,
            repo,
            ops: [op, op, op],
            releaseOrder: order,
          );

          expect(
            run.watcher.violations,
            isEmpty,
            reason: 'invariant violated during the interleaving',
          );
          // I2a.
          expect(
            controller.status,
            isIn(_terminalStatuses),
            reason:
                'I2 everything has settled, so status must be terminal — '
                'a screen left on `loading` after every request finished is '
                'a spinner that never stops',
          );
          // I2b.
          if (op.readsOwnStatus) {
            for (var index = 0; index < 3; index++) {
              expect(
                run.statusWhenOpCompleted[index],
                isIn(_terminalStatuses),
                reason:
                    'I2 "${op.name}" #$index returned while status was still '
                    'loading; its caller reads exactly that to decide whether '
                    'to tell the user the save failed',
              );
            }
          }
        });
      }
    }

    for (final order in _releaseOrders) {
      test(
        'a write, a budget save and a background reload, order $order',
        () async {
          final repo = _GenerationalFakeRepository();
          final controller = _controller(repo);
          await _seed(controller, repo);

          final mixed = [_ops[2], _ops[5], _ops[0]];
          final run = await _interleave(
            controller,
            repo,
            ops: mixed,
            releaseOrder: order,
          );

          expect(run.watcher.violations, isEmpty);
          expect(controller.status, isIn(_terminalStatuses));
          for (var index = 0; index < mixed.length; index++) {
            if (!mixed[index].readsOwnStatus) continue;
            expect(
              run.statusWhenOpCompleted[index],
              isIn(_terminalStatuses),
              reason: 'I2 "${mixed[index].name}" returned still loading',
            );
          }
        },
      );
    }
  });

  test(
    'a superseded load still waits for its own split-spending leg',
    () async {
      final repo = _GenerationalFakeRepository();
      final controller = _controller(repo);
      await _seed(controller, repo);

      // Two concurrent reloads; the second one wins, so the first is
      // superseded and takes `load`'s early return.
      var supersededSettled = false;
      final superseded = controller
          .load('tok', '2026-07', background: true)
          .then((_) => supersededSettled = true);
      await pumpEventQueue();
      final supersededGeneration = repo.count('getSummary');
      final winner = controller.load('tok', '2026-07', background: true);
      await pumpEventQueue();
      final winnerGeneration = repo.count('getSummary');

      repo.release(winnerGeneration);
      await pumpEventQueue();

      // The superseded call's main fetch lands (and is discarded), but its
      // split-spending request is still outstanding.
      repo.releaseMainFetch(supersededGeneration);
      await pumpEventQueue();
      expect(
        supersededSettled,
        isFalse,
        reason:
            'load() promises callers "a fully settled state"; returning while '
            'its own split-spending leg is still in flight leaves a '
            'notifyListeners() about to fire on a controller the caller has '
            'already finished inspecting',
      );

      repo.releaseSplitSpending(supersededGeneration);
      await Future.wait([superseded, winner]);
      expect(supersededSettled, isTrue);
    },
  );

  group('sign-out lands in the middle of the interleaving', () {
    for (final op in _ops) {
      test('${op.name} ×3, reset() before any response lands', () async {
        final repo = _GenerationalFakeRepository();
        final controller = _controller(repo);
        await _seed(controller, repo);

        final run = await _interleave(
          controller,
          repo,
          ops: [op, op, op],
          releaseOrder: const [2, 0, 1],
          resetBeforeRelease: true,
        );

        expect(run.watcher.violations, isEmpty);
        // I3, field by field: #156/#157 was a reset that cleared a list of
        // fields and missed one, which no single-field assertion would see.
        expect(controller.summary, isNull, reason: 'I3 summary');
        expect(controller.transactions, isEmpty, reason: 'I3 transactions');
        expect(controller.categories, isEmpty, reason: 'I3 categories');
        expect(controller.budgets, isEmpty, reason: 'I3 budgets');
        expect(
          controller.installmentPlans,
          isEmpty,
          reason: 'I3 installmentPlans',
        );
        expect(controller.splitSpending, isEmpty, reason: 'I3 splitSpending');
        expect(
          controller.splitSpendingStatus,
          SplitSpendingStatus.loading,
          reason: 'I3 splitSpendingStatus',
        );
        expect(controller.selectedMonth, '', reason: 'I3 selectedMonth');
        expect(controller.reloadFailed, isFalse, reason: 'I3 reloadFailed');
      });
    }
  });

  group('a write that fails while a newer reload overtakes its own', () {
    // Each of these makes the *first* of three concurrent operations fail
    // server-side. Its own reload is then superseded by the two newer ones,
    // which is exactly the interleaving in which `status` stops speaking for
    // the failed write — so the write must still resolve to a terminal
    // status of its own rather than be left on `loading`.
    final backgroundReload = _ops[0];

    // `_mutate` deliberately reloads on only these two (design D5: the server
    // changed under the caller); the other arms never call `load`, so there
    // is no reload for a newer one to overtake and nothing here to test.
    final mutateFailures = <String, Object>{
      'a 409 conflict': const FinanceConflict(),
      'a 404': const FinanceNotFound(),
    };
    // `saveBudgets` reloads on *every* arm, so all five belong here.
    final budgetFailures = <String, Object>{
      'a 409 conflict': const FinanceConflict(),
      'a 404': const FinanceNotFound(),
      'a validation failure': const FinanceValidationFailure(),
      'a fetch failure': const FinanceFetchFailure('boom'),
      'a 401': const FinanceReauthenticationRequired(),
    };

    for (final entry in mutateFailures.entries) {
      for (final order in _releaseOrders) {
        test(
          'addTransaction rejected with ${entry.key}, order $order',
          () async {
            final repo = _GenerationalFakeRepository();
            final controller = _controller(repo);
            await _seed(controller, repo);
            repo.failNextWrite = entry.value;

            final run = await _interleave(
              controller,
              repo,
              ops: [_ops[2], backgroundReload, backgroundReload],
              releaseOrder: order,
            );

            expect(run.watcher.violations, isEmpty);
            expect(
              run.statusWhenOpCompleted[0],
              isIn(_terminalStatuses),
              reason:
                  'I2 addTransaction returned still loading after ${entry.key}; '
                  'the record sheet reads that as "not saved yet" and keeps '
                  'the user waiting on a write that is already decided',
            );
          },
        );
      }
    }

    for (final entry in budgetFailures.entries) {
      for (final order in _releaseOrders) {
        test('saveBudgets rejected with ${entry.key}, order $order', () async {
          final repo = _GenerationalFakeRepository();
          final controller = _controller(repo);
          await _seed(controller, repo);
          repo.failNextWrite = entry.value;

          final run = await _interleave(
            controller,
            repo,
            ops: [_ops[5], backgroundReload, backgroundReload],
            releaseOrder: order,
          );

          expect(run.watcher.violations, isEmpty);
          expect(
            run.statusWhenOpCompleted[0],
            isIn(_terminalStatuses),
            reason:
                'I2 saveBudgets returned still loading after ${entry.key}; the '
                'budget sheet reads that as "your budget did not save"',
          );
        });
      }
    }
  });

  group('a write does not get reported as failed by a newer, unrelated reload failure', () {
    // Regression for 7af5e79: `_reloadAfterWrite` gated its supersede branch
    // on `status == FinanceStatus.loading`, so a newer background reload
    // that failed to *fetch* (landing on `error`/`fetchFailed` before this
    // write's own reload arrived) blocked the branch and left a transaction
    // that had genuinely just been written reported back to
    // `AddTransactionSheet._save` as a failed save — `status` never even
    // reaches `loaded`. `_ownedByNewerCall` is the fix: a newer call's own
    // plain reload failure ([reloadFailed] `true`) is not "owned" by anyone
    // and must not block resolving a known-successful write to `loaded`.
    test(
      'addTransaction resolves to loaded even though a newer background '
      "reload's own fetch failed first",
      () async {
        final repo = _GenerationalFakeRepository();
        final controller = _controller(repo);
        await _seed(controller, repo);

        final addFuture = controller.addTransaction(
          'tok',
          type: FinanceType.expense,
          amount: 500,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-15',
        );
        await pumpEventQueue();
        final addGeneration = repo.count('getSummary');

        // A concurrent, newer background reload whose own main fetch will
        // fail once released — unrelated to whether addTransaction's write
        // succeeded, which it already has.
        final bgFuture = controller.load('tok', '2026-07', background: true);
        await pumpEventQueue();
        final bgGeneration = repo.count('getSummary');
        expect(bgGeneration, addGeneration + 1);
        repo.failGeneration[bgGeneration] = const FinanceFetchFailure('boom');

        // The background reload's failure lands first, claiming `status`
        // before addTransaction's own reload lands.
        repo.release(bgGeneration);
        await pumpEventQueue();
        expect(controller.status, FinanceStatus.error);
        expect(controller.reloadFailed, isTrue);

        // addTransaction's own reload lands next — superseded (`bgGeneration`
        // is newer), but its write already succeeded server-side.
        repo.release(addGeneration);
        await Future.wait([addFuture, bgFuture]);

        expect(
          controller.status,
          FinanceStatus.loaded,
          reason:
              "the write succeeded; a newer call's own plain reload failure "
              'must not be reported back as this write having failed — '
              'AddTransactionSheet._save only pops the sheet on `loaded`, so '
              'anything else leaves it open telling the user a saved '
              'transaction failed to save, inviting a duplicate resubmit',
        );
        expect(
          controller.reloadFailed,
          isTrue,
          reason:
              "the background reload really did fail — the \"couldn't "
              'refresh" notice must still show even though the write '
              'itself resolves to loaded',
        );
      },
    );

    test(
      'a second write\'s own genuine conflict is not masked by a first '
      "write's stale reload landing after it",
      () async {
        final repo = _GenerationalFakeRepository();
        final controller = _controller(repo);
        await _seed(controller, repo);

        final addA = controller.addTransaction(
          'tok',
          type: FinanceType.expense,
          amount: 100,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-15',
        );
        await pumpEventQueue();
        final generationA = repo.count('getSummary');

        repo.failNextWrite = const FinanceConflict();
        final addB = controller.addTransaction(
          'tok',
          type: FinanceType.expense,
          amount: 200,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-15',
        );
        await pumpEventQueue();
        final generationB = repo.count('getSummary');
        expect(generationB, generationA + 1);

        // B's own reload (after its write was rejected with a conflict)
        // lands and succeeds — a genuine, owned outcome.
        repo.release(generationB);
        await pumpEventQueue();
        expect(controller.status, FinanceStatus.error);
        expect(controller.error, FinanceError.conflict);
        expect(controller.reloadFailed, isFalse);

        // A's own reload — for a write that succeeded — lands after B's and
        // is superseded by it.
        repo.release(generationA);
        await Future.wait([addA, addB]);

        expect(
          controller.status,
          FinanceStatus.error,
          reason:
              "B's genuine conflict is a different write's own reported "
              "outcome (reloadFailed is false), not a plain reload failure — "
              "A's stale, superseded success must not overwrite it",
        );
        expect(controller.error, FinanceError.conflict);
      },
    );
  });
}
