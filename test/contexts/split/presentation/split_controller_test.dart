import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/settlement.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/domain/split_input.dart';
import 'package:life_os/contexts/split/presentation/split_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_exceptions.dart';

import '../support/fake_split_repository.dart';
import '../support/split_presentation_fakes.dart';

SplitController _controller(
  FakeSplitRepository repo,
  FakeProfileRepository profileRepo,
  FakeSocialRepositoryForSplit socialRepo,
) => SplitController(
  GetBalances(repo),
  ListGroups(repo),
  ListExpenses(repo),
  CreateExpense(repo),
  UpdateExpense(repo),
  DeleteExpense(repo),
  CreateGroup(repo),
  ListFriends(socialRepo),
  GetProfile(profileRepo),
  ListSettlements(repo),
  CreateSettlement(repo),
  DeleteSettlement(repo),
);

void main() {
  group('SplitController.load', () {
    test('resolves the caller profile first, then loads balances/groups/expenses/friends', () async {
      final repo = FakeSplitRepository()
        ..balancesToReturn = [
          const Balance(
            userId: 'u2',
            displayName: 'Bo',
            balances: [CurrencyBalance(currency: 'TWD', amount: 500)],
          ),
        ]
        ..groupsToReturn = const [
          SplitGroup(id: 'g1', name: 'Trip', createdByUserId: 'self-1', archivedAt: null),
        ];
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile(id: 'self-1');
      final socialRepo = FakeSocialRepositoryForSplit()
        ..friends = const [Friend(userId: 'f1', displayName: 'Friend')];
      final controller = _controller(repo, profileRepo, socialRepo);

      await controller.load('tok');

      expect(controller.status, SplitStatus.loaded);
      expect(controller.selfUserId, 'self-1');
      expect(controller.balances.single.displayName, 'Bo');
      expect(controller.groups.single.name, 'Trip');
      expect(controller.friends.single.displayName, 'Friend');
    });

    test('a profile fetch failure goes to an error state, not a null self id', () async {
      final repo = FakeSplitRepository();
      final profileRepo = FakeProfileRepository()..failNext = const ProfileFetchFailure('boom');
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);

      await controller.load('tok');

      expect(controller.status, SplitStatus.error);
      expect(controller.error, SplitError.profileFailed);
      expect(controller.selfUserId, isNull);
      // The split data itself was never fetched — the profile gate ran first.
      expect(repo.gotIdToken, isNull);
    });

    test('a profile 401 goes to needsReauth', () async {
      final repo = FakeSplitRepository();
      final profileRepo = FakeProfileRepository()..failNext = const ReauthenticationRequired();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);

      await controller.load('tok');

      expect(controller.status, SplitStatus.needsReauth);
    });

    test('a split-data 401 (after a resolved profile) goes to needsReauth', () async {
      final repo = FakeSplitRepository()..failNext = const SplitReauthenticationRequired();
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);

      await controller.load('tok');

      expect(controller.status, SplitStatus.needsReauth);
      expect(controller.selfUserId, isNotNull);
    });

    test('a split-data fetch failure goes to error/fetchFailed', () async {
      final repo = FakeSplitRepository()..failNext = const SplitFetchFailure();
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);

      await controller.load('tok');

      expect(controller.status, SplitStatus.error);
      expect(controller.error, SplitError.fetchFailed);
    });

    test('a friends-list 401 (social context) also surfaces as needsReauth', () async {
      final repo = FakeSplitRepository();
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile();
      final socialRepo = FakeSocialRepositoryForSplit()
        ..failNext = const SocialReauthenticationRequired();
      final controller = _controller(repo, profileRepo, socialRepo);

      await controller.load('tok');

      expect(controller.status, SplitStatus.needsReauth);
    });
  });

  group('SplitController mutations', () {
    test('createExpense reloads on success', () async {
      final repo = FakeSplitRepository()
        ..expenseToReturn = _sampleExpense()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        );
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);
      await controller.load('tok');
      expect(controller.expenses, isEmpty);

      // Change what the fake returns *between* the load and the mutation, so
      // the assertion below can only hold if the mutation refetched — the
      // `mutationErrorSeq == 0` / `status == loaded` pair it used to assert
      // was already true before the call.
      repo.expensesToReturn = [_sampleExpense()];
      await controller.createExpense(
        'tok',
        payerUserId: 'self-1',
        amount: 100,
        currency: 'TWD',
        description: 'Lunch',
        day: '2026-08-02',
        split: const EqualSplitInput(['self-1']),
      );

      expect(controller.mutationErrorSeq, 0);
      expect(controller.status, SplitStatus.loaded);
      expect(controller.expenses.single.id, 'e1');
    });

    test('a mutation failure is recorded on mutationError without disturbing loaded data', () async {
      final repo = FakeSplitRepository()
        ..groupsToReturn = const [
          SplitGroup(id: 'g1', name: 'Trip', createdByUserId: 'self-1', archivedAt: null),
        ];
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);
      await controller.load('tok');
      expect(controller.groups, hasLength(1));

      repo.failNext = const NotFriends();
      await controller.createExpense(
        'tok',
        payerUserId: 'self-1',
        amount: 100,
        currency: 'TWD',
        description: 'Lunch',
        day: '2026-08-02',
        split: const EqualSplitInput(['self-1']),
      );

      expect(controller.mutationErrorSeq, 1);
      expect(controller.mutationError, isA<NotFriends>());
      // The previously loaded groups are left untouched.
      expect(controller.groups, hasLength(1));
    });
  });

  group('SplitController settlements (task 5.1/5.2/5.3)', () {
    test('load also loads settlements alongside balances/groups/expenses', () async {
      final repo = FakeSplitRepository()
        ..settlementsToReturn = [_sampleSettlement()];
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile(id: 'self-1');
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);

      await controller.load('tok');

      expect(controller.settlements.single.id, 's1');
    });

    test('createSettlement always sends group_id null, even if a caller passed one', () async {
      final repo = FakeSplitRepository()..settlementToReturn = _sampleSettlement();
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile(id: 'self-1');
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);
      await controller.load('tok');

      await controller.createSettlement(
        'tok',
        groupId: 'g-should-be-ignored',
        fromUserId: 'self-1',
        toUserId: 'u2',
        amount: 300,
        currency: 'TWD',
        day: '2026-08-02',
      );

      // `gotCreateSettlementGroupId`, not `gotGroupId`: the follow-up
      // `load` runs an unfiltered `listSettlements`, which resets
      // `gotGroupId` to null — so asserting on it would pass whatever the
      // write actually sent (mirrors group_detail_controller_test.dart).
      expect(repo.gotCreateSettlementGroupId, isNull);
      expect(repo.gotFromUserId, 'self-1');
      expect(repo.gotToUserId, 'u2');
    });

    test('createSettlement reloads on success', () async {
      final repo = FakeSplitRepository()..settlementToReturn = _sampleSettlement();
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile(id: 'self-1');
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);
      await controller.load('tok');
      final loadsBefore = repo.getBalancesCalls;

      await controller.createSettlement(
        'tok',
        fromUserId: 'self-1',
        toUserId: 'u2',
        amount: 300,
        currency: 'TWD',
        day: '2026-08-02',
      );

      expect(repo.getBalancesCalls, loadsBefore + 1);
    });

    test('a failed createSettlement is recorded on mutationError, not status', () async {
      final repo = FakeSplitRepository();
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile(id: 'self-1');
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);
      await controller.load('tok');
      repo.failNext = const NotFriends();

      await controller.createSettlement(
        'tok',
        fromUserId: 'self-1',
        toUserId: 'u2',
        amount: 300,
        currency: 'TWD',
        day: '2026-08-02',
      );

      expect(controller.status, SplitStatus.loaded);
      expect(controller.mutationError, isA<NotFriends>());
    });

    test('deleteSettlement calls the repository and reloads', () async {
      final repo = FakeSplitRepository();
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile(id: 'self-1');
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);
      await controller.load('tok');
      final loadsBefore = repo.getBalancesCalls;

      await controller.deleteSettlement('tok', 's1');

      expect(repo.gotSettlementId, 's1');
      expect(repo.deleteSettlementCalls, 1);
      expect(repo.getBalancesCalls, loadsBefore + 1);
    });
  });

  group('SplitController lifecycle', () {
    test('a load that lands after dispose does not throw "used after being disposed"', () async {
      final repo = FakeSplitRepository();
      final profileRepo = FakeProfileRepository()..profileToReturn = testProfile();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, profileRepo, socialRepo);
      controller.addListener(() {});

      // Popping /finance (or signing out) while the tab is still loading is
      // exactly this: the State disposes the controller, the responses land
      // afterwards.
      final inFlight = controller.load('tok');
      controller.dispose();

      await expectLater(inFlight, completes);
    });
  });
}

Settlement _sampleSettlement() => const Settlement(
  id: 's1',
  groupId: null,
  fromUserId: 'self-1',
  fromDisplayName: 'Self',
  toUserId: 'u2',
  toDisplayName: 'Bo',
  amount: 300,
  currency: 'TWD',
  day: '2026-08-02',
  note: null,
  createdByUserId: 'self-1',
);

SplitExpense _sampleExpense() => const SplitExpense(
  id: 'e1',
  groupId: 'g1',
  payerUserId: 'self-1',
  payerDisplayName: 'Self',
  createdByUserId: 'self-1',
  amount: 100,
  currency: 'TWD',
  description: 'Lunch',
  day: '2026-08-02',
  splitMode: 'equal',
  shares: [],
  createdAt: '2026-08-02T00:00:00.000Z',
  updatedAt: '2026-08-02T00:00:00.000Z',
);
