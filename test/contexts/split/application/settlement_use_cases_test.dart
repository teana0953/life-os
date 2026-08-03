import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/split/domain/settlement.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';

import '../support/fake_split_repository.dart';

const _settlement = Settlement(
  id: 's1',
  groupId: null,
  fromUserId: 'u1',
  fromDisplayName: 'Alex',
  toUserId: 'u2',
  toDisplayName: 'Bo',
  amount: 450,
  currency: 'TWD',
  day: '2026-08-02',
  note: null,
  createdByUserId: 'u1',
);

void main() {
  group('CreateSettlement', () {
    test('forwards every field to the repository, including a null groupId', () async {
      final repository = FakeSplitRepository()..settlementToReturn = _settlement;

      final settlement = await CreateSettlement(repository)(
        'token-1',
        groupId: null,
        fromUserId: 'u1',
        toUserId: 'u2',
        amount: 450,
        currency: 'TWD',
        day: '2026-08-02',
        note: 'lunch',
      );

      expect(repository.gotIdToken, 'token-1');
      expect(repository.gotGroupId, isNull);
      expect(repository.gotFromUserId, 'u1');
      expect(repository.gotToUserId, 'u2');
      expect(repository.gotAmount, 450);
      expect(repository.gotCurrency, 'TWD');
      expect(repository.gotDay, '2026-08-02');
      expect(repository.gotNote, 'lunch');
      expect(settlement, _settlement);
    });

    test('lets the repository error propagate', () async {
      final repository = FakeSplitRepository()..failNext = const CannotSettleWithSelf();

      expect(
        () => CreateSettlement(repository)(
          'token-1',
          fromUserId: 'u1',
          toUserId: 'u1',
          amount: 450,
          currency: 'TWD',
          day: '2026-08-02',
        ),
        throwsA(isA<CannotSettleWithSelf>()),
      );
    });
  });

  group('ListSettlements', () {
    test('forwards the filters and returns the repository result', () async {
      final repository = FakeSplitRepository()..settlementsToReturn = const [_settlement];

      final settlements = await ListSettlements(repository)(
        'token-1',
        groupId: 'g1',
        withUserId: 'u2',
      );

      expect(repository.gotGroupId, 'g1');
      expect(repository.gotWithUserId, 'u2');
      expect(settlements, [_settlement]);
    });

    test('lets the repository error propagate', () async {
      final repository = FakeSplitRepository()..failNext = const SplitFetchFailure();

      expect(() => ListSettlements(repository)('token-1'), throwsA(isA<SplitFetchFailure>()));
    });
  });

  group('DeleteSettlement', () {
    test('forwards the settlement id to the repository', () async {
      final repository = FakeSplitRepository();

      await DeleteSettlement(repository)('token-1', 's1');

      expect(repository.gotIdToken, 'token-1');
      expect(repository.gotSettlementId, 's1');
      expect(repository.deleteSettlementCalls, 1);
    });

    test('lets the repository error propagate', () async {
      final repository = FakeSplitRepository()..failNext = const SplitNotFound();

      expect(() => DeleteSettlement(repository)('token-1', 's1'), throwsA(isA<SplitNotFound>()));
    });
  });
}
