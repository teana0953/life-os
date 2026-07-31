import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';

import '../../../support/l10n_test_app.dart';
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
}

void main() {
  group('FinanceScaffold', () {
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
  });
}
