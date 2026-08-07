import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/finance/domain/finance_money.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/settlement.dart';
import 'package:life_os/contexts/split/domain/split_activity.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/domain/split_share.dart';
import 'package:life_os/contexts/split/presentation/split_activity_controller.dart';
import 'package:life_os/contexts/split/presentation/split_controller.dart';
import 'package:life_os/contexts/split/presentation/split_tab.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

import '../../../support/l10n_test_app.dart';
import '../support/fake_split_repository.dart';
import '../support/split_presentation_fakes.dart';

SplitController _controller() {
  final repo = FakeSplitRepository();
  final profileRepo = FakeProfileRepository();
  final socialRepo = FakeSocialRepositoryForSplit();
  return SplitController(
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
}

SplitExpense _expense({
  required String id,
  required String createdByUserId,
  required String payerUserId,
  String? payerDisplayName = 'Payer',
  List<SplitShare> shares = const [],
}) => SplitExpense(
  id: id,
  groupId: null,
  payerUserId: payerUserId,
  payerDisplayName: payerDisplayName,
  createdByUserId: createdByUserId,
  amount: 900,
  currency: 'TWD',
  description: 'Dinner',
  day: '2026-08-02',
  splitMode: 'equal',
  shares: shares,
  createdAt: '2026-08-02T00:00:00.000Z',
  updatedAt: '2026-08-02T00:00:00.000Z',
);

Widget _wrap(SplitTab tab) => l10nTestApp(home: Scaffold(body: tab));

SplitActivity _activity(String id) => SplitActivity(
  id: id,
  type: SplitActivityType.expenseCreated,
  actorUserId: 'u-amy',
  actorDisplayName: 'Amy',
  groupId: null,
  groupName: null,
  subjectId: 'e1',
  counterpartUserId: null,
  counterpartDisplayName: null,
  amount: 900,
  previousAmount: null,
  actorIsPayer: null,
  currency: 'TWD',
  description: 'Dinner',
  createdAt: '2026-08-01T10:30:00.000Z',
);

/// A repayment **made to the reader** ('self-1'): Amy is the actor and the
/// payer, the reader is the counterpart. The row this renders is the one that
/// can be wrong about *who* without being wrong about the direction.
SplitActivity _repaymentToReader(String id) => SplitActivity(
  id: id,
  type: SplitActivityType.settlementCreated,
  actorUserId: 'u-amy',
  actorDisplayName: 'Amy',
  groupId: null,
  groupName: null,
  subjectId: 's1',
  counterpartUserId: 'self-1',
  // The reader's own display name — what the row falls back to naming them
  // when it does not know they are the reader.
  counterpartDisplayName: 'Me',
  amount: 900,
  previousAmount: null,
  actorIsPayer: true,
  currency: 'TWD',
  description: null,
  createdAt: '2026-08-01T10:30:00.000Z',
);

SplitTab _tab(SplitController controller) => SplitTab(
  onAddFriend: () {},
  controller: controller,
  activityController: testSplitActivityController(),
  onRetry: () {},
  onRecordExpense: () {},
  onOpenGroup: (_) {},
  onCreateGroup: () {},
  onEditExpense: (_) {},
  onSettleUp: ({
    required otherUserId,
    required otherDisplayName,
    required balanceAmount,
    required currency,
  }) {},
  onDeleteSettlement: (_) {},
  onSignInAgain: () {},
);

void main() {
  group('SplitTab — repayment schedules', () {
    testWidgets('two schedules with one person stay two lines', (tester) async {
      // The server returns them per expense precisely because merging them
      // produced a row belonging to neither (backend #84). Reading only the
      // first, or summing the periods, would put that bug back on this side
      // of the wire.
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..balances = const [
          Balance(
            userId: 'u2',
            displayName: 'Bo',
            balances: [
              CurrencyBalance(
                currency: 'TWD',
                amount: 11400,
                schedules: [
                  BalanceSchedule(expenseId: 'e1', nextPeriod: 3, totalPeriods: 12, periodAmount: 500),
                  BalanceSchedule(expenseId: 'e2', nextPeriod: 1, totalPeriods: 6, periodAmount: 900),
                ],
              ),
            ],
          ),
        ];

      await tester.pumpWidget(_wrap(_tab(controller)));

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(
        tester.widget<Text>(find.byKey(const Key('split-owed-to-me-schedule-0-0'))).data,
        loc.splitBalanceSchedule(3, 12, formatMinorUnitsForDisplay(500, 'TWD')),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('split-owed-to-me-schedule-0-1'))).data,
        loc.splitBalanceSchedule(1, 6, formatMinorUnitsForDisplay(900, 'TWD')),
      );
      // The balance itself is the whole debt, not the periods already due.
      expect(find.textContaining(formatMinorUnitsForDisplay(11400, 'TWD')), findsOneWidget);
    });

    testWidgets('a balance with no schedule shows no schedule line', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..balances = const [
          Balance(
            userId: 'u2',
            displayName: 'Bo',
            balances: [CurrencyBalance(currency: 'TWD', amount: 500)],
          ),
        ];

      await tester.pumpWidget(_wrap(_tab(controller)));

      expect(find.byKey(const Key('split-owed-to-me-schedule-0-0')), findsNothing);
    });
  });

  group('SplitTab', () {
    testWidgets('splits balances into owed-to-me / owed-by-me, and keeps currencies apart', (
      tester,
    ) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..balances = const [
          Balance(
            userId: 'u2',
            displayName: 'Bo',
            balances: [
              CurrencyBalance(currency: 'TWD', amount: 500),
              CurrencyBalance(currency: 'USD', amount: -200),
            ],
          ),
        ];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.splitSectionOwedToMe), findsOneWidget);
      expect(find.text(loc.splitSectionOwedByMe), findsOneWidget);
      expect(find.textContaining('Bo owes you'), findsOneWidget);
      expect(find.textContaining('You owe Bo'), findsOneWidget);

      // Tier 2 (unify-empty-states): balances are on screen, so the tab is
      // not empty — its Groups *section* is, and says so in one muted line
      // rather than a page-sized guide. This site had no test at all before.
      //
      // The header is what earns the note its tier (design D1b): the "Groups"
      // heading and its New group action are rendered *outside* the
      // isEmpty branch, so the region is still named and still fillable with
      // the note gone. Move the heading inside the non-empty branch and the
      // section would need a full guide instead — hence this assertion.
      expect(find.text(loc.splitSectionGroups), findsOneWidget);
      expect(find.byKey(const Key('split-add-group-button')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('split-no-groups')),
          matching: find.byType(EmptyStateNote),
        ),
        findsOneWidget,
      );
      expect(find.byType(EmptyStateGuide), findsNothing);
    });

    testWidgets('empty state shows the record CTA, not a blank tab', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1';
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () => tapped = true,
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('split-empty-title')), findsOneWidget);

      // Tier 1 (unify-empty-states): the shared full guide, keyed on its own
      // column, carrying the icon that says *which* kind of empty this is.
      expect(
        find.ancestor(
          of: find.byKey(const Key('split-empty-title')),
          matching: find.byType(EmptyStateGuide),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EmptyStateGuide),
          matching: find.byIcon(Icons.call_split),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('split-empty-cta')));
      expect(tapped, isTrue);
    });

    testWidgets('the empty tab points a friendless user at the friends page', (tester) async {
      // Otherwise the empty state's own CTA is a dead end: the record sheet
      // it opens holds only 「你」, and its Save asks for a second person
      // this user has no way to produce from inside finance.
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..friends = const [];
      var addFriendTaps = 0;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () => addFriendTaps++,
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.splitNoFriendsYet), findsOneWidget);
      await tester.tap(find.byKey(const Key('split-empty-add-friend')));
      expect(addFriendTaps, 1);

      // …and it is the *primary* action while it is the only one that leads
      // anywhere: the record CTA opens a sheet whose Save is unreachable
      // without a second person, so it drops to secondary weight rather than
      // competing with the action that unblocks it.
      expect(
        find.descendant(
          of: find.byType(EmptyStateGuide),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
        reason: 'the guide offers more than one equal-weight primary action',
      );
      expect(
        tester.widget(find.byKey(const Key('split-empty-add-friend'))),
        isA<FilledButton>(),
      );
      expect(
        tester.widget(find.byKey(const Key('split-empty-cta'))),
        isA<OutlinedButton>(),
      );
    });

    testWidgets('the empty tab says nothing about friends to a user who has some', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..friends = const [Friend(userId: 'f1', displayName: 'Friend One')];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('split-empty-add-friend')), findsNothing);

      // With friends, recording *is* the first move — so the CTA takes the
      // primary weight back, and it is still the only primary.
      expect(
        tester.widget(find.byKey(const Key('split-empty-cta'))),
        isA<FilledButton>(),
      );
      expect(
        find.descendant(
          of: find.byType(EmptyStateGuide),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
        reason: 'the guide offers more than one equal-weight primary action',
      );
    });

    testWidgets('error state shows a retry action', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.error
        ..error = SplitError.fetchFailed;
      var retried = false;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () => retried = true,
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('split-load-error')), findsOneWidget);
      await tester.tap(find.byKey(const Key('split-retry')));
      expect(retried, isTrue);
    });

    testWidgets('profile-fetch failure shows its own distinct message', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.error
        ..error = SplitError.profileFailed;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.splitProfileFailedMessage), findsOneWidget);
    });

    testWidgets('needsReauth shows the existing reauth exit', (tester) async {
      final controller = _controller()..status = SplitStatus.needsReauth;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
    });

    testWidgets('tapping a group row opens it', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..groups = const [
          SplitGroup(id: 'g1', name: 'Trip', createdByUserId: 'self-1', archivedAt: null),
        ];
      String? opened;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (id) => opened = id,
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('split-group-row-g1')));
      expect(opened, 'g1');
    });

    testWidgets('an expense row names who paid and what the viewer own share is', (tester) async {
      // The whole point of the payer name riding on the expense: a
      // participant who is neither creator nor payer gets no edit sheet, so
      // the row is the only place these two facts can reach them.
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..expenses = [
          _expense(
            id: 'e1',
            createdByUserId: 'other',
            payerUserId: 'other',
            payerDisplayName: 'Dana Paidforit',
            shares: const [
              SplitShare(userId: 'self-1', displayName: 'Self', amount: 300),
              SplitShare(userId: 'other', displayName: 'Dana Paidforit', amount: 600),
            ],
          ),
        ];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.textContaining('Dana Paidforit'), findsOneWidget);
      expect(find.text(loc.splitYourShare('300')), findsOneWidget);
      // …and no edit action, since the viewer is neither creator nor payer.
      expect(find.byKey(const Key('split-expense-edit-e1')), findsNothing);
    });

    testWidgets('an expense whose payer name the server did not send falls back to the placeholder', (
      tester,
    ) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..expenses = [
          _expense(
            id: 'e1',
            createdByUserId: 'ghost-uuid-123',
            payerUserId: 'ghost-uuid-123',
            payerDisplayName: null,
          ),
        ];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.textContaining(loc.splitUnknownMember), findsOneWidget);
      expect(find.textContaining('ghost-uuid-123'), findsNothing);
    });

    testWidgets('nothing owed in either direction says so instead of silently showing nothing', (
      tester,
    ) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..groups = const [
          SplitGroup(id: 'g1', name: 'Trip', createdByUserId: 'self-1', archivedAt: null),
        ];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('split-all-settled')), findsOneWidget);

      // Tier 2 (unify-empty-states): with balances on screen the tab is not
      // empty — its Groups and Recent-activity *sections* are, and each says
      // so in one muted line rather than a page-sized guide. Neither site
      // had any test before this change.
      // (This scenario has a group, so only the activity section is empty.)
      expect(
        find.ancestor(
          of: find.byKey(const Key('split-no-activity')),
          matching: find.byType(EmptyStateNote),
        ),
        findsOneWidget,
      );
      expect(find.byType(EmptyStateGuide), findsNothing);
    });

    testWidgets('the empty tab also offers creating a group, not only recording an expense', (
      tester,
    ) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1';
      var createGroupTapped = false;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () => createGroupTapped = true,
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('split-empty-create-group')));
      expect(createGroupTapped, isTrue);
    });

    testWidgets('an edit action is offered only to the expense creator or payer', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..expenses = [
          _expense(id: 'e-mine', createdByUserId: 'self-1', payerUserId: 'other'),
          _expense(id: 'e-not-mine', createdByUserId: 'other', payerUserId: 'other2'),
        ];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('split-expense-edit-e-mine')), findsOneWidget);
      expect(find.byKey(const Key('split-expense-edit-e-not-mine')), findsNothing);
    });
  });

  group('SplitTab settle-up wiring (task 5) — the signed amount and counterpart travel intact', () {
    testWidgets('a row I am owed on carries the positive signed amount and the counterpart id', (
      tester,
    ) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..balances = const [
          Balance(
            userId: 'u2',
            displayName: 'Bo',
            balances: [CurrencyBalance(currency: 'TWD', amount: 500)],
          ),
        ];
      String? gotOtherUserId;
      String? gotOtherDisplayName;
      int? gotBalanceAmount;
      String? gotCurrency;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {
              gotOtherUserId = otherUserId;
              gotOtherDisplayName = otherDisplayName;
              gotBalanceAmount = balanceAmount;
              gotCurrency = currency;
            },
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('split-owed-to-me-settle-0')));

      expect(gotOtherUserId, 'u2');
      expect(gotOtherDisplayName, 'Bo');
      // Positive, not pre-negated for display — the direction the sheet
      // needs to tell "they owe me" from "I owe them" (design.md task 5).
      expect(gotBalanceAmount, 500);
      expect(gotCurrency, 'TWD');
    });

    testWidgets(
      'a row I owe carries the *negative* signed amount — an earlier draft negated it away here',
      (tester) async {
        // The regression this guards: `split_tab.dart` used to negate
        // owed-by-me before building the row, so its value was always
        // positive by the time anything downstream saw it — which made the
        // settle sheet unable to tell direction at all.
        final controller = _controller()
          ..status = SplitStatus.loaded
          ..selfUserId = 'self-1'
          ..balances = const [
            Balance(
              userId: 'u2',
              displayName: 'Bo',
              balances: [CurrencyBalance(currency: 'TWD', amount: -450)],
            ),
          ];
        int? gotBalanceAmount;

        await tester.pumpWidget(
          _wrap(
            SplitTab(
              onAddFriend: () {},
              controller: controller,
              activityController: testSplitActivityController(),
              onRetry: () {},
              onRecordExpense: () {},
              onOpenGroup: (_) {},
              onCreateGroup: () {},
              onEditExpense: (_) {},
              onSettleUp: ({
                required otherUserId,
                required otherDisplayName,
                required balanceAmount,
                required currency,
              }) {
                gotBalanceAmount = balanceAmount;
              },
              onDeleteSettlement: (_) {},
              onSignInAgain: () {},
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('split-owed-by-me-settle-0')));

        expect(gotBalanceAmount, -450);
      },
    );

    testWidgets('a balance spanning two currencies offers one settle entry per currency', (
      tester,
    ) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..balances = const [
          Balance(
            userId: 'u2',
            displayName: 'Bo',
            balances: [
              CurrencyBalance(currency: 'TWD', amount: 500),
              CurrencyBalance(currency: 'USD', amount: 20),
            ],
          ),
        ];
      final gotCurrencies = <String>[];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) => gotCurrencies.add(currency),
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('split-owed-to-me-settle-0')), findsOneWidget);
      expect(find.byKey(const Key('split-owed-to-me-settle-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('split-owed-to-me-settle-0')));
      await tester.tap(find.byKey(const Key('split-owed-to-me-settle-1')));
      expect(gotCurrencies.toSet(), {'TWD', 'USD'});
    });
  });

  group('SplitTab repayments in the activity list (task 5.1/5.2)', () {
    Settlement settlement({
      String id = 's1',
      String fromUserId = 'other',
      String? fromDisplayName = 'Bo',
      String toUserId = 'self-1',
      String? toDisplayName = 'Self',
      String createdByUserId = 'other',
      String day = '2026-08-03',
    }) => Settlement(
      id: id,
      groupId: null,
      fromUserId: fromUserId,
      fromDisplayName: fromDisplayName,
      toUserId: toUserId,
      toDisplayName: toDisplayName,
      amount: 300,
      currency: 'TWD',
      day: day,
      note: null,
      createdByUserId: createdByUserId,
    );

    testWidgets('a repayment is labelled as one in words, distinct from an expense row', (
      tester,
    ) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..settlements = [settlement()];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.byKey(const Key('split-settlement-row-s1')), findsOneWidget);
      expect(find.text(loc.splitSettlementRow('Bo', 'Self')), findsOneWidget);
    });

    testWidgets('delete is offered to the creator', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..settlements = [settlement(createdByUserId: 'self-1', fromUserId: 'other')];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('split-settlement-delete-s1')), findsOneWidget);
    });

    testWidgets('delete is offered to the payer', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..settlements = [settlement(createdByUserId: 'other', fromUserId: 'self-1')];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('split-settlement-delete-s1')), findsOneWidget);
    });

    testWidgets('delete is not offered to a mere payee (neither creator nor payer)', (
      tester,
    ) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..settlements = [settlement(createdByUserId: 'other', fromUserId: 'other', toUserId: 'self-1')];

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (_) {},
            onSignInAgain: () {},
          ),
        ),
      );

      // The row itself must be on screen, otherwise "no delete here" would
      // hold simply because the repayment was never rendered.
      expect(find.byKey(const Key('split-settlement-row-s1')), findsOneWidget);
      expect(find.byKey(const Key('split-settlement-delete-s1')), findsNothing);
    });

    testWidgets('tapping delete invokes onDeleteSettlement with the settlement', (tester) async {
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1'
        ..settlements = [settlement(createdByUserId: 'self-1')];
      Settlement? deleted;

      await tester.pumpWidget(
        _wrap(
          SplitTab(
            onAddFriend: () {},
            controller: controller,
            activityController: testSplitActivityController(),
            onRetry: () {},
            onRecordExpense: () {},
            onOpenGroup: (_) {},
            onCreateGroup: () {},
            onEditExpense: (_) {},
            onSettleUp: ({
              required otherUserId,
              required otherDisplayName,
              required balanceAmount,
              required currency,
            }) {},
            onDeleteSettlement: (s) => deleted = s,
            onSignInAgain: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('split-settlement-delete-s1')));
      expect(deleted?.id, 's1');
    });
  });

  group('SplitTab — the 變更紀錄 section (add-split-activity-ui)', () {
    SplitTab tab(SplitController controller, SplitActivityController activity) => SplitTab(
      onAddFriend: () {},
      controller: controller,
      activityController: activity,
      onRetry: () {},
      onRecordExpense: () {},
      onOpenGroup: (_) {},
      onCreateGroup: () {},
      onEditExpense: (_) {},
      onSettleUp: ({
        required otherUserId,
        required otherDisplayName,
        required balanceAmount,
        required currency,
      }) {},
      onDeleteSettlement: (_) {},
      onSignInAgain: () {},
    );

    testWidgets('opens on the overview and fetches no change log until asked', (tester) async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          SplitActivityPage(entries: [_activity('a1')], nextCursor: null),
        ];
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1';

      await tester.pumpWidget(_wrap(tab(controller, testSplitActivityController(repo))));
      await tester.pump();

      expect(find.byKey(const Key('split-section-selector')), findsOneWidget);
      expect(find.byKey(const Key('split-activity-list')), findsNothing);
      expect(repo.activityCalls, isEmpty);
    });

    testWidgets('selecting it loads and shows the change log', (tester) async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          SplitActivityPage(entries: [_activity('a1')], nextCursor: null),
        ];
      final controller = _controller()
        ..status = SplitStatus.loaded
        ..selfUserId = 'self-1';

      await tester.pumpWidget(_wrap(tab(controller, testSplitActivityController(repo))));
      await tester.tap(find.text(lookupAppLocalizations(const Locale('en')).splitSectionChangeLog));
      await tester.pump();
      await tester.pump();

      expect(repo.activityCalls, hasLength(1));
      expect(find.byKey(const Key('split-activity-row-a1')), findsOneWidget);
    });

    testWidgets('a failed overview does not take the change log down with it', (tester) async {
      // The section switch sits *above* the overview's loading/error
      // branches: they are two independent sets of data, and putting the
      // switch inside the overview's error branch would make one failure
      // hide the other section entirely.
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          SplitActivityPage(entries: [_activity('a1')], nextCursor: null),
        ];
      final controller = _controller()
        ..status = SplitStatus.error
        ..error = SplitError.fetchFailed;

      await tester.pumpWidget(_wrap(tab(controller, testSplitActivityController(repo))));
      expect(find.byKey(const Key('split-load-error')), findsOneWidget);

      await tester.tap(find.text(lookupAppLocalizations(const Locale('en')).splitSectionChangeLog));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('split-activity-row-a1')), findsOneWidget);
      expect(find.byKey(const Key('split-load-error')), findsNothing);
    });

    // The change log resolves the reader **itself** (its own `/api/me`), so
    // its "you" does not depend on the overview's profile load. Wiring it to
    // `SplitController.selfUserId` couples the two sections again exactly
    // where it is invisible: the direction stays right and only the person is
    // wrong, so a repayment made *to* the reader reads "Amy paid Me" — their
    // own display name, in the third person — for as long as the overview has
    // not loaded, and forever after `SplitError.profileFailed`.
    for (final (name, overview) in [
      ('is still loading', SplitStatus.loading),
      ('failed to resolve the profile', SplitStatus.error),
    ]) {
      testWidgets('a repayment to the reader says "you" while the overview $name', (tester) async {
        final repo = FakeSplitRepository()
          ..activityPagesToReturn = [
            SplitActivityPage(entries: [_repaymentToReader('a1')], nextCursor: null),
          ];
        // The overview never resolves a reader: `selfUserId` stays null,
        // which is what the change log used to borrow.
        final controller = _controller()
          ..status = overview
          ..error = overview == SplitStatus.error ? SplitError.profileFailed : null;
        expect(controller.selfUserId, isNull);

        await tester.pumpWidget(_wrap(tab(controller, testSplitActivityController(repo))));
        final loc = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(loc.splitSectionChangeLog));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.text(loc.splitActivityRepaymentPaidYou('Amy')), findsOneWidget);
        expect(find.text(loc.splitActivityRepaymentBetween('Amy', 'Me')), findsNothing);
      });
    }
  });
}
