import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_input.dart';

import '../support/fake_split_repository.dart';

void main() {
  const expense = SplitExpense(
    id: 'e1',
    groupId: 'g1',
    payerUserId: 'u1',
    payerDisplayName: 'Alex',
    createdByUserId: 'u1',
    amount: 900,
    currency: 'TWD',
    description: 'Dinner',
    day: '2026-08-02',
    splitMode: 'equal',
    shares: [],
    createdAt: '2026-08-02T00:00:00.000Z',
    updatedAt: '2026-08-02T00:00:00.000Z',
  );

  test('ListExpenses forwards the group/with filters', () async {
    final repository = FakeSplitRepository()..expensesToReturn = const [expense];

    final expenses = await ListExpenses(repository)('token-1', groupId: 'g1', withUserId: 'u2');

    expect(repository.gotIdToken, 'token-1');
    expect(repository.gotGroupId, 'g1');
    expect(repository.gotWithUserId, 'u2');
    expect(expenses.single.id, 'e1');
  });

  test('ListExpenses lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitFetchFailure();

    expect(() => ListExpenses(repository)('token-1'), throwsA(isA<SplitFetchFailure>()));
  });

  test('CreateExpense forwards all fields to the repository', () async {
    final repository = FakeSplitRepository()..expenseToReturn = expense;
    const split = EqualSplitInput(['u1', 'u2']);

    final created = await CreateExpense(repository)(
      'token-1',
      groupId: 'g1',
      payerUserId: 'u1',
      amount: 900,
      currency: 'TWD',
      description: 'Dinner',
      day: '2026-08-02',
      split: split,
    );

    expect(repository.gotGroupId, 'g1');
    expect(repository.gotPayerUserId, 'u1');
    expect(repository.gotAmount, 900);
    expect(repository.gotCurrency, 'TWD');
    expect(repository.gotDescription, 'Dinner');
    expect(repository.gotDay, '2026-08-02');
    expect(repository.gotSplit, split);
    expect(created.id, 'e1');
  });

  test('CreateExpense lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SharesDoNotSumToAmount('short by 1');

    expect(
      () => CreateExpense(repository)(
        'token-1',
        payerUserId: 'u1',
        amount: 900,
        currency: 'TWD',
        description: 'Dinner',
        day: '2026-08-02',
        split: const EqualSplitInput(['u1']),
      ),
      throwsA(isA<SharesDoNotSumToAmount>()),
    );
  });

  test('GetExpense delegates expenseId', () async {
    final repository = FakeSplitRepository()..expenseToReturn = expense;

    final got = await GetExpense(repository)('token-1', 'e1');

    expect(repository.gotExpenseId, 'e1');
    expect(got.id, 'e1');
  });

  test('GetExpense lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitNotFound();

    expect(() => GetExpense(repository)('token-1', 'e1'), throwsA(isA<SplitNotFound>()));
  });

  test('UpdateExpense forwards expenseId and all fields to the repository', () async {
    final repository = FakeSplitRepository()..expenseToReturn = expense;
    const split = EqualSplitInput(['u1', 'u2']);

    final updated = await UpdateExpense(repository)(
      'token-1',
      'e1',
      payerUserId: 'u1',
      amount: 900,
      currency: 'TWD',
      description: 'Dinner',
      day: '2026-08-02',
      split: split,
    );

    expect(repository.gotExpenseId, 'e1');
    expect(repository.gotPayerUserId, 'u1');
    expect(repository.gotSplit, split);
    expect(updated.id, 'e1');
  });

  test('UpdateExpense lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const GroupArchived();

    expect(
      () => UpdateExpense(repository)(
        'token-1',
        'e1',
        payerUserId: 'u1',
        amount: 900,
        currency: 'TWD',
        description: 'Dinner',
        day: '2026-08-02',
        split: const EqualSplitInput(['u1']),
      ),
      throwsA(isA<GroupArchived>()),
    );
  });

  test('DeleteExpense delegates expenseId', () async {
    final repository = FakeSplitRepository();

    await DeleteExpense(repository)('token-1', 'e1');

    expect(repository.gotExpenseId, 'e1');
  });

  test('DeleteExpense lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitNotFound();

    expect(() => DeleteExpense(repository)('token-1', 'e1'), throwsA(isA<SplitNotFound>()));
  });
}
