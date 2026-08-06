import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/split/domain/group_member.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/domain/split_share.dart';
import 'package:life_os/contexts/split/presentation/split_controller.dart';
import 'package:life_os/contexts/split/presentation/split_expense_sheet.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../support/fake_split_repository.dart';
import '../support/split_presentation_fakes.dart';

const _self = 'self-1';
final _loc = lookupAppLocalizations(const Locale('en'));

SplitExpense _sampleExpense() => const SplitExpense(
  id: 'e1',
  groupId: null,
  payerUserId: _self,
  payerDisplayName: 'Self',
  createdByUserId: _self,
  amount: 100,
  currency: 'TWD',
  description: 'Lunch',
  day: '2026-08-02',
  splitMode: 'equal',
  shares: [],
  createdAt: '2026-08-02T00:00:00.000Z',
  updatedAt: '2026-08-02T00:00:00.000Z',
);

SplitController _controller(FakeSplitRepository repo) => SplitController(
  GetBalances(repo),
  ListGroups(repo),
  ListExpenses(repo),
  CreateExpense(repo),
  UpdateExpense(repo),
  DeleteExpense(repo),
  CreateGroup(repo),
  ListFriends(FakeSocialRepositoryForSplit()),
  GetProfile(FakeProfileRepository()),
  ListSettlements(repo),
  CreateSettlement(repo),
  DeleteSettlement(repo),
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required SplitExpenseSheet sheet,
}) async {
  await tester.pumpWidget(l10nTestApp(home: Scaffold(body: sheet)));
  await tester.pumpAndSettle();
}

void main() {
  group('SplitExpenseSheet — candidates', () {
    testWidgets('a locked group narrows candidates to its own members', (tester) async {
      final repo = FakeSplitRepository();
      final group = const SplitGroup(
        id: 'g1',
        name: 'Trip',
        createdByUserId: _self,
        archivedAt: null,
        members: [
          GroupMember(groupId: 'g1', userId: _self, displayName: 'Self', joinedAt: '2026-01-01T00:00:00Z'),
          GroupMember(groupId: 'g1', userId: 'u2', displayName: 'Bo', joinedAt: '2026-01-01T00:00:00Z'),
        ],
      );

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          lockedGroup: group,
          friends: const [Friend(userId: 'f-not-in-group', displayName: 'Not in group')],
        ),
      );

      expect(find.byKey(const Key('split-participant-u2')), findsOneWidget);
      expect(find.byKey(const Key('split-participant-f-not-in-group')), findsNothing);
      // No group selector while locked.
      expect(find.byKey(const Key('split-group-field')), findsNothing);
    });

    testWidgets('no group means friends plus the caller', (tester) async {
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      expect(find.byKey(const Key('split-participant-$_self')), findsOneWidget);
      expect(find.byKey(const Key('split-participant-f1')), findsOneWidget);
    });

    testWidgets('editing hides the group selector', (tester) async {
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          editing: _sampleExpense(),
        ),
      );

      expect(find.byKey(const Key('split-group-field')), findsNothing);
    });
  });

  group('SplitExpenseSheet — stake gate', () {
    testWidgets('unchecking self as a non-payer participant blocks save with a warning', (
      tester,
    ) async {
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      // A complete form first: the reason line states the *first* thing
      // blocking Save, so with a blank amount the blocker is the amount, not
      // the stake.
      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
      await tester.pumpAndSettle();

      // Make the friend the payer and drop self from participants.
      await tester.tap(find.byKey(const Key('split-payer-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friend One').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('split-participant-f1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('split-participant-$_self')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('split-stake-warning')), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('a blank amount is reported as the missing amount, not as a missing stake', (
      tester,
    ) async {
      // The stake warning used to be rendered from its own `if (!_hasStake)`
      // branch, ahead of the ordered reason — and a blank amount makes the
      // equal preview all zeros, so a checked participant read as having no
      // stake. Picking the payer (the field directly above) was answered
      // with "you must be the payer or hold a share above zero", while the
      // real reason, the missing amount, was suppressed entirely.
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      await tester.tap(find.byKey(const Key('split-payer-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friend One').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('split-stake-warning')), findsNothing);
      expect(find.byKey(const Key('split-save-blocked')), findsOneWidget);
      expect(find.text(_loc.splitAmountRequired), findsOneWidget);
    });

    testWidgets('being the payer satisfies the stake even with no participant share', (
      tester,
    ) async {
      final repo = FakeSplitRepository()..expenseToReturn = _sampleExpense();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      expect(find.byKey(const Key('split-stake-warning')), findsNothing);
    });
  });

  group('SplitExpenseSheet — equal split preview', () {
    // Pinned to the backend's own equalSplit cases (design.md D3/task 6.4b).
    testWidgets('100 split 3 ways previews 34/33/33 with the remainder on the lexically first id', (
      tester,
    ) async {
      final repo = FakeSplitRepository();
      final group = const SplitGroup(
        id: 'g1',
        name: 'Trip',
        createdByUserId: _self,
        archivedAt: null,
        members: [
          GroupMember(groupId: 'g1', userId: 'b-user', displayName: 'B', joinedAt: '2026-01-01T00:00:00Z'),
          GroupMember(groupId: 'g1', userId: 'a-user', displayName: 'A', joinedAt: '2026-01-01T00:00:00Z'),
          GroupMember(groupId: 'g1', userId: 'c-user', displayName: 'C', joinedAt: '2026-01-01T00:00:00Z'),
        ],
      );

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: 'a-user',
          today: '2026-08-02',
          lockedGroup: group,
        ),
      );

      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.pumpAndSettle();
      // 'a-user' (self) starts checked by default — only the other two need
      // tapping in.
      for (final id in ['b-user', 'c-user']) {
        await tester.ensureVisible(find.byKey(Key('split-participant-$id')));
        await tester.tap(find.byKey(Key('split-participant-$id')));
      }
      await tester.pumpAndSettle();

      // 'a-user' is self, so it's shown as "You" (design.md — the caller's
      // own display name is never used for this purpose), not its raw
      // displayName 'A'.
      expect(
        find.text(_loc.splitEqualShareRow(_loc.splitYouLabel, '34')),
        findsOneWidget,
      );
      expect(find.text(_loc.splitEqualShareRow('B', '33')), findsOneWidget);
      expect(find.text(_loc.splitEqualShareRow('C', '33')), findsOneWidget);
    });
  });

  group('SplitExpenseSheet — exact split', () {
    testWidgets('shows how much is left to assign', (tester) async {
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      // The category picker added a field above the mode toggle, pushing it
      // past the 600dp test viewport.
      await tester.ensureVisible(find.byKey(const Key('split-mode-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('split-mode-toggle')).hitTestable().first);
      // Select the exact segment specifically.
      await tester.tap(find.text(_loc.splitModeExact));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.pumpAndSettle();

      expect(
        find.text(_loc.splitExactRemaining('100')),
        findsOneWidget,
      );
    });
  });

  group('SplitExpenseSheet — exact split, over-assigned', () {
    testWidgets('assigning more than the amount says so, and Save is refused', (tester) async {
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
      await tester.tap(find.byKey(const Key('split-participant-f1')));
      await tester.pumpAndSettle();
      // The category picker added a field above the mode toggle, pushing it
      // past the 600dp test viewport — a `tap` there silently misses.
      await tester.ensureVisible(find.text(_loc.splitModeExact));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_loc.splitModeExact));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('split-exact-field-$_self')), '40');
      await tester.enterText(find.byKey(const Key('split-exact-field-f1')), '80');
      await tester.pumpAndSettle();

      // Not "還差 -20" / "Remaining to assign: -20", which reads as the exact
      // opposite of what happened.
      expect(find.text(_loc.splitExactOverAssigned('20')), findsOneWidget);
      expect(find.text(_loc.splitExactRemaining('-20')), findsNothing);
      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNull);
      expect(find.text(_loc.splitExactMustSumToAmount), findsOneWidget);
    });

    testWidgets('shares that add up exactly say so, and Save is offered', (tester) async {
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
      await tester.tap(find.byKey(const Key('split-participant-f1')));
      await tester.pumpAndSettle();
      // The category picker added a field above the mode toggle, pushing it
      // past the 600dp test viewport — a `tap` there silently misses.
      await tester.ensureVisible(find.text(_loc.splitModeExact));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_loc.splitModeExact));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('split-exact-field-$_self')), '40');
      await tester.enterText(find.byKey(const Key('split-exact-field-f1')), '60');
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitExactAssignedInFull), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('typing into a pre-filled exact field updates the running total', (tester) async {
      final repo = FakeSplitRepository();
      const editing = SplitExpense(
        id: 'e1',
        groupId: null,
        payerUserId: _self,
        payerDisplayName: 'Self',
        createdByUserId: _self,
        amount: 100,
        currency: 'TWD',
        description: 'Lunch',
        day: '2026-08-02',
        splitMode: 'exact',
        shares: [
          SplitShare(userId: _self, displayName: 'Self', amount: 50),
          SplitShare(userId: 'f1', displayName: 'Friend One', amount: 50),
        ],
        createdAt: '2026-08-02T00:00:00.000Z',
        updatedAt: '2026-08-02T00:00:00.000Z',
      );

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          editing: editing,
        ),
      );

      expect(find.text(_loc.splitExactAssignedInFull), findsOneWidget);

      await tester.enterText(find.byKey(const Key('split-exact-field-$_self')), '10');
      await tester.pumpAndSettle();

      // Frozen at "assigned in full" would mean the pre-filled controllers
      // never got the rebuild listener.
      expect(find.text(_loc.splitExactRemaining('40')), findsOneWidget);
    });
  });

  group('SplitExpenseSheet — every disabled Save states its reason', () {
    Future<void> pumpDefaultSheet(WidgetTester tester) => _pumpSheet(
      tester,
      sheet: SplitExpenseSheet(
        onAddFriend: () {},
        writer: _controller(FakeSplitRepository()),
        idToken: () async => 'tok',
        selfUserId: _self,
        today: '2026-08-02',
        friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
      ),
    );

    testWidgets('a blank description', (tester) async {
      await pumpDefaultSheet(tester);

      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.tap(find.byKey(const Key('split-participant-f1')));
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitDescriptionRequired), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('no participants at all', (tester) async {
      await pumpDefaultSheet(tester);

      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
      await tester.tap(find.byKey(const Key('split-participant-$_self')));
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitParticipantsRequired), findsOneWidget);
    });

    testWidgets('a blank amount', (tester) async {
      await pumpDefaultSheet(tester);

      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitAmountRequired), findsOneWidget);
    });

    testWidgets('a split of one person — what the backend calls split_too_small', (tester) async {
      await pumpDefaultSheet(tester);

      // The sheet's own default state: self is payer and the only participant.
      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitTooFewPeople), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNull);
      // Refused locally: nothing was sent.
      expect(find.byKey(const Key('split-save-button')), findsOneWidget);
    });

    testWidgets('an equal split whose amount is below the participant count', (tester) async {
      await pumpDefaultSheet(tester);

      await tester.enterText(find.byKey(const Key('split-amount-field')), '1');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
      await tester.tap(find.byKey(const Key('split-participant-f1')));
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitAmountBelowParticipants(2)), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNull);
    });
  });

  group('SplitExpenseSheet — nobody to split with', () {
    testWidgets('a caller with no friends and no groups is told so, and offered the way out', (
      tester,
    ) async {
      // The split tab's empty-state CTA lands a first-time user here. The
      // participant list holds only them, so "add someone besides the payer"
      // is an instruction they cannot carry out inside this sheet — the
      // prerequisite is a friend, on another page.
      final repo = FakeSplitRepository();
      var addFriendTaps = 0;

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () => addFriendTaps++,
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('split-amount-field')), '900');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Dinner');
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitNoFriendsYet), findsOneWidget);
      expect(find.text(_loc.splitTooFewPeople), findsNothing);
      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNull);

      await tester.ensureVisible(find.byKey(const Key('split-add-friend-action')));
      await tester.tap(find.byKey(const Key('split-add-friend-action')));
      await tester.pumpAndSettle();

      expect(addFriendTaps, 1);
    });

    testWidgets('a caller with a group but no friends is not sent to the friends page', (
      tester,
    ) async {
      // The next step for them is the group selector in this very sheet.
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          groups: const [
            SplitGroup(
              id: 'g1',
              name: 'Trip',
              createdByUserId: _self,
              archivedAt: null,
              members: [
                GroupMember(
                  groupId: 'g1',
                  userId: _self,
                  displayName: 'Self',
                  joinedAt: '2026-01-01T00:00:00Z',
                ),
              ],
            ),
          ],
        ),
      );

      expect(find.text(_loc.splitNoFriendsYet), findsNothing);
      expect(find.byKey(const Key('split-add-friend-action')), findsNothing);
    });

    testWidgets('an archived group is not a next step, and is not offered', (tester) async {
      // An archived group takes no new expenses, so counting it as somewhere
      // to go leaves a friendless user with no route to the friends page and
      // a form that completes only to be rejected by the server.
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          groups: const [
            SplitGroup(
              id: 'g1',
              name: 'Old trip',
              createdByUserId: _self,
              archivedAt: '2026-07-01T00:00:00Z',
              members: [
                GroupMember(
                  groupId: 'g1',
                  userId: _self,
                  displayName: 'Self',
                  joinedAt: '2026-01-01T00:00:00Z',
                ),
              ],
            ),
          ],
        ),
      );

      expect(find.text(_loc.splitNoFriendsYet), findsOneWidget);
      expect(find.byKey(const Key('split-add-friend-action')), findsOneWidget);
      expect(find.text('Old trip'), findsNothing);
    });
  });

  group('SplitExpenseSheet — amount limit', () {
    testWidgets('an amount above the backend maximum blocks save', (tester) async {
      final repo = FakeSplitRepository();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          // Someone to split with, so the amount really is the first thing
          // blocking Save.
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      await tester.enterText(find.byKey(const Key('split-amount-field')), '99999999999');
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitAmountTooLarge), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNull);
    });
  });

  group('SplitExpenseSheet — save/failure', () {
    testWidgets('a failed submission keeps every typed field', (tester) async {
      final repo = FakeSplitRepository()..failNext = const NotFriends();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch with Friend');
      // A split needs a second person (the backend's own rule) — without one
      // Save stays disabled and no request is ever sent.
      await tester.tap(find.byKey(const Key('split-participant-f1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('split-save-button')));
      await tester.tap(find.byKey(const Key('split-save-button')));
      await tester.pumpAndSettle();

      expect(find.text(_loc.splitErrorNotFriends), findsOneWidget);
      final amountField = tester.widget<TextField>(find.byKey(const Key('split-amount-field')));
      expect(amountField.controller!.text, '100');
      expect(find.text('Lunch with Friend'), findsOneWidget);
    });

    testWidgets('submitting is disabled while a save is in flight', (tester) async {
      final repo = FakeSplitRepository()..expenseToReturn = _sampleExpense();

      await _pumpSheet(
        tester,
        sheet: SplitExpenseSheet(
          onAddFriend: () {},
          writer: _controller(repo),
          idToken: () async => 'tok',
          selfUserId: _self,
          today: '2026-08-02',
          friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
        ),
      );

      await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
      await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
      await tester.tap(find.byKey(const Key('split-participant-f1')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('split-save-button')));
      await tester.tap(find.byKey(const Key('split-save-button')));
      // Immediately after the tap, before the fake repo's future resolves.
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(find.byKey(const Key('split-save-button')));
      expect(saveButton.onPressed, isNull);
      await tester.pumpAndSettle();
    });
  });
}
