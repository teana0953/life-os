import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';
import 'package:life_os/contexts/finance/presentation/networth_tab.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/split/application/activity_use_cases.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/split/presentation/split_tab.dart';
import 'package:life_os/contexts/split/presentation/split_tab_dependencies.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/routing/finance_tab.dart';

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

SplitTabDependencies _splitDeps(FakeSplitRepository repo) => SplitTabDependencies(
  getBalances: GetBalances(repo),
  listGroups: ListGroups(repo),
  listExpenses: ListExpenses(repo),
  createExpense: CreateExpense(repo),
  updateExpense: UpdateExpense(repo),
  deleteExpense: DeleteExpense(repo),
  createGroup: CreateGroup(repo),
  listFriends: ListFriends(FakeSocialRepositoryForSplit()),
  getProfile: GetProfile(FakeProfileRepository()..profileToReturn = testProfile()),
  listSettlements: ListSettlements(repo),
  createSettlement: CreateSettlement(repo),
  deleteSettlement: DeleteSettlement(repo),
  listActivity: ListActivity(repo),
  onOpenGroup: (_, __) async {},
  onAddFriend: (_) {},
);

class _Harness {
  final GoRouter router;
  final FakeFinanceRepository finance;
  final FakeSplitRepository split;

  /// Every location `/finance` has been *built* with, in order. Read from the
  /// route builder rather than `routerDelegate.currentConfiguration.uri`,
  /// which reports the pre-push location for an imperative `push` — a URL
  /// guard reading that would pass no matter what this scaffold did.
  final List<String> financeLocations;

  _Harness(this.router, this.finance, this.split, this.financeLocations);
}

/// `/` sits under `/finance` so a `pop` has somewhere to land — which is how
/// these tests tell `replace` (no history entry) from `push`/`go`.
Future<_Harness> _pump(WidgetTester tester) async {
  final finance = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);
  final split = FakeSplitRepository();
  final financeLocations = <String>[];
  // Built once, outside the builder — `replace` re-runs it, and controllers
  // constructed inside would be silently swapped for empty ones mid-session.
  final financeController = testFinanceController(finance);
  final netWorthController = testNetWorthController(finance);
  final splitDeps = _splitDeps(split);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(
        path: '/finance',
        builder: (_, state) {
          financeLocations.add(state.uri.toString());
          return FinanceScaffold(
            initialTab:
                FinanceTab.fromSlug(
                  state.uri.queryParameters[FinanceTab.queryParameter],
                ) ??
                FinanceTab.overview,
            authRepository: _FakeAuthRepository(),
            controller: financeController,
            netWorthController: netWorthController,
            financeRepository: finance,
            split: splitDeps,
            clock: () => DateTime(2026, 7, 15),
          );
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
  return _Harness(router, finance, split, financeLocations);
}

int _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> _tapDestination(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('switching tabs syncs the URL', () {
    testWidgets('the visible tab is on the URL after every switch', (tester) async {
      final harness = await _pump(tester);
      harness.router.push('/finance');
      await tester.pumpAndSettle();

      await _tapDestination(tester, find.byKey(const Key('networth-tab')));
      expect(harness.financeLocations.last, '/finance?tab=networth');

      await _tapDestination(tester, find.byIcon(Icons.dashboard_outlined));
      expect(harness.financeLocations.last, '/finance?tab=overview');

      await _tapDestination(tester, find.byKey(const Key('split-tab')));
      expect(harness.financeLocations.last, '/finance?tab=split');
      expect(_selectedIndex(tester), FinanceTab.split.index);
    });

    testWidgets(
      'three tab switches add no history entries — one pop leaves finance',
      (tester) async {
        // Deliberately its own test, with no State assertion ahead of it: a
        // history guard that only ever runs after some other expectation has
        // already failed is not a guard.
        final harness = await _pump(tester);
        harness.router.push('/finance');
        await tester.pumpAndSettle();

        await _tapDestination(tester, find.byKey(const Key('networth-tab')));
        await _tapDestination(tester, find.byIcon(Icons.dashboard_outlined));
        await _tapDestination(tester, find.byKey(const Key('split-tab')));

        // With `go` the entry under finance is gone entirely; with `push`
        // every tab switch became a history entry and this pop lands on the
        // previous *tab* instead of on home.
        expect(harness.router.canPop(), isTrue);
        harness.router.pop();
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsOneWidget);
        expect(find.byType(FinanceScaffold), findsNothing);
      },
    );

    testWidgets('the scaffold State survives the URL rewrite', (tester) async {
      final harness = await _pump(tester);
      harness.router.push('/finance');
      await tester.pumpAndSettle();
      expect(harness.finance.summaryTokens, ['tok'], reason: 'the entry load');

      await _tapDestination(tester, find.byKey(const Key('networth-tab')));
      await _tapDestination(tester, find.byIcon(Icons.dashboard_outlined));
      await _tapDestination(tester, find.byKey(const Key('split-tab')));

      // Proved, not reasoned about from "same GoRoute keeps its pageKey": a
      // remounted scaffold re-runs its entry load, so the token log would
      // grow. Exact list, not a count floor — `hasLength(greaterThan(0))`
      // cannot fail.
      expect(
        harness.finance.summaryTokens,
        ['tok'],
        reason:
            'replace must reuse the same page/State — a remount would refetch '
            'the ledger on every tab switch',
      );
      // And the lazy gate opened by the first switch is still open, which
      // only a surviving State can be.
      expect(find.byType(NetWorthTab, skipOffstage: false), findsOneWidget);
    });

    testWidgets('arriving does NOT rewrite the URL', (tester) async {
      // The initState seed deliberately skips the sync: a bare `/finance` the
      // user just arrived on must not turn into `/finance?tab=overview`, and
      // an entry on `?tab=split` must not be rebuilt into anything else.
      final harness = await _pump(tester);
      harness.router.push('/finance');
      await tester.pumpAndSettle();
      expect(harness.financeLocations, ['/finance']);

      harness.financeLocations.clear();
      harness.router.go('/finance?tab=split');
      await tester.pumpAndSettle();
      expect(harness.financeLocations, ['/finance?tab=split']);
      expect(_selectedIndex(tester), FinanceTab.split.index);
    });

    testWidgets(
      'initialTab is an initState-only seed: a later route rebuild does not '
      'move the tab under the user',
      (tester) async {
        // If `didUpdateWidget` re-applied `initialTab`, the scaffold's own
        // `replace` would fight the user's taps. Driving the route directly is
        // the sharpest form of that: the widget's `initialTab` becomes 分帳
        // while the user is standing on 淨值.
        final harness = await _pump(tester);
        harness.router.push('/finance');
        await tester.pumpAndSettle();
        await _tapDestination(tester, find.byKey(const Key('networth-tab')));

        harness.router.replace('/finance?tab=split');
        await tester.pumpAndSettle();

        expect(_selectedIndex(tester), FinanceTab.networth.index);
        expect(find.byType(SplitTab), findsNothing);
        expect(
          harness.split.getBalancesCalls,
          0,
          reason: 'the split tab was never opened by the user',
        );
      },
    );
  });

  group('the maybeOf null-guard', () {
    testWidgets('router-less: switching tabs still works and does not throw', (
      tester,
    ) async {
      // Most of this scaffold's widget tests pump it under a plain
      // `MaterialApp`. `GoRouter.of` would throw here; `maybeOf` no-ops.
      final finance = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);
      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: testFinanceController(finance),
            netWorthController: testNetWorthController(finance),
            financeRepository: finance,
            split: _splitDeps(FakeSplitRepository()),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapDestination(tester, find.byKey(const Key('networth-tab')));

      expect(tester.takeException(), isNull);
      expect(_selectedIndex(tester), FinanceTab.networth.index);
      expect(find.byKey(const Key('account-row-acc-cash')), findsOneWidget);
    });
  });
}
