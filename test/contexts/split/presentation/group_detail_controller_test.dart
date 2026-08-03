import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/group_member.dart';
import 'package:life_os/contexts/split/domain/settlement.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/domain/split_input.dart';
import 'package:life_os/contexts/split/presentation/group_detail_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_exceptions.dart';

import '../support/fake_split_repository.dart';
import '../support/split_presentation_fakes.dart';

GroupDetailController _controller(
  FakeSplitRepository repo,
  FakeSocialRepositoryForSplit socialRepo, {
  FakeProfileRepository? profileRepo,
}) => GroupDetailController(
  GetGroup(repo),
  GetGroupBalances(repo),
  ListExpenses(repo),
  AddGroupMember(repo),
  ArchiveGroup(repo),
  CreateExpense(repo),
  UpdateExpense(repo),
  DeleteExpense(repo),
  ListFriends(socialRepo),
  GetProfile(profileRepo ?? (FakeProfileRepository()..profileToReturn = testProfile())),
  GetBalances(repo),
  CreateSettlement(repo),
);

void main() {
  group('GroupDetailController.load', () {
    test('loads group, members, group balances, expenses, and friend candidates', () async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        )
        ..membersToReturn = const [
          GroupMember(groupId: 'g1', userId: 'self-1', displayName: 'Self', joinedAt: '2026-01-01T00:00:00Z'),
        ]
        ..balancesToReturn = const [
          Balance(
            userId: 'self-1',
            displayName: 'Self',
            balances: [CurrencyBalance(currency: 'TWD', amount: 100)],
          ),
        ];
      final socialRepo = FakeSocialRepositoryForSplit()
        ..friends = const [Friend(userId: 'f1', displayName: 'Friend')];
      final controller = _controller(repo, socialRepo);

      await controller.load('tok', 'g1');

      expect(controller.status, GroupDetailStatus.loaded);
      expect(controller.group!.name, 'Trip');
      expect(controller.members.single.displayName, 'Self');
      expect(controller.groupBalances.single.balances.single.amount, 100);
      expect(controller.friends.single.displayName, 'Friend');
    });

    test('401 goes to needsReauth', () async {
      final repo = FakeSplitRepository()..failNext = const SplitReauthenticationRequired();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, socialRepo);

      await controller.load('tok', 'g1');

      expect(controller.status, GroupDetailStatus.needsReauth);
    });

    test('resolves the caller own user id from the profile, not from any caller-supplied value', () async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'creator-1',
          archivedAt: null,
        );
      final controller = _controller(
        repo,
        FakeSocialRepositoryForSplit(),
        profileRepo: FakeProfileRepository()..profileToReturn = testProfile(id: 'creator-1'),
      );

      await controller.load('tok', 'g1');

      expect(controller.selfUserId, 'creator-1');
    });

    test('a profile fetch failure goes to its own error, not a null self id', () async {
      final repo = FakeSplitRepository();
      final controller = _controller(
        repo,
        FakeSocialRepositoryForSplit(),
        profileRepo: FakeProfileRepository()..failNext = const ProfileFetchFailure('boom'),
      );

      await controller.load('tok', 'g1');

      expect(controller.status, GroupDetailStatus.error);
      expect(controller.error, GroupDetailError.profileFailed);
      expect(controller.selfUserId, isNull);
      // The group itself was never fetched — the profile gate ran first.
      expect(repo.gotGroupId, isNull);
    });

    test('a fetch failure goes to error', () async {
      final repo = FakeSplitRepository()..failNext = const SplitFetchFailure();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = _controller(repo, socialRepo);

      await controller.load('tok', 'g1');

      expect(controller.status, GroupDetailStatus.error);
      expect(controller.error, GroupDetailError.fetchFailed);
    });
  });

  group('GroupDetailController mutations', () {
    GroupDetailController loadedController(FakeSplitRepository repo, FakeSocialRepositoryForSplit socialRepo) {
      repo.groupToReturn = const SplitGroup(
        id: 'g1',
        name: 'Trip',
        createdByUserId: 'self-1',
        archivedAt: null,
      );
      return _controller(repo, socialRepo);
    }

    test('addMember reloads on success', () async {
      final repo = FakeSplitRepository()
        ..memberToReturn = const GroupMember(
          groupId: 'g1',
          userId: 'u2',
          displayName: 'Bo',
          joinedAt: '2026-01-01T00:00:00Z',
        );
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = loadedController(repo, socialRepo);
      await controller.load('tok', 'g1');
      expect(controller.members, isEmpty);

      // What the fake returns changes between the load and the mutation, so
      // only an actual refetch can make the assertion below hold (the
      // seq/status pair it used to assert was already true beforehand).
      repo.membersToReturn = const [
        GroupMember(groupId: 'g1', userId: 'u2', displayName: 'Bo', joinedAt: '2026-01-01T00:00:00Z'),
      ];
      await controller.addMember('tok', 'g1', 'u2');

      expect(controller.mutationErrorSeq, 0);
      expect(controller.status, GroupDetailStatus.loaded);
      expect(controller.members.single.displayName, 'Bo');
    });

    test('addMember failure is recorded without disturbing loaded members', () async {
      final repo = FakeSplitRepository()
        ..membersToReturn = const [
          GroupMember(groupId: 'g1', userId: 'self-1', displayName: 'Self', joinedAt: '2026-01-01T00:00:00Z'),
        ];
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = loadedController(repo, socialRepo);
      await controller.load('tok', 'g1');
      expect(controller.members, hasLength(1));

      repo.failNext = const AlreadyAGroupMember();
      await controller.addMember('tok', 'g1', 'u2');

      expect(controller.mutationErrorSeq, 1);
      expect(controller.mutationError, isA<AlreadyAGroupMember>());
      expect(controller.members, hasLength(1));
    });

    test('archive reloads on success', () async {
      final repo = FakeSplitRepository();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = loadedController(repo, socialRepo);
      await controller.load('tok', 'g1');

      repo.groupToReturn = const SplitGroup(
        id: 'g1',
        name: 'Trip',
        createdByUserId: 'self-1',
        archivedAt: '2026-08-02T00:00:00Z',
      );
      await controller.archive('tok', 'g1');

      expect(controller.mutationErrorSeq, 0);
      expect(controller.group!.archivedAt, isNotNull);
    });

    test('createExpense sends the locked group id and reloads', () async {
      final repo = FakeSplitRepository()..expenseToReturn = _sampleExpense();
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = loadedController(repo, socialRepo);
      await controller.load('tok', 'g1');

      await controller.createExpense(
        'tok',
        groupId: 'g1',
        payerUserId: 'self-1',
        amount: 100,
        currency: 'TWD',
        description: 'Lunch',
        day: '2026-08-02',
        split: const EqualSplitInput(['self-1']),
      );

      expect(repo.gotGroupId, 'g1');
      expect(controller.mutationErrorSeq, 0);
    });

    test('deleteExpense reloads on success', () async {
      final repo = FakeSplitRepository()..expensesToReturn = [_sampleExpense()];
      final socialRepo = FakeSocialRepositoryForSplit();
      final controller = loadedController(repo, socialRepo);
      await controller.load('tok', 'g1');
      expect(controller.expenses, hasLength(1));

      // The deleted expense is gone from what the fake returns next; only a
      // refetch can make the controller agree.
      repo.expensesToReturn = const [];
      await controller.deleteExpense('tok', 'e1');

      expect(controller.mutationErrorSeq, 0);
      expect(repo.gotExpenseId, 'e1');
      expect(controller.expenses, isEmpty);
    });

    test('a load that lands after dispose does not throw "used after being disposed"', () async {
      final repo = FakeSplitRepository();
      final controller = loadedController(repo, FakeSocialRepositoryForSplit());
      controller.addListener(() {});

      // Tapping back during the initial load is exactly this.
      final inFlight = controller.load('tok', 'g1');
      controller.dispose();

      await expectLater(inFlight, completes);
    });

    group('settling a two-person balance (design D8, task 5b.3)', () {
      test('load also loads personal (two-person) balances, distinct from group balances', () async {
        final repo = FakeSplitRepository()
          ..balancesToReturn = const [
            Balance(
              userId: 'u2',
              displayName: 'Bo',
              balances: [CurrencyBalance(currency: 'TWD', amount: 300)],
            ),
          ];
        final controller = loadedController(repo, FakeSocialRepositoryForSplit());

        await controller.load('tok', 'g1');

        expect(controller.personalBalances.single.userId, 'u2');
        expect(controller.groupBalances.single.userId, 'u2');
      });

      test('createSettlement always sends group_id null, never this screen\'s own group', () async {
        final repo = FakeSplitRepository()..settlementToReturn = _sampleSettlement();
        final controller = loadedController(repo, FakeSocialRepositoryForSplit());
        await controller.load('tok', 'g1');

        await controller.createSettlement(
          'tok',
          groupId: 'g1',
          fromUserId: 'self-1',
          toUserId: 'u2',
          amount: 300,
          currency: 'TWD',
          day: '2026-08-02',
        );

        expect(repo.gotCreateSettlementGroupId, isNull);
        expect(controller.mutationErrorSeq, 0);
      });
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
