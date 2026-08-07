import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/domain/installment_plan.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/split/application/activity_use_cases.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/settlement.dart';
import 'package:life_os/contexts/split/domain/split_activity.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/presentation/split_tab_dependencies.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/sheet_finders.dart';
import '../../split/support/fake_split_repository.dart';
import '../../split/support/split_presentation_fakes.dart';
import '../../../support/month_label.dart';
import '../finance_test_support.dart';

SplitTabDependencies _splitDeps(
  FakeSplitRepository repo, {
  Future<void> Function(BuildContext, String)? onOpenGroup,
  void Function(BuildContext)? onAddFriend,
  List<Friend> friends = const [],
  GetProfile? getProfile,
}) => SplitTabDependencies(
  getBalances: GetBalances(repo),
  listGroups: ListGroups(repo),
  listExpenses: ListExpenses(repo),
  createExpense: CreateExpense(repo),
  updateExpense: UpdateExpense(repo),
  deleteExpense: DeleteExpense(repo),
  createGroup: CreateGroup(repo),
  listFriends: ListFriends(FakeSocialRepositoryForSplit()..friends = friends),
  getProfile:
      getProfile ?? GetProfile(FakeProfileRepository()..profileToReturn = testProfile()),
  listSettlements: ListSettlements(repo),
  createSettlement: CreateSettlement(repo),
  deleteSettlement: DeleteSettlement(repo),
  listActivity: ListActivity(repo),
  onOpenGroup: onOpenGroup ?? (_, __) async {},
  onAddFriend: onAddFriend ?? (_) {},
);

class _FakeAuthRepository implements AuthRepository {
  /// What the next [idToken] call resolves to. Mutable so a test can simulate
  /// Firebase renewing the token while the scaffold stays mounted.
  String token;

  _FakeAuthRepository({this.token = 'tok'});

  @override
  Future<String?> idToken() async => token;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}
}

void main() {
  group('FinanceScaffold', () {
    // `FinanceScaffold` is one of the long-mounted shells issue #106 is about,
    // and it used to fetch one token at mount and feed it to fifteen read/write
    // sites. Asserts on the token the repository RECEIVED, not on the provider
    // having been called.
    testWidgets(
      'a month switch after a token renewal carries the new token',
      (tester) async {
        final repo = FakeFinanceRepository();
        final auth = _FakeAuthRepository(token: 'token-1');

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: auth,
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(FakeSplitRepository()),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(repo.summaryTokens, ['token-1']);

        // Firebase renewed the token while the scaffold stayed mounted.
        auth.token = 'token-2';

        await tester.tap(find.byKey(const Key('finance-month-previous')));
        await tester.pumpAndSettle();

        expect(repo.summaryTokens, ['token-1', 'token-2']);
      },
    );

    testWidgets('shows both bottom-nav destinations and switches tabs', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();
      final controller = testFinanceController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('finance-empty-title')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('finance-transactions-empty')), findsOneWidget);
    });

    testWidgets('the FAB opens the record sheet', (tester) async {
      final repo = FakeFinanceRepository();
      final controller = testFinanceController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('amount-field')), findsOneWidget);
      expect(find.byKey(const Key('save-transaction-button')), findsOneWidget);
    });

    testWidgets('both FABs stay reachable at 320dp, textScale 2.0', (
      tester,
    ) async {
      // The two sit stacked in a Column above the navigation bar, and the
      // narrow-screen sweep only renders the two new screens standalone — it
      // never renders this stack. A FAB pushed off the top, under the bar, or
      // off-screen raises no layout error; it just cannot be pressed, and
      // `tap` on a missed hit test only prints a warning.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      useTextScaleFactor(tester, 2.0);

      final repo = FakeFinanceRepository();
      final controller = testFinanceController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hit-testing the centre, not comparing rects: a widget laid out past
      // the viewport still reports its logical rect, so `getRect` alone
      // passes on a FAB that is nowhere near the screen. What matters is
      // whether a tap at that point reaches it.
      for (final key in ['finance-fab', 'finance-installment-fab']) {
        final finder = find.byKey(Key(key));
        final centre = tester.getCenter(finder);
        final hits = tester.hitTestOnBinding(centre).path.any(
          (entry) => entry.target == tester.renderObject(finder),
        );
        expect(
          hits,
          isTrue,
          reason: '$key 在 320dp / textScale 2.0 下按不到(中心點 $centre)',
        );
      }

      await tester.tap(find.byKey(const Key('finance-installment-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('installment-mode-total')), findsOneWidget);
    });

    testWidgets('the second FAB opens the recurring-charge form', (tester) async {
      // Without this the whole feature is unreachable: the sheet and the plan
      // screen both existed, fully tested in isolation, with zero call sites
      // in the app. Every one of their own tests stayed green.
      final repo = FakeFinanceRepository();
      final controller = testFinanceController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-installment-fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('installment-mode-total')), findsOneWidget);
      // Not the ordinary record sheet — the two FABs sit together and wiring
      // both to `_openSheet()` would leave this passing on the wrong form.
      expect(find.byKey(const Key('save-transaction-button')), findsNothing);
    });

    testWidgets('a split repayment period says which period it is, with no plan to go to', (tester) async {
      // The shape that has no plan at all: a friend repaying the caller in
      // monthly instalments. `plan_id` is null and `installment_no` is not,
      // and the previous rule (`planId != null`) marked none of these — twelve
      // identical rows of 500 with nothing to tell them apart.
      final repo = FakeFinanceRepository()
        ..byMonth['2026-07'] = [
          const FinanceTransaction(
            id: 't-split-period',
            type: FinanceType.expense,
            amount: 500,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-15',
            splitExpenseId: 'split-1',
            installmentNo: 3,
          ),
        ];
      final controller = testFinanceController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(loc.financeTabTransactions));
      await tester.pumpAndSettle();

      // In the list, alongside the split mark — both, not one instead of the
      // other.
      expect(find.byKey(const Key('finance-transaction-installment-t-split-period')), findsOneWidget);
      expect(find.byKey(const Key('finance-transaction-mirror-t-split-period')), findsOneWidget);

      await tester.tap(find.byKey(const Key('finance-transaction-t-split-period')));
      await tester.pumpAndSettle();

      // "Period 3", never "period 3 of 12": there is no plan, so there is no
      // total, and inventing one would be a figure the server never gave.
      expect(
        tester.widget<Text>(find.byKey(const Key('finance-installment-info'))).data,
        loc.financeInstallmentPeriodOnly(3),
      );
      expect(find.byKey(const Key('finance-go-to-plan')), findsNothing);
    });

    testWidgets('go-to-plan really lands on the plan screen', (tester) async {
      // The button existed, correctly gated, wired to a callback nobody
      // passed — a dead end that every sheet test passed straight through
      // because they supply their own callback. This is the only place that
      // can tell "the control is there" from "the control does something".
      final repo = FakeFinanceRepository()
        ..byMonth['2026-07'] = [
          const FinanceTransaction(
            id: 't-inst',
            type: FinanceType.expense,
            amount: 5000,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-15',
            planId: 'plan-9',
            installmentNo: 3,
          ),
        ]
        ..plansById['plan-9'] = const InstallmentPlan(
          id: 'plan-9',
          mode: InstallmentMode.total,
          periods: 12,
          startDay: '2026-05-15',
          amount: 60000,
          currency: 'TWD',
          categoryId: 'cat-food',
        );
      final controller = testFinanceController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(loc.financeTabTransactions));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('finance-transaction-t-inst')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-go-to-plan')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('installment-settle-button')), findsOneWidget);
      // The sheet was popped first, not left stranded under the pushed screen.
      expect(find.byKey(const Key('finance-go-to-plan')), findsNothing);
    });

    testWidgets('the 淨值 tab loads its own month, independent of the ledger', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);
      final controller = testFinanceController(repo);
      final netWorthController = testNetWorthController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: netWorthController,
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The net worth tab is not loaded until it's actually opened.
      expect(netWorthController.selectedMonth, isEmpty);

      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      expect(netWorthController.selectedMonth, '2026-07');
      expect(find.byKey(const Key('networth-net-value')), findsOneWidget);
      expect(find.byKey(const Key('networth-month-label')), findsOneWidget);
      // The transaction FAB doesn't belong on the net worth tab.
      expect(find.byKey(const Key('finance-fab')), findsNothing);

      // Switching the net worth month leaves the ledger's month alone.
      await tester.tap(find.byKey(const Key('networth-month-previous')));
      await tester.pumpAndSettle();

      expect(netWorthController.selectedMonth, '2026-06');
      expect(controller.selectedMonth, '2026-07');
    });

    testWidgets('re-entering finance reloads the 淨值 tab, keeping its month', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);
      final netWorthController = testNetWorthController(repo);

      Widget scaffold() => l10nTestApp(
        home: FinanceScaffold(
          authRepository: _FakeAuthRepository(),
          controller: testFinanceController(repo),
          netWorthController: netWorthController,
          financeRepository: repo,
          split: _splitDeps(FakeSplitRepository()),
          clock: () => DateTime(2026, 7, 15),
        ),
      );

      await tester.pumpWidget(scaffold());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-month-previous')));
      await tester.pumpAndSettle();

      expect(netWorthController.selectedMonth, '2026-06');
      expect(repo.trendCalls.length, 2);

      // Leave finance entirely (the State is disposed), then come back. The
      // controller is an app-lifetime singleton, so without a per-State
      // "already loaded" flag the tab would never refetch.
      await tester.pumpWidget(l10nTestApp(home: const Scaffold(body: Text('away'))));
      await tester.pumpAndSettle();
      await tester.pumpWidget(scaffold());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      expect(repo.trendCalls.length, 3);
      // The month the user was last looking at is kept, not reset to today.
      expect(netWorthController.selectedMonth, '2026-06');
    });

    testWidgets('tapping an account row opens the value sheet', (tester) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: testFinanceController(repo),
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('account-row-acc-cash')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('snapshot-field')), findsOneWidget);
    });

    testWidgets('the manage button opens the account management sheet', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: testFinanceController(repo),
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('account-manage-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-add-name')), findsOneWidget);
    });

    group('sheets carry a drag handle, and it is what closes them', () {
      // Opened from the scaffold itself, not by pumping the sheet widget with a
      // local showModalBottomSheet — the bug lives in the scaffold's call sites,
      // so a test that supplies its own sheet route could never catch it.
      Future<void> pumpScaffold(WidgetTester tester, FakeFinanceRepository repo) async {
        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(FakeSplitRepository()),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('the record sheet', (tester) async {
        await pumpScaffold(tester, FakeFinanceRepository());

        await tester.tap(find.byKey(const Key('finance-fab')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('amount-field')), findsOneWidget);
        expectSheetHasDragHandle(tester);
      });

      testWidgets('the budget sheet', (tester) async {
        await pumpScaffold(tester, FakeFinanceRepository());

        await tester.tap(find.byKey(const Key('budget-edit-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('budget-sheet-save')), findsOneWidget);
        expectSheetHasDragHandle(tester);
      });

      testWidgets('the snapshot sheet', (tester) async {
        await pumpScaffold(
          tester,
          FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234),
        );

        await tester.tap(find.byKey(const Key('networth-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-row-acc-cash')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('snapshot-field')), findsOneWidget);
        expectSheetHasDragHandle(tester);
      });

      testWidgets('the account management sheet', (tester) async {
        await pumpScaffold(tester, FakeFinanceRepository());

        await tester.tap(find.byKey(const Key('networth-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-manage-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('account-add-name')), findsOneWidget);
        expectSheetHasDragHandle(tester);
      });

      /// Enough accounts that the management sheet's content is taller than the
      /// viewport — the state the user actually hit. On a phone (<= the M3
      /// sheet maxWidth of 640) the sheet then covers the screen edge to edge
      /// with no scrim left to tap, so a broken handle leaves it inescapable
      /// rather than merely degraded. (This test's 800px-wide viewport keeps
      /// side scrim; the vertical fill, which is what the drag exercises, is
      /// the same.)
      FakeFinanceRepository tallAccountsRepo() {
        return FakeFinanceRepository()
          ..accounts = [
            for (var i = 0; i < 14; i++)
              NetWorthAccount(
                id: 'acc-asset-$i',
                kind: NetWorthKind.asset,
                name: '資產 $i',
                sortOrder: i,
                archived: false,
              ),
            for (var i = 0; i < 6; i++)
              NetWorthAccount(
                id: 'acc-liab-$i',
                kind: NetWorthKind.liability,
                name: '負債 $i',
                sortOrder: i,
                archived: false,
              ),
          ];
      }

      Future<Finder> openTallAccountSheet(WidgetTester tester) async {
        await pumpScaffold(tester, tallAccountsRepo());
        await tester.tap(find.byKey(const Key('networth-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-manage-button')));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(find.byKey(const Key('account-add-name')), findsOneWidget);
        // Precondition for everything below: the sheet really does fill the
        // viewport, leaving no scrim to tap outside of.
        final sheetRect = tester.getRect(sheet);
        final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(sheetRect.top, lessThanOrEqualTo(0));
        expect(sheetRect.height, greaterThanOrEqualTo(viewport.height));
        return sheet;
      }

      testWidgets('pulling the handle down closes a viewport-filling sheet', (
        tester,
      ) async {
        final sheet = await openTallAccountSheet(tester);

        await tester.drag(dragHandleIn(tester, sheet), const Offset(0, 500));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byKey(const Key('account-add-name')), findsNothing);
        // Closed the sheet, not popped the whole finance route — the original
        // complaint was that the only way out took the user off the screen.
        expect(find.byType(FinanceScaffold), findsOneWidget);
        expect(find.byKey(const Key('networth-tab')), findsOneWidget);
        expect(find.byKey(const Key('account-manage-button')), findsOneWidget);
      });

      testWidgets('dragging the content, unlike the handle, never closes the sheet', (
        tester,
      ) async {
        final sheet = await openTallAccountSheet(tester);

        // Well below the 48px handle strip: the content's own scrollable, which
        // is exactly what swallowed the pull-down before the handle existed.
        final sheetRect = tester.getRect(sheet);
        await tester.dragFrom(
          Offset(sheetRect.center.dx, sheetRect.top + 300),
          const Offset(0, 500),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byKey(const Key('account-add-name')), findsOneWidget);
      });
    });

    group('the 分帳 tab (task 5.4)', () {
      // `split` was optional through part 2 of this change so `FinanceScaffold`
      // kept compiling before its DI existed (see `SplitTabDependencies`'
      // doc comment); the "is absent when not supplied" case that tested is
      // no longer expressible now that `split` is a required constructor
      // parameter (task 8.1) — an omission is a compile error, not a runtime
      // state to assert on.

      testWidgets('appears as the fourth destination, lazily loaded, with its own FAB', (
        tester,
      ) async {
        final repo = FakeFinanceRepository();
        final splitRepo = FakeSplitRepository();

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(splitRepo),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Not fetched until the tab is actually opened.
        expect(splitRepo.gotIdToken, isNull);

        expect(find.byKey(const Key('split-tab')), findsOneWidget);
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();

        expect(splitRepo.gotIdToken, 'tok');
        // The transaction FAB is gone; the split tab has its own.
        expect(find.byKey(const Key('finance-fab')), findsNothing);
        expect(find.byKey(const Key('split-fab')), findsOneWidget);
        // AppBar title indexes cleanly into the fourth slot — no RangeError.
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'popping a route mid tab-switch does not collide the two FABs as heroes',
        (tester) async {
          final repo = FakeFinanceRepository();
          final scaffold = FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: testFinanceController(repo),
            netWorthController: testNetWorthController(repo),
            financeRepository: repo,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          );

          await tester.pumpWidget(
            l10nRouterTestApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    key: const Key('open-finance'),
                    onPressed: () => context.push('/finance', extra: scaffold),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('open-finance')));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('split-tab')));
          // Deliberately *not* `pumpAndSettle`: switching to 分帳 cross-fades
          // the transaction FAB into the split FAB, and for those ~200ms both
          // are in the tree. Starting a route transition inside that window
          // is what makes two default-tagged heroes visible to the same
          // flight — settling first makes this test pass either way.
          await tester.pump(const Duration(milliseconds: 100));
          GoRouter.of(tester.element(find.byKey(const Key('split-tab')))).pop();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('the FAB opens the record-expense sheet', (tester) async {
        final repo = FakeFinanceRepository();
        final splitRepo = FakeSplitRepository();

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(splitRepo),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('split-fab')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('split-amount-field')), findsOneWidget);
        expect(find.byKey(const Key('split-save-button')), findsOneWidget);

        // The other of the two `SplitExpenseSheet` call sites. The group-detail
        // one has its own version of this; both are asserted because wiring
        // one and not the other is invisible until an edit made from the
        // unwired screen clears everybody's category.
        await tester.ensureVisible(find.byKey(const Key('split-category-field')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-category-field')));
        await tester.pumpAndSettle();
        expect(find.text('餐飲'), findsWidgets);
      });

      testWidgets('the friendless empty state leaves for the friends page, closing the sheet', (
        tester,
      ) async {
        // The one prerequisite for splitting that finance cannot create
        // itself. Both surfaces are wired to the same injected exit: the
        // empty state's own button, and the record sheet's blocked-Save
        // action once the user has already tapped through to it.
        final repo = FakeFinanceRepository();
        final splitRepo = FakeSplitRepository();
        var addFriendCalls = 0;

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(splitRepo, onAddFriend: (_) => addFriendCalls++),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('split-empty-add-friend')));
        await tester.pumpAndSettle();
        expect(addFriendCalls, 1);

        await tester.tap(find.byKey(const Key('split-fab')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('split-add-friend-action')));
        await tester.tap(find.byKey(const Key('split-add-friend-action')));
        await tester.pumpAndSettle();

        expect(addFriendCalls, 2);
        // Navigating out from under an open modal sheet would strand it on
        // top of the friends page.
        expect(find.byKey(const Key('split-amount-field')), findsNothing);
      });

      testWidgets('tapping a group row calls the injected onOpenGroup with the group id', (
        tester,
      ) async {
        final repo = FakeFinanceRepository();
        final splitRepo = FakeSplitRepository()
          ..groupsToReturn = const [
            SplitGroup(id: 'g1', name: 'Trip', createdByUserId: 'self-1', archivedAt: null),
          ];
        String? openedGroupId;

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(
                splitRepo,
                onOpenGroup: (context, groupId) async {
                  openedGroupId = groupId;
                },
              ),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('split-group-row-g1')));
        await tester.pumpAndSettle();

        expect(openedGroupId, 'g1');
      });

      testWidgets('a failed create-group says so instead of closing on nothing', (tester) async {
        final repo = FakeFinanceRepository();
        final splitRepo = FakeSplitRepository();

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(splitRepo),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();

        splitRepo.failNext = const SplitBadRequest('name is required');
        await tester.tap(find.byKey(const Key('split-empty-create-group')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('split-group-name-field')), 'Trip');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-create-group-confirm')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.splitErrorBadRequest('name is required')), findsOneWidget);
      });

      testWidgets(
        'returning from group detail reloads the split tab so an add/archive there is '
        'reflected (task 8.1b)',
        (tester) async {
          final repo = FakeFinanceRepository();
          final splitRepo = FakeSplitRepository()
            ..groupsToReturn = const [
              SplitGroup(id: 'g1', name: 'Trip', createdByUserId: 'self-1', archivedAt: null),
            ];
          // Stands in for the real `onOpenGroup` (a `context.push` that
          // completes only once the pushed screen is popped) — held open
          // until the test explicitly completes it, so the reload-on-return
          // assertion below can distinguish "navigated away" from "come
          // back".
          final returned = Completer<void>();

          await tester.pumpWidget(
            l10nTestApp(
              home: FinanceScaffold(
                authRepository: _FakeAuthRepository(),
                controller: testFinanceController(repo),
                netWorthController: testNetWorthController(repo),
                financeRepository: repo,
                split: _splitDeps(
                  splitRepo,
                  onOpenGroup: (context, groupId) => returned.future,
                ),
                clock: () => DateTime(2026, 7, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('split-tab')));
          await tester.pumpAndSettle();

          expect(splitRepo.getBalancesCalls, 1);

          await tester.tap(find.byKey(const Key('split-group-row-g1')));
          await tester.pump();

          // Still "away": the split tab must not reload while the group
          // screen is still on top.
          expect(splitRepo.getBalancesCalls, 1);

          returned.complete();
          await tester.pumpAndSettle();

          // Reloaded exactly once more on return.
          expect(splitRepo.getBalancesCalls, 2);
        },
      );

      // The settle wiring is the one place the *signed* balance crosses from
      // a tab row into the sheet, and the sign is the whole direction of the
      // money (design D1/D2). Driving `SettleUpSheet` directly with a
      // hand-passed `balanceAmount` cannot see this hand-over at all:
      // negating it here transposes payer and payee for every settlement
      // started from the split tab, and every such test stays green.
      for (final (label, amount, settleKey, receiving) in [
        ('they owe me', 450, 'split-owed-to-me-settle-0', true),
        ('I owe them', -450, 'split-owed-by-me-settle-0', false),
      ]) {
        testWidgets(
          'settling from the split tab ($label) opens the sheet for that row and posts the '
          'repayment in that direction',
          (tester) async {
            final repo = FakeFinanceRepository();
            final splitRepo = FakeSplitRepository()
              ..balancesToReturn = [
                Balance(
                  userId: 'u2',
                  displayName: 'Bo',
                  balances: [CurrencyBalance(currency: 'TWD', amount: amount)],
                ),
              ]
              // Without this the fake's `createSettlement` throws on
              // `settlementToReturn!` *after* recording its arguments: the
              // direction assertions below would still pass while the flow
              // sat on its error path (sheet open, snackbar, no reload).
              ..settlementToReturn = Settlement(
                id: 's-new',
                groupId: null,
                fromUserId: receiving ? 'u2' : 'self-1',
                fromDisplayName: receiving ? 'Bo' : 'Self',
                toUserId: receiving ? 'self-1' : 'u2',
                toDisplayName: receiving ? 'Self' : 'Bo',
                amount: 450,
                currency: 'TWD',
                day: '2026-07-15',
                note: null,
                createdByUserId: 'self-1',
              );

            await tester.pumpWidget(
              l10nTestApp(
                home: FinanceScaffold(
                  authRepository: _FakeAuthRepository(),
                  controller: testFinanceController(repo),
                  netWorthController: testNetWorthController(repo),
                  financeRepository: repo,
                  split: _splitDeps(splitRepo),
                  clock: () => DateTime(2026, 7, 15),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('split-tab')));
            await tester.pumpAndSettle();

            await tester.tap(find.byKey(Key(settleKey)));
            await tester.pumpAndSettle();

            final loc = lookupAppLocalizations(const Locale('en'));
            // The heading states the direction in words, so a transposed
            // sign is visible here before anything is even submitted.
            expect(
              find.text(
                receiving ? loc.settleUpTitleReceiving('Bo') : loc.settleUpTitlePaying('Bo'),
              ),
              findsOneWidget,
            );

            final balanceCallsBeforeConfirm = splitRepo.getBalancesCalls;

            await tester.tap(find.byKey(const Key('settle-up-confirm-button')));
            await tester.pumpAndSettle();

            expect(splitRepo.gotFromUserId, receiving ? 'u2' : 'self-1');
            expect(splitRepo.gotToUserId, receiving ? 'self-1' : 'u2');
            expect(splitRepo.gotAmount, 450);
            // D0: settling always starts from a two-person balance.
            expect(splitRepo.gotCreateSettlementGroupId, isNull);

            // What *success* means, as opposed to "the arguments were
            // recorded before something threw": the sheet closes, no error
            // is surfaced, and the tab's balances are re-fetched so the row
            // reflects the repayment without leaving the tab.
            expect(find.byKey(const Key('settle-up-title')), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            expect(splitRepo.getBalancesCalls, greaterThan(balanceCallsBeforeConfirm));
          },
        );
      }

      testWidgets(
        'deleting a repayment asks first — naming the person and the amount — and only '
        'deletes once confirmed',
        (tester) async {
          final repo = FakeFinanceRepository();
          final splitRepo = FakeSplitRepository()
            ..settlementsToReturn = const [
              Settlement(
                id: 's1',
                groupId: null,
                fromUserId: 'self-1',
                fromDisplayName: 'Self',
                toUserId: 'u2',
                toDisplayName: 'Bo',
                amount: 450,
                currency: 'TWD',
                day: '2026-07-10',
                note: null,
                createdByUserId: 'self-1',
              ),
            ];

          await tester.pumpWidget(
            l10nTestApp(
              home: FinanceScaffold(
                authRepository: _FakeAuthRepository(),
                controller: testFinanceController(repo),
                netWorthController: testNetWorthController(repo),
                financeRepository: repo,
                split: _splitDeps(splitRepo),
                clock: () => DateTime(2026, 7, 15),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('split-tab')));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('split-settlement-delete-s1')));
          await tester.pumpAndSettle();

          final loc = lookupAppLocalizations(const Locale('en'));
          // The counterpart is the *other* party, never the caller.
          expect(find.text(loc.splitDeleteSettlementConfirmMessage('Bo', '450')), findsOneWidget);

          // Cancelling deletes nothing.
          await tester.tap(find.byKey(const Key('split-delete-settlement-cancel')));
          await tester.pumpAndSettle();
          expect(splitRepo.deleteSettlementCalls, 0);

          await tester.tap(find.byKey(const Key('split-settlement-delete-s1')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('split-delete-settlement-confirm')));
          await tester.pumpAndSettle();

          expect(splitRepo.deleteSettlementCalls, 1);
          expect(splitRepo.gotSettlementId, 's1');
        },
      );
    });

    group('the 變更紀錄 section', () {
      SplitActivity activity(String id) => SplitActivity(
        id: id,
        type: SplitActivityType.expenseCreated,
        actorUserId: 'self-1',
        actorDisplayName: 'Self',
        groupId: null,
        groupName: null,
        subjectId: 'e-$id',
        counterpartUserId: null,
        counterpartDisplayName: null,
        amount: 10000,
        previousAmount: null,
        actorIsPayer: null,
        currency: 'TWD',
        description: id,
        createdAt: '2026-07-15T10:30:00.000Z',
      );

      testWidgets('recording an expense from on top of it makes the log show it', (
        tester,
      ) async {
        // The 記一筆 FAB stays on this read-only section by design (task
        // 3.1c). Before this, recording from here reloaded only the overview
        // controller: the reader watched the change log — the screen whose
        // whole promise is that everything that happened is in it — not move,
        // which reads as "my expense wasn't saved", and the entry that did not
        // appear is exactly the one explaining the balance that just changed.
        final repo = FakeFinanceRepository();
        final splitRepo = FakeSplitRepository()
          ..expenseToReturn = const SplitExpense(
            id: 'e-new',
            groupId: null,
            payerUserId: 'self-1',
            payerDisplayName: 'Self',
            createdByUserId: 'self-1',
            amount: 10000,
            currency: 'TWD',
            description: 'Lunch',
            day: '2026-07-15',
            splitMode: 'equal',
            shares: [],
            createdAt: '2026-07-15T10:30:00.000Z',
            updatedAt: '2026-07-15T10:30:00.000Z',
          )
          ..activityPagesToReturn = [
            SplitActivityPage(entries: [activity('older')], nextCursor: null),
            SplitActivityPage(
              entries: [activity('Lunch'), activity('older')],
              nextCursor: null,
            ),
          ];
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(
                splitRepo,
                friends: const [Friend(userId: 'f1', displayName: 'Friend One')],
              ),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();

        // Stand on the change log.
        await tester.tap(find.text(loc.splitSectionChangeLog));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('split-activity-row-older')), findsOneWidget);
        expect(splitRepo.activityCalls, hasLength(1));

        // Record from here, without leaving the section.
        await tester.tap(find.byKey(const Key('split-fab')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('split-amount-field')), '100');
        await tester.enterText(find.byKey(const Key('split-description-field')), 'Lunch');
        await tester.pumpAndSettle();
        // `ensureVisible` first: the sheet grew a category picker, which pushed
        // the participant list past the bottom of the 800x600 test viewport —
        // `tap` there warns about the missed hit test and then silently does
        // nothing, so the save button stays disabled and the failure surfaces
        // several lines later as a null `gotDescription`.
        await tester.ensureVisible(find.byKey(const Key('split-participant-f1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-participant-f1')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('split-save-button')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byKey(const Key('split-save-button'))).onPressed,
          isNotNull,
        );
        await tester.tap(find.byKey(const Key('split-save-button')));
        await tester.pumpAndSettle();

        expect(splitRepo.gotDescription, 'Lunch');
        expect(splitRepo.activityCalls, hasLength(2));
        expect(splitRepo.activityCalls.last.cursor, isNull, reason: 'refetched from the top');
        expect(find.byKey(const Key('split-activity-row-Lunch')), findsOneWidget);
      });

      testWidgets('its label does not collide with the bottom bar destination', (
        tester,
      ) async {
        // 總覽 / "Overview" is the finance bottom bar's first destination, and
        // it is on screen at the same time as the section switch. Two
        // different controls, one word, one screen.
        final repo = FakeFinanceRepository();
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(FakeSplitRepository()),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();

        expect(find.text(loc.financeTabOverview), findsOneWidget);
        expect(loc.splitSectionOverview, isNot(loc.financeTabOverview));
      });

      testWidgets('a dead record button is not shown at all', (tester) async {
        // With no profile there is no "you" to pre-select and no share stake
        // to check, so `_openSplitExpenseSheet` returns without opening
        // anything. The FAB used to stay on screen swallowing taps — worst of
        // all on the change log, which renders its own entries from its own
        // profile request and so looks perfectly healthy.
        final repo = FakeFinanceRepository();

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(
                FakeSplitRepository(),
                getProfile: GetProfile(
                  FakeProfileRepository()
                    ..profileToReturn = testProfile()
                    ..failNext = Exception('profile unavailable'),
                ),
              ),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('split-load-error')), findsOneWidget);
        expect(find.byKey(const Key('split-fab')), findsNothing);
      });
    });

    testWidgets(
      "a mirrored transaction's 'go to splits' exit really lands on the 分帳 "
      'tab',
      (tester) async {
        // The sheet only says where the locked parts are changed; the exit has
        // to actually get there, and it is wired from *this* widget (the split
        // tab is this scaffold's own index, not a route).
        final repo = FakeFinanceRepository()
          // Growable: the fake mutates this list in place on every write.
          ..byMonth['2026-07'] = [
            const FinanceTransaction(
              id: 'mirror-1',
              type: FinanceType.expense,
              amount: 900,
              currency: 'TWD',
              categoryId: 'cat-food',
              date: '2026-07-15',
              note: '晚餐',
              splitExpenseId: 'exp-1',
            ),
          ];

        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              financeRepository: repo,
              split: _splitDeps(FakeSplitRepository()),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.list_alt_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('finance-transaction-mirror-1')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('finance-go-to-split')));
        await tester.pumpAndSettle();

        // The sheet is gone and the 分帳 tab is the selected destination —
        // asserted on what the user can see there, not only on the index, so
        // "switched but never loaded" cannot pass.
        expect(find.byKey(const Key('finance-go-to-split')), findsNothing);
        expect(
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          3,
        );
        expect(find.byKey(const Key('split-fab')), findsOneWidget);
      },
    );
  });
}
