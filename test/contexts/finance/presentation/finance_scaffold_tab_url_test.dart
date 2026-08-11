import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Every location `/finance` has been *built* with, in order.
  final List<String> financeLocations;

  /// Every `routeInformationUpdated` the framework sent to the platform —
  /// i.e. every write to the browser address bar/history, as `(uri, replace)`.
  ///
  /// This, not the builder's `state.uri`, is what a user sees and what a
  /// refresh reloads. A guard that only reads the builder argument cannot
  /// tell a correct rewrite from one that reports a different location to the
  /// browser than the one it built.
  final List<(String, bool)> platformUrlWrites;

  _Harness(this.router, this.finance, this.split, this.financeLocations, this.platformUrlWrites);

  /// The location the browser is on — what `restoreRouteInformation` hands
  /// the engine, not the internal match list's `uri`.
  String get reportedLocation => router.routeInformationParser
      .restoreRouteInformation(router.routerDelegate.currentConfiguration)!
      .uri
      .toString();
}

/// `/finance` is nested under `/`, exactly as in `app.dart` — and that nesting
/// is load-bearing for these tests, not decoration. With the two routes as
/// flat siblings, an imperative `replace` collapses to a plain match list and
/// its location reaches the address bar; nested, it becomes an
/// `ImperativeRouteMatch` whose location go_router does *not* report (unless
/// `GoRouter.optionURLReflectsImperativeAPIs` is set, which this app never
/// does), so the browser is handed the parent's `/` with a stale query. A flat
/// harness would pass either way.
///
/// `/` also gives a `pop` somewhere to land, which is how these tests tell a
/// non-navigating tab switch from a `push`.
Future<_Harness> _pump(WidgetTester tester) async {
  final finance = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);
  final split = FakeSplitRepository();
  final financeLocations = <String>[];
  // Built once, outside the builder — these tests drive the route directly,
  // which re-runs it, and controllers constructed inside would be silently
  // swapped for empty ones mid-session.
  final financeController = testFinanceController(finance);
  final netWorthController = testNetWorthController(finance);
  final splitDeps = _splitDeps(split);
  final platformUrlWrites = <(String, bool)>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.navigation, (
    call,
  ) async {
    if (call.method == 'routeInformationUpdated') {
      final args = call.arguments as Map<Object?, Object?>;
      platformUrlWrites.add((args['uri']! as String, args['replace']! as bool));
    }
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      null,
    ),
  );
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('HOME')),
        routes: [
          GoRoute(
            path: 'finance',
            builder: (_, state) {
              financeLocations.add(state.uri.toString());
              return FinanceScaffold(
                initialTab:
                    FinanceTab.fromSlug(state.uri.queryParameters[FinanceTab.queryParameter]) ??
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
  return _Harness(router, finance, split, financeLocations, platformUrlWrites);
}

int _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> _tapDestination(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('switching tabs leaves the address bar alone', () {
    testWidgets('a refresh after three switches still reloads finance', (tester) async {
      // Entered with `go`, so the reported location is the real
      // `/finance?tab=networth` — the case where a wrong rewrite is
      // *visible*. (After a `push` the address bar is already `/`, which
      // hides the damage.)
      final harness = await _pump(tester);
      harness.router.go('/finance?tab=networth');
      await tester.pumpAndSettle();
      expect(harness.reportedLocation, '/finance?tab=networth');

      await _tapDestination(tester, find.byKey(const Key('split-tab')));
      await _tapDestination(tester, find.byIcon(Icons.dashboard_outlined));
      await _tapDestination(tester, find.byKey(const Key('networth-tab')));

      // The taps really landed — without this, the location assertion below
      // would also hold for a scaffold that ignored every tap.
      expect(_selectedIndex(tester), FinanceTab.networth.index);
      expect(
        harness.reportedLocation,
        '/finance?tab=networth',
        reason:
            'a `replace` here reports the *parent* route with the old query '
            '(`/?tab=networth`), because it is an imperative match go_router '
            'does not reflect — a refresh would land on 首頁',
      );
    });

    testWidgets('switching tabs writes nothing to the browser history', (tester) async {
      // Its own test, with no assertion ahead of it that a URL-writing
      // scaffold would trip first: a guard that only runs after some other
      // expectation has already failed is not a guard.
      final harness = await _pump(tester);
      harness.router.go('/finance?tab=networth');
      await tester.pumpAndSettle();
      harness.platformUrlWrites.clear();

      await _tapDestination(tester, find.byKey(const Key('split-tab')));
      await _tapDestination(tester, find.byIcon(Icons.dashboard_outlined));
      await _tapDestination(tester, find.byKey(const Key('networth-tab')));

      expect(_selectedIndex(tester), FinanceTab.networth.index);
      expect(
        harness.platformUrlWrites,
        isEmpty,
        reason: 'no tab switch may reach the address bar or the history stack',
      );
    });

    testWidgets('three tab switches add no history entries — one pop leaves finance', (
      tester,
    ) async {
      // Deliberately its own test, with no State assertion ahead of it: a
      // history guard that only ever runs after some other expectation has
      // already failed is not a guard.
      final harness = await _pump(tester);
      harness.router.push('/finance');
      await tester.pumpAndSettle();

      await _tapDestination(tester, find.byKey(const Key('networth-tab')));
      await _tapDestination(tester, find.byIcon(Icons.dashboard_outlined));
      await _tapDestination(tester, find.byKey(const Key('split-tab')));

      // With `push` every tab switch became a history entry and this pop
      // lands on the previous *tab* instead of on home.
      expect(harness.router.canPop(), isTrue);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(FinanceScaffold), findsNothing);
    });

    testWidgets('the scaffold State survives three tab switches', (tester) async {
      // Entered by `push`, the way the home tiles enter it: that is the case
      // where a routing call per tab switch would remount the scaffold (the
      // imperative match is replaced by a plain one, a different page key)
      // and throw away its per-`State` split controller.
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
            'a tab switch must reuse the same page/State — a remount would '
            'refetch the ledger on every tab switch',
      );
      // And the lazy gate opened by the first switch is still open, which
      // only a surviving State can be.
      expect(find.byType(NetWorthTab, skipOffstage: false), findsOneWidget);
    });

    testWidgets('arriving reads the URL without rewriting it', (tester) async {
      // Both halves at once: a bare `/finance` the user just arrived on must
      // not turn into `/finance?tab=overview`, and an entry on `?tab=split`
      // must be *obeyed* — the URL is read inwards, never written back.
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

    testWidgets('initialTab is an initState-only seed: a later route rebuild does not '
        'move the tab under the user', (tester) async {
      // If `didUpdateWidget` re-applied `initialTab`, any later rebuild of
      // this route — a deep link handled elsewhere, a redirect — would move
      // the tab under the user. Driving the route directly is the sharpest
      // form of that: the widget's `initialTab` becomes 分帳 while the user
      // is standing on 淨值.
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
    });
  });

  group('with no Router above it at all', () {
    testWidgets('switching tabs still works and does not throw', (tester) async {
      // Most of this scaffold's widget tests pump it under a plain
      // `MaterialApp`. Kept as the standing guard against reintroducing an
      // unguarded `GoRouter.of(context)` in the tab-switch path — which would
      // throw here rather than fail somewhere subtle.
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
