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
import 'package:life_os/contexts/split/domain/split_group.dart';
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

  _Harness(this.router, this.finance, this.split);
}

/// A real router whose `/finance` route parses `?tab=` exactly the way
/// `app.dart` does, so `router.go(...)` here is the browser/refresh/PWA-
/// shortcut shape — the whole match stack rebuilt from the URL alone.
///
/// Both fakes return **non-empty, identifiable** data (one net-worth account
/// with a snapshot, one split group). Without that, a tab that is built but
/// blank would be indistinguishable from a tab that was built and loaded, and
/// the first-open-load half of these guards would be testing nothing.
Future<_Harness> _pump(WidgetTester tester, String location) async {
  final finance = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);
  final split = FakeSplitRepository()
    ..groupsToReturn = const [
      SplitGroup(id: 'g1', name: 'Trip', createdByUserId: 'self-1', archivedAt: null),
    ];
  // Built ONCE, outside the route builder: `replace` (the tab-switch URL sync)
  // re-runs that builder, and controllers constructed inside it would hand the
  // scaffold fresh empty ones on every tab switch. In production these come
  // from `main.dart`'s DI and are stable.
  final financeController = testFinanceController(finance);
  final netWorthController = testNetWorthController(finance);
  final splitDeps = _splitDeps(split);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(
        path: '/finance',
        builder: (_, state) => FinanceScaffold(
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
        ),
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
  router.go(location);
  await tester.pumpAndSettle();
  return _Harness(router, finance, split);
}

int _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

final _loc = lookupAppLocalizations(const Locale('en'));

void main() {
  group('/finance?tab= opens that destination, fully built', () {
    testWidgets('?tab=networth lands on 淨值 with its data on screen', (tester) async {
      final harness = await _pump(tester, '/finance?tab=networth');

      // Not just "the widget exists": a seeded account row proves the lazy
      // build gate opened AND `_loadNetWorth` ran. Setting `_index = 2`
      // directly gives a blank `SizedBox`; opening the gate without the load
      // gives a spinner that never ends.
      expect(find.byType(NetWorthTab), findsOneWidget);
      expect(find.byKey(const Key('account-row-acc-cash')), findsOneWidget);
      expect(harness.finance.trendCalls, hasLength(1));

      expect(_selectedIndex(tester), FinanceTab.networth.index);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(_loc.financeTabNetWorth)),
        findsOneWidget,
      );
      // 淨值 has no record-transaction FAB.
      expect(find.byKey(const Key('finance-fab')), findsNothing);
      expect(find.byKey(const Key('finance-installment-fab')), findsNothing);
    });

    testWidgets('?tab=split lands on 分帳 with its data on screen', (tester) async {
      final harness = await _pump(tester, '/finance?tab=split');

      expect(find.byType(SplitTab), findsOneWidget);
      expect(find.byKey(const Key('split-group-row-g1')), findsOneWidget);
      // The fetch itself, not only the paint: "gate released, `_loadSplit`
      // never called" is the exact blank-screen bug this pins.
      expect(harness.split.getBalancesCalls, 1);

      expect(_selectedIndex(tester), FinanceTab.split.index);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(_loc.financeTabSplit)),
        findsOneWidget,
      );
      // Present only once the profile resolved — which it has, because the
      // load ran.
      expect(find.byKey(const Key('split-fab')), findsOneWidget);
      expect(find.byKey(const Key('finance-fab')), findsNothing);
    });

    testWidgets('entering on 淨值 then tapping 淨值 does not load twice', (tester) async {
      final harness = await _pump(tester, '/finance?tab=networth');
      expect(harness.finance.trendCalls, hasLength(1));

      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      expect(
        harness.finance.trendCalls,
        hasLength(1),
        reason: '_netWorthLoaded must still gate the re-selection',
      );
    });
  });

  group('an unknown or missing tab falls back to 總覽 — and builds nothing else', () {
    for (final location in ['/finance', '/finance?tab=bogus', '/finance?tab=', '/finance?tab=NetWorth']) {
      testWidgets('$location shows 總覽 and leaves both lazy tabs unbuilt', (tester) async {
        final harness = await _pump(tester, location);

        expect(_selectedIndex(tester), FinanceTab.overview.index);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(_loc.financeTabOverview),
          ),
          findsOneWidget,
        );

        // The reverse half. Without it, "open every gate on entry" passes the
        // two tests above. Exact zero/absence, never `greaterThan` — and on
        // the same fakes that produce visible content in those tests, so this
        // is absence of a tab, not absence of data.
        expect(find.byType(NetWorthTab), findsNothing);
        expect(find.byType(SplitTab), findsNothing);
        expect(harness.finance.trendCalls, isEmpty);
        expect(harness.split.getBalancesCalls, 0);

        // 總覽 keeps the record FAB.
        expect(find.byKey(const Key('finance-fab')), findsOneWidget);
      });
    }
  });
}
