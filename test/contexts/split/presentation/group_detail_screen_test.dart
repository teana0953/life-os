import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/group_member.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/domain/split_share.dart';
import 'package:life_os/contexts/split/presentation/group_detail_screen.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../support/fake_split_repository.dart';
import '../support/split_presentation_fakes.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => 'tok';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

SplitExpense _expense({
  required String id,
  required String createdByUserId,
  required String payerUserId,
  String description = 'Dinner',
  String? payerDisplayName = 'Payer',
  List<SplitShare> shares = const [],
}) => SplitExpense(
  id: id,
  groupId: 'g1',
  payerUserId: payerUserId,
  payerDisplayName: payerDisplayName,
  createdByUserId: createdByUserId,
  amount: 900,
  currency: 'TWD',
  description: description,
  day: '2026-08-02',
  splitMode: 'equal',
  shares: shares,
  createdAt: '2026-08-02T00:00:00.000Z',
  updatedAt: '2026-08-02T00:00:00.000Z',
);

Widget _screen({
  required FakeSplitRepository repo,
  required String selfUserId,
  List<Friend> friends = const [],
}) => l10nRouterTestApp(
  home: GroupDetailScreen(
    getGroup: GetGroup(repo),
    getGroupBalances: GetGroupBalances(repo),
    listExpenses: ListExpenses(repo),
    addGroupMember: AddGroupMember(repo),
    archiveGroup: ArchiveGroup(repo),
    createExpense: CreateExpense(repo),
    updateExpense: UpdateExpense(repo),
    deleteExpense: DeleteExpense(repo),
    listFriends: ListFriends(FakeSocialRepositoryForSplit()..friends = friends),
    // The screen resolves the caller's own id from `/api/me` itself — it is
    // never handed one by whoever navigated there.
    getProfile: GetProfile(FakeProfileRepository()..profileToReturn = testProfile(id: selfUserId)),
    authRepository: _FakeAuthRepository(),
    groupId: 'g1',
    clock: () => DateTime(2026, 8, 2),
  ),
);

void main() {
  group('GroupDetailScreen', () {
    testWidgets('shows members and group balances with should-collect/should-pay wording', (
      tester,
    ) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        )
        ..membersToReturn = const [
          GroupMember(groupId: 'g1', userId: 'self-1', displayName: 'Self', joinedAt: '2026-01-01T00:00:00Z'),
          GroupMember(groupId: 'g1', userId: 'u2', displayName: 'Bo', joinedAt: '2026-01-01T00:00:00Z'),
        ]
        ..balancesToReturn = const [
          Balance(
            userId: 'u2',
            displayName: 'Bo',
            balances: [CurrencyBalance(currency: 'TWD', amount: 300)],
          ),
          Balance(
            userId: 'self-1',
            displayName: 'Self',
            balances: [CurrencyBalance(currency: 'TWD', amount: -300)],
          ),
        ];

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('split-member-row-u2')), findsOneWidget);
      expect(find.text(_loc.splitGroupBalanceShouldCollect('Bo', '300')), findsOneWidget);
      expect(find.text(_loc.splitGroupBalanceShouldPay('Self', '300')), findsOneWidget);
    });

    testWidgets('archive action is offered only to the group creator', (tester) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        );

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('split-archive-button')), findsOneWidget);

      final repo2 = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'creator-1',
          archivedAt: null,
        );
      await tester.pumpWidget(_screen(repo: repo2, selfUserId: 'self-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('split-archive-button')), findsNothing);
    });

    testWidgets('archiving requires a confirmation naming the group', (tester) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        );

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('split-archive-button')));
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitArchiveConfirmTitle('Trip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('split-archive-cancel')));
      await tester.pumpAndSettle();

      // Cancelling sends nothing. Counted, not inferred from `gotGroupId`:
      // the initial load already set that to 'g1', and archiving would set
      // it to the very same value, so it held either way.
      expect(repo.archiveCalls, 0);

      await tester.tap(find.byKey(const Key('split-archive-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('split-archive-confirm')));
      await tester.pumpAndSettle();
      expect(repo.archiveCalls, 1);
    });

    testWidgets('a failed archive says so instead of closing the dialog on nothing', (tester) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        );

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();

      repo.failNext = const SplitNotFound();
      await tester.tap(find.byKey(const Key('split-archive-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('split-archive-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitErrorNotFound), findsOneWidget);
    });

    testWidgets('a failed add-member says so — the only path that can produce already_a_member', (
      tester,
    ) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        );

      await tester.pumpWidget(
        _screen(
          repo: repo,
          selfUserId: 'self-1',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );
      await tester.pumpAndSettle();

      repo.failNext = const AlreadyAGroupMember();
      await tester.tap(find.byKey(const Key('split-add-member-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('split-add-member-candidate-f1')));
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitErrorAlreadyMember), findsOneWidget);
    });

    testWidgets('the archive gate follows the signed-in profile, not anything in the URL', (
      tester,
    ) async {
      // `selfUserId` here is only what the fake profile endpoint answers —
      // the screen takes no caller-supplied id at all.
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'creator-1',
          archivedAt: null,
        );

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'creator-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('split-archive-button')), findsOneWidget);
    });

    testWidgets('a group with nothing outstanding says everyone is settled, not a blank card', (
      tester,
    ) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        )
        ..balancesToReturn = const [
          Balance(
            userId: 'u2',
            displayName: 'Bo',
            balances: [CurrencyBalance(currency: 'TWD', amount: 0)],
          ),
        ];

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('split-group-no-balances')), findsOneWidget);
    });

    testWidgets('a group expense row names who paid and the viewer own share', (tester) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        )
        ..expensesToReturn = [
          _expense(
            id: 'e1',
            createdByUserId: 'other',
            payerUserId: 'other',
            payerDisplayName: 'Dana Paidforit',
            shares: const [SplitShare(userId: 'self-1', displayName: 'Self', amount: 300)],
          ),
        ];

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Dana Paidforit'), findsOneWidget);
      expect(find.text(_loc.splitYourShare('300')), findsOneWidget);
    });

    testWidgets('archived group hides add-expense/add-member but expenses stay editable', (
      tester,
    ) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: '2026-08-02T00:00:00Z',
        )
        ..expensesToReturn = [_expense(id: 'e1', createdByUserId: 'self-1', payerUserId: 'self-1')];

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('split-group-fab')), findsNothing);
      expect(find.byKey(const Key('split-add-member-button')), findsNothing);
      expect(find.byKey(const Key('split-group-archived-badge')), findsOneWidget);
      // The existing expense is still editable by its creator/payer.
      expect(find.byKey(const Key('split-group-expense-edit-e1')), findsOneWidget);
    });

    testWidgets('edit action is offered only to an expense creator or payer', (tester) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        )
        ..expensesToReturn = [
          _expense(id: 'e-mine', createdByUserId: 'self-1', payerUserId: 'other'),
          _expense(id: 'e-not-mine', createdByUserId: 'other', payerUserId: 'other2'),
        ];

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('split-group-expense-edit-e-mine')), findsOneWidget);
      expect(find.byKey(const Key('split-group-expense-edit-e-not-mine')), findsNothing);
    });

    testWidgets('an unnamed member shows the neutral placeholder, never a raw id', (tester) async {
      final repo = FakeSplitRepository()
        ..groupToReturn = const SplitGroup(
          id: 'g1',
          name: 'Trip',
          createdByUserId: 'self-1',
          archivedAt: null,
        )
        ..membersToReturn = const [
          GroupMember(groupId: 'g1', userId: 'ghost-uuid-123', displayName: null, joinedAt: '2026-01-01T00:00:00Z'),
        ];

      await tester.pumpWidget(_screen(repo: repo, selfUserId: 'self-1'));
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitUnknownMember), findsOneWidget);
      expect(find.text('ghost-uuid-123'), findsNothing);
    });
  });
}
