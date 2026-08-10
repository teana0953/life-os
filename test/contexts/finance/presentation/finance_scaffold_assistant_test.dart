import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/split/application/activity_use_cases.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/split/presentation/split_tab_dependencies.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../split/support/fake_split_repository.dart';
import '../../split/support/split_presentation_fakes.dart';
import '../finance_test_support.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => 'tok';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}
}

SplitTabDependencies _splitDeps(FakeSplitRepository repo) =>
    SplitTabDependencies(
      getBalances: GetBalances(repo),
      listGroups: ListGroups(repo),
      listExpenses: ListExpenses(repo),
      createExpense: CreateExpense(repo),
      updateExpense: UpdateExpense(repo),
      deleteExpense: DeleteExpense(repo),
      createGroup: CreateGroup(repo),
      listFriends: ListFriends(FakeSocialRepositoryForSplit()),
      getProfile: GetProfile(
        FakeProfileRepository()..profileToReturn = testProfile(),
      ),
      listSettlements: ListSettlements(repo),
      createSettlement: CreateSettlement(repo),
      deleteSettlement: DeleteSettlement(repo),
      listActivity: ListActivity(repo),
      onOpenGroup: (_, __) async {},
      onAddFriend: (_) {},
    );

class _Harness {
  final GoRouter router;
  final FakeFinanceRepository repo;
  final FinanceController controller;
  final List<String> pushedAssistantUris;

  _Harness(this.router, this.repo, this.controller, this.pushedAssistantUris);
}

/// A real router: `/` is the scaffold, `/assistant` records the **full URI it
/// was pushed with** (query included) and shows a stub the test can pop —
/// which is what lets these guards see the URL and the return, the two things
/// this slice is about.
Future<_Harness> _pumpScaffold(WidgetTester tester) async {
  final repo = FakeFinanceRepository();
  final controller = testFinanceController(repo);
  final pushed = <String>[];
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => FinanceScaffold(
          authRepository: _FakeAuthRepository(),
          controller: controller,
          netWorthController: testNetWorthController(repo),
          financeRepository: repo,
          split: _splitDeps(FakeSplitRepository()),
          // The clock's month (2026-07) is deliberately different from the
          // month the tests pin (2026-06) AND from the real today: an entry
          // built from "today" instead of the selected month comes out
          // different either way, so the URL guard can actually go red.
          clock: () => DateTime(2026, 7, 15),
        ),
      ),
      GoRoute(
        path: '/assistant',
        builder: (_, state) {
          pushed.add(state.uri.toString());
          return const Scaffold(body: Text('assistant-stub'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: testSupportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(router, repo, controller, pushed);
}

void main() {
  group('FinanceScaffold assistant entry', () {
    testWidgets('the entry URL carries the tab being looked at and the pinned '
        'non-current month — not today\'s', (tester) async {
      final harness = await _pumpScaffold(tester);

      // Pin the month AWAY from the clock's 2026-07: an implementation
      // that sends monthOf(today) instead of selectedMonth now differs.
      await tester.tap(find.byKey(const Key('finance-month-previous')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-assistant-button')));
      await tester.pumpAndSettle();

      expect(harness.pushedAssistantUris, hasLength(1));
      final uri = Uri.parse(harness.pushedAssistantUris.single);
      expect(uri.path, '/assistant');
      expect(uri.queryParameters['ctx'], 'finance');
      expect(uri.queryParameters['tab'], 'transactions');
      expect(uri.queryParameters['month'], '2026-06');

      // GUARD: Verify no missing or extra parameters. All three parameters
      // must be present — missing 'ctx' or 'tab' would put the assistant in
      // the wrong mode. An extra parameter would cause the URL to not match
      // in AssistantChatContext.fromQuery and the context would not restore.
      expect(
        uri.queryParameters.length,
        3,
        reason: 'the URL must carry exactly ctx + tab + month',
      );
    });

    testWidgets('the split tab sends no month — it has none to show', (
      tester,
    ) async {
      final harness = await _pumpScaffold(tester);

      await tester.tap(find.byKey(const Key('split-tab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-assistant-button')));
      await tester.pumpAndSettle();

      final uri = Uri.parse(harness.pushedAssistantUris.single);
      expect(uri.queryParameters['tab'], 'split');
      expect(uri.queryParameters.containsKey('month'), isFalse);
    });

    testWidgets('the networth tab sends its OWN month — not the ledger\'s', (
      tester,
    ) async {
      final harness = await _pumpScaffold(tester);

      // Pin the ledger's month TWO steps away from the clock's 2026-07
      // (→ 2026-05), then pin 淨值's own month ONE step away (→ 2026-06):
      // ledger, 淨值, and "today" all land on different months, so this
      // guard can tell 淨值's own selectedMonth apart from both the
      // ledger's selectedMonth AND monthOf(today) — swapping the
      // `2 => widget.netWorthController.selectedMonth` branch for either
      // of those now differs from the assertion below.
      await tester.tap(find.byKey(const Key('finance-month-previous')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('finance-month-previous')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('networth-month-previous')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-assistant-button')));
      await tester.pumpAndSettle();

      final uri = Uri.parse(harness.pushedAssistantUris.single);
      expect(uri.queryParameters['tab'], 'networth');
      expect(uri.queryParameters['month'], '2026-06');
      expect(
        uri.queryParameters['month'],
        isNot(harness.controller.selectedMonth),
        reason: '淨值 and the ledger keep separate months on purpose',
      );
      expect(
        uri.queryParameters['month'],
        isNot('2026-07'),
        reason: "淨值's own month must not silently fall back to today's",
      );
    });

    testWidgets(
      'returning from the assistant reloads the ledger — and only on return',
      (tester) async {
        final harness = await _pumpScaffold(tester);
        expect(harness.repo.summaryTokens, hasLength(1)); // entry load

        await tester.tap(find.byKey(const Key('finance-month-previous')));
        await tester.pumpAndSettle();
        expect(harness.repo.summaryTokens, hasLength(2)); // month switch

        await tester.tap(find.byKey(const Key('finance-assistant-button')));
        await tester.pumpAndSettle();
        // Still 2: a fire-and-forget push whose reload runs immediately —
        // while the user is still *in* the assistant — trips this.
        expect(
          harness.repo.summaryTokens,
          hasLength(2),
          reason: 'the reload must wait for the user to come back',
        );

        harness.router.pop();
        await tester.pumpAndSettle();

        expect(
          harness.repo.summaryTokens,
          hasLength(3),
          reason:
              'coming back must refetch — the assistant may have recorded '
              'a transaction the ledger on screen does not show yet',
        );
        // The reload kept the pinned month; a reload of monthOf(today) would
        // have moved selectedMonth back to 2026-07.
        expect(harness.controller.selectedMonth, '2026-06');

        // GUARD: Pushing the assistant again does not reload a second time
        // (no duplicate reload in-flight). The push itself must be awaited,
        // not fire-and-forget with a separate reload.
        await tester.tap(find.byKey(const Key('finance-assistant-button')));
        await tester.pumpAndSettle();
        expect(
          harness.repo.summaryTokens,
          hasLength(3),
          reason:
              'pushing the assistant again must not trigger another reload '
              'while in the assistant view',
        );
      },
    );
  });
}
