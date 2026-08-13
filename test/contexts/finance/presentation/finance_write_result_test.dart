import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/monthly_summary.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';

import '../finance_test_support.dart';

/// Every write path's own reported outcome, in isolation from concurrency.
///
/// **Why this file exists.** [FinanceController.status] is the *screen's*
/// state: any concurrent call may move it. The four write paths therefore
/// report their own outcome by returning it ([FinanceWriteResult]), and the
/// three sheets read that return value instead of `status`. This file pins the
/// two halves the sheets depend on, once per write path:
///
/// * the write succeeded ⇒ the caller is told `saved`, **whatever the reload
///   that follows it does** (its 401/500 belongs to the refresh, not to the
///   row that is already on the server — reporting it as a failed save is what
///   makes a user press Save twice and pay twice);
/// * the server refused the write ⇒ the caller is told which refusal it was,
///   because the record sheet answers a 409 and a 404 with different copy and
///   a different exit.
///
/// The concurrency half — "and none of this changes when other calls are in
/// flight" — lives in `finance_controller_race_invariants_test.dart` (I6).

/// Fails chosen `getSummary` calls, so a *reload* can fail while the write
/// before it succeeded. [FakeFinanceRepository.failNext] cannot express this:
/// it fires once, and the write itself would consume it.
class _ReloadFailingRepository extends FakeFinanceRepository {
  /// 1-indexed `getSummary` call numbers that throw [reloadFailure].
  final Set<int> failSummaryCalls = {};
  Object reloadFailure = const FinanceFetchFailure('reload boom');

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async {
    final callNumber = summaryTokens.length + 1;
    if (failSummaryCalls.contains(callNumber)) {
      summaryTokens.add(idToken);
      throw reloadFailure;
    }
    return super.getSummary(idToken, month);
  }
}

const _seededRow = FinanceTransaction(
  id: 't-seed',
  type: FinanceType.expense,
  amount: 300,
  currency: 'TWD',
  categoryId: 'cat-food',
  date: '2026-07-10',
);

Future<FinanceController> _loaded(FakeFinanceRepository repo) async {
  repo.byMonth['2026-07'] = [_seededRow];
  final controller = testFinanceController(repo);
  await controller.load('tok', '2026-07');
  expect(controller.status, FinanceStatus.loaded);
  return controller;
}

/// The four write paths, each issued against a loaded 2026-07.
final _writes = <String, Future<FinanceWriteResult> Function(FinanceController)>{
  'addTransaction': (c) => c.addTransaction(
    'tok',
    type: FinanceType.expense,
    amount: 500,
    currency: 'TWD',
    categoryId: 'cat-food',
    date: '2026-07-15',
  ),
  'updateTransaction': (c) => c.updateTransaction(
    'tok',
    't-seed',
    type: FinanceType.expense,
    amount: 700,
    currency: 'TWD',
    categoryId: 'cat-food',
    date: '2026-07-15',
  ),
  'deleteTransaction': (c) => c.deleteTransaction('tok', 't-seed'),
  'saveBudgets': (c) => c.saveBudgets('tok', {null: 50000}),
};

void main() {
  group('the write succeeded ⇒ the caller is told saved', () {
    for (final entry in _writes.entries) {
      test('${entry.key} returns saved', () async {
        final repo = FakeFinanceRepository();
        final controller = await _loaded(repo);

        expect(await entry.value(controller), FinanceWriteResult.saved);
      });

      // LINCHPIN. This is #165 itself: the row is on the server, and the
      // reload after it is the only thing that failed.
      test(
        '${entry.key} returns saved even though its own reload failed to fetch',
        () async {
          final repo = _ReloadFailingRepository();
          final controller = await _loaded(repo);
          // The seeding load above was `getSummary` #1; the reload this write
          // triggers is #2.
          repo.failSummaryCalls.add(2);

          expect(await entry.value(controller), FinanceWriteResult.saved);
          expect(
            controller.status,
            FinanceStatus.error,
            reason:
                'the screen really is stale — the "couldn\'t refresh" notice '
                'must still fire; that is what `status`/`reloadFailed` are '
                'for, and precisely what the write\'s own result is not',
          );
          expect(controller.reloadFailed, isTrue);
        },
      );

      test(
        '${entry.key} returns saved even though its own reload got a 401',
        () async {
          final repo = _ReloadFailingRepository()
            ..reloadFailure = const FinanceReauthenticationRequired();
          final controller = await _loaded(repo);
          repo.failSummaryCalls.add(2);

          expect(
            await entry.value(controller),
            FinanceWriteResult.saved,
            reason:
                'the session dying while the screen refreshes says nothing '
                'about the row the server already accepted',
          );
          expect(controller.status, FinanceStatus.needsReauth);
        },
      );
    }
  });

  group('the server refused the write ⇒ the caller is told which refusal', () {
    final refusals = <String, ({Object thrown, FinanceWriteResult result})>{
      'a 401': (
        thrown: const FinanceReauthenticationRequired(),
        result: FinanceWriteResult.needsReauth,
      ),
      'a 400': (
        thrown: const FinanceValidationFailure(),
        result: FinanceWriteResult.validation,
      ),
      'a 409': (
        thrown: const FinanceConflict(),
        result: FinanceWriteResult.conflict,
      ),
      'a 404': (
        thrown: const FinanceNotFound(),
        result: FinanceWriteResult.notFound,
      ),
      'a fetch failure': (
        thrown: const FinanceFetchFailure('boom'),
        result: FinanceWriteResult.fetchFailed,
      ),
      'an unexpected error': (
        thrown: StateError('boom'),
        result: FinanceWriteResult.unknown,
      ),
    };

    for (final write in _writes.entries) {
      for (final refusal in refusals.entries) {
        test('${write.key} rejected with ${refusal.key}', () async {
          final repo = FakeFinanceRepository();
          final controller = await _loaded(repo);
          repo.failNext = refusal.value.thrown;

          // The budget endpoints have no split-moved-underneath answer, so
          // `saveBudgets` has no `FinanceConflict` arm and a 409 lands in its
          // catch-all. Pinned as it is rather than inventing an arm: the
          // sheet's copy is the same either way.
          final expected =
              write.key == 'saveBudgets' && refusal.key == 'a 409'
              ? FinanceWriteResult.unknown
              : refusal.value.result;
          expect(await write.value(controller), expected);
        });
      }
    }
  });
}
