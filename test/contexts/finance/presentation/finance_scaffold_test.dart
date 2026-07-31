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
      final controller = testFinanceController(FakeFinanceRepository());

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
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
      final controller = testFinanceController(FakeFinanceRepository());

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
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
  });
}
